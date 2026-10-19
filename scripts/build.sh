#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat >&2 <<'EOF'
Usage: build.sh OUTPUT_DIRECTORY

Build the complete pinned AArch64 PRoot vendor-Vulkan stack: libhybris SPHAL
runtime, Vulkan Loader, sysvk, AHardwareBuffer wrapper, xMeM X11 WSI and probes.
OUTPUT_DIRECTORY must not already exist.
EOF
}

(($# == 1)) || { usage; exit 2; }

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
lock=$repo_root/build/source-lock.json
output=$1
[[ $output == /* ]] || output=$PWD/$output
[[ ! -e $output ]] || {
    printf 'build: output already exists: %s\n' "$output" >&2
    exit 2
}
mkdir -p "$output/src" "$output/stage"

source_field()
{
    python3 - "$lock" "$1" "$2" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    lock = json.load(handle)
print(lock["sources"][sys.argv[2]][sys.argv[3]])
PY
}

fetch_locked()
{
    local name=$1 url revision destination
    url=$(source_field "$name" url)
    revision=$(source_field "$name" revision)
    destination=$output/src/$name
    git init -q "$destination"
    git -C "$destination" remote add origin "$url"
    git -C "$destination" fetch -q --depth=1 origin "$revision"
    git -C "$destination" checkout -q --detach FETCH_HEAD
    [[ $(git -C "$destination" rev-parse HEAD) == "$revision" ]] || {
        printf 'build: revision mismatch for %s\n' "$name" >&2
        exit 3
    }
}

for source in \
    libhybris android_headers sysvk vulkan_headers vulkan_loader \
    xmem_wsi wsi_headers; do
    fetch_locked "$source"
done

for patch in "$repo_root"/patches/libhybris/*.patch; do
    git -C "$output/src/libhybris" apply --check "$patch"
    git -C "$output/src/libhybris" apply "$patch"
done
git -C "$output/src/libhybris" diff --check

git -C "$output/src/sysvk" apply --check \
    "$repo_root/patches/sysvk/0001-discover-and-validate-explicit-vulkan-hal.patch"
git -C "$output/src/sysvk" apply \
    "$repo_root/patches/sysvk/0001-discover-and-validate-explicit-vulkan-hal.patch"
git -C "$output/src/sysvk" diff --check

for patch in "$repo_root"/patches/xmem-wsi/*.patch; do
    git -C "$output/src/xmem_wsi" apply --check "$patch"
    git -C "$output/src/xmem_wsi" apply "$patch"
done
git -C "$output/src/xmem_wsi" diff --check

dockerfile=$repo_root/build/Dockerfile.arm64
image=${PROOT_SPHAL_BUILD_IMAGE:-proot-sphal-build:$(git hash-object "$dockerfile")}
docker image inspect "$image" >/dev/null 2>&1 || \
    docker build --platform linux/arm64 -t "$image" \
        -f "$dockerfile" "$repo_root/build"

source_date_epoch=$(git -C "$output/src/libhybris" show -s --format=%ct HEAD)
docker run --rm --platform linux/arm64 \
    --volume "$repo_root:/repo:ro" \
    --volume "$output:/work" \
    --env LC_ALL=C \
    --env TZ=UTC \
    --env SOURCE_DATE_EPOCH="$source_date_epoch" \
    "$image" \
    bash -euo pipefail -c '
        prefix=/work/stage/opt/proot-sphal

        cd /work/src/libhybris/hybris
        ./autogen.sh
        ./configure \
            --prefix=/opt/proot-sphal \
            --libdir=/opt/proot-sphal/lib \
            --with-android-headers=/work/src/android_headers \
            --with-default-hybris-ld-library-path=/system/lib64:/system_ext/lib64:/product/lib64:/vendor/lib64:/vendor/lib64/egl:/vendor/lib64/hw:/odm/lib64:/apex/com.android.runtime/lib64/bionic \
            --enable-arch=arm64 \
            --enable-mali-quirks \
            --enable-property-cache \
            --enable-experimental \
            --enable-relocatable-runtime \
            --disable-debug \
            CFLAGS="-O2 -g0 -Wa,--noexecstack -fPIC -ffile-prefix-map=/work=." \
            CXXFLAGS="-O2 -g0 -Wa,--noexecstack -fPIC -ffile-prefix-map=/work=." \
            LDFLAGS="-Wl,-z,noexecstack"
        make -C common -j"$(nproc)"
        make -C hardware -j"$(nproc)"
        make -C common DESTDIR=/work/stage install
        make -C hardware DESTDIR=/work/stage install

        install -d "$prefix/bin" "$prefix/include" "$prefix/lib/vulkan"
        cc -O2 -g0 -Wall -Wextra -Werror -fPIC -shared \
            -Wl,-soname,libproot-sphal.so.0 \
            -I/repo/include /repo/src/proot_sphal.c \
            -L"$prefix/lib" -lhybris-common \
            -o "$prefix/lib/libproot-sphal.so.0"
        ln -s libproot-sphal.so.0 "$prefix/lib/libproot-sphal.so"
        cc -O2 -g0 -Wall -Wextra -Werror \
            -I/repo/include /repo/tools/sphal-probe.c \
            -L"$prefix/lib" -Wl,-rpath-link,"$prefix/lib" \
            -lproot-sphal -lhybris-common \
            -o "$prefix/bin/sphal-probe"
        install -m 0644 /repo/include/proot_sphal.h "$prefix/include/"
        install -m 0755 /repo/scripts/proot-sphal-run "$prefix/bin/"
        install -m 0755 /repo/scripts/proot-vulkan-x11-run "$prefix/bin/"

        cmake -S /work/src/vulkan_headers -B /work/build/vulkan-headers -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/work/vulkan-headers-install
        cmake --build /work/build/vulkan-headers --parallel "$(nproc)"
        cmake --install /work/build/vulkan-headers

        cmake -S /work/src/vulkan_loader -B /work/build/vulkan-loader -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/opt/proot-sphal \
            -DCMAKE_INSTALL_LIBDIR=lib/vulkan \
            -DVULKAN_HEADERS_INSTALL_DIR=/work/vulkan-headers-install \
            -DBUILD_TESTS=OFF \
            -DBUILD_WSI_XCB_SUPPORT=ON \
            -DBUILD_WSI_XLIB_SUPPORT=ON \
            -DBUILD_WSI_WAYLAND_SUPPORT=OFF
        cmake --build /work/build/vulkan-loader --parallel "$(nproc)"
        DESTDIR=/work/stage cmake --install /work/build/vulkan-loader

        loader_symbols=$(nm -D --defined-only "$prefix/lib/vulkan/libvulkan.so.1" |
            awk "{ print \$3 }" | sed "s/@.*//")
        for symbol in vkCreateXcbSurfaceKHR vkCreateXlibSurfaceKHR; do
            if ! grep -Fxq "$symbol" <<<"$loader_symbols"; then
                printf "build: Vulkan Loader is missing %s\n" "$symbol" >&2
                exit 1
            fi
        done

        cc -std=c11 -O2 -g0 -fPIC -shared -ffile-prefix-map=/work=. \
            -I/work/src/sysvk/include \
            -I/work/src/vulkan_headers/include \
            -I/work/src/android_headers \
            -I/work/src/libhybris/hybris/include \
            /work/src/sysvk/sysvk.c \
            -L"$prefix/lib" -Wl,--no-as-needed -lhardware -lhybris-common \
            -Wl,-rpath,'\''$ORIGIN/..'\'' -Wl,-z,noexecstack -pthread -ldl \
            -o "$prefix/lib/vulkan/libsysvk.so"

        cc -std=c11 -O2 -g0 -fPIC -shared -ffile-prefix-map=/work=. \
            -I/work/src/android_headers \
            -I/work/src/libhybris/hybris/include \
            /repo/bridge/ahb-wrapper.c \
            -L"$prefix/lib" -Wl,--no-as-needed -lhybris-common \
            -Wl,-rpath,'\''$ORIGIN/..'\'' -Wl,-z,noexecstack -pthread -ldl \
            -o "$prefix/lib/vulkan/libahb-wrapper.so"

        headers=/work/src/wsi_headers/include
        cmake -S /work/src/xmem_wsi -B /work/build/wsi -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/opt/proot-sphal \
            -DVULKAN_CXX_INCLUDE="$headers" \
            -DANDROID_HEADERS_INCLUDE_DIR=/work/src/android_headers \
            -DBUILD_WSI_HEADLESS=ON \
            -DBUILD_WSI_X11=ON \
            -DBUILD_WSI_WAYLAND=OFF \
            -DBUILD_WSI_DISPLAY=OFF \
            -DBUILD_WSI_DISPLAY_SUPPORT_FORMAT_MODIFIERS=ON \
            -DBUILD_WSI_IMAGE_COMPRESSION_CONTROL_SWAPCHAIN=OFF \
            -DVULKAN_WSI_LAYER_EXPERIMENTAL=OFF \
            -DENABLE_INSTRUMENTATION=OFF
        cmake --build /work/build/wsi --parallel "$(nproc)"
        DESTDIR=/work/wsi-stage cmake --install /work/build/wsi

        source_dir=/work/wsi-stage/opt/proot-sphal/share/vulkan/implicit_layer.d
        target_dir=$prefix/share/vulkan/explicit_layer.d
        install -d "$target_dir"
        install -m 0755 \
            "$source_dir/libVkLayer_window_system_integration.so" \
            "$target_dir/libVkLayer_window_system_integration.so"
        install -m 0644 \
            "$source_dir/VkLayer_window_system_integration.json" \
            "$target_dir/VkLayer_window_system_integration.json"

        install -d "$prefix/libexec"
        cc -std=c11 -O2 -g0 -ffile-prefix-map=/work=. \
            -I/work/src/vulkan_headers/include \
            /repo/probes/vulkan-thread-lifecycle.c \
            -L"$prefix/lib/vulkan" -lvulkan -ldl -pthread \
            -Wl,-rpath,'\''$ORIGIN/../lib/vulkan'\'' -Wl,-z,noexecstack \
            -o "$prefix/libexec/vulkan-thread-lifecycle"
        cc -std=c11 -O2 -g0 -ffile-prefix-map=/work=. \
            -I/work/src/vulkan_headers/include \
            /repo/probes/vulkan-xcb-present.c \
            -L"$prefix/lib/vulkan" -lvulkan -lxcb \
            -Wl,-rpath,'\''$ORIGIN/../lib/vulkan'\'' -Wl,-z,noexecstack \
            -o "$prefix/libexec/vulkan-xcb-present"

        while IFS= read -r -d "" candidate; do
            readelf -h "$candidate" >/dev/null 2>&1 || continue
            dynamic=$(readelf -dW "$candidate")
            while IFS= read -r line; do
                [[ $line =~ \((RPATH|RUNPATH)\).*\[(.*)\] ]] || continue
                path=${BASH_REMATCH[2]}
                case "$path" in
                    ""|'\''$ORIGIN/..'\''|'\''$ORIGIN/../lib/vulkan'\'') ;;
                    *) printf "non-relocatable runtime path in %s: %s\n" \
                           "$candidate" "$path" >&2; exit 1 ;;
                esac
            done <<<"$dynamic"
        done < <(find "$prefix" -type f -print0)
    '

install -d "$output/stage/opt/proot-sphal/share/vulkan/icd.d"
install -m 0644 "$repo_root/bridge/sysvk.json" \
    "$output/stage/opt/proot-sphal/share/vulkan/icd.d/sysvk.json"

python3 "$repo_root/packaging/verify_libhybris.py" \
    "$output/stage/opt/proot-sphal/lib/libhybris-common.so.1"

for required in \
    bin/proot-sphal-run \
    bin/proot-vulkan-x11-run \
    lib/vulkan/libahb-wrapper.so \
    lib/vulkan/libsysvk.so \
    lib/vulkan/libvulkan.so.1 \
    libexec/vulkan-thread-lifecycle \
    libexec/vulkan-xcb-present \
    share/vulkan/icd.d/sysvk.json \
    share/vulkan/explicit_layer.d/libVkLayer_window_system_integration.so \
    share/vulkan/explicit_layer.d/VkLayer_window_system_integration.json; do
    [[ -e $output/stage/opt/proot-sphal/$required ]] || {
        printf 'build: missing output: %s\n' "$required" >&2
        exit 3
    }
done

printf 'PASS complete package staged at %s\n' \
    "$output/stage/opt/proot-sphal"
