#!/usr/bin/env bash
set -euo pipefail

usage()
{
    printf 'Usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
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

fetch_locked libhybris
fetch_locked android_headers

for patch in "$repo_root"/patches/libhybris/*.patch; do
    git -C "$output/src/libhybris" apply --check "$patch"
    git -C "$output/src/libhybris" apply "$patch"
done
git -C "$output/src/libhybris" diff --check

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

        prefix=/work/stage/opt/proot-sphal
        install -d "$prefix/bin" "$prefix/include"
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
    '

python3 "$repo_root/packaging/verify_libhybris.py" \
    "$output/stage/opt/proot-sphal/lib/libhybris-common.so.1"
printf 'PASS package staged at %s\n' "$output/stage/opt/proot-sphal"
