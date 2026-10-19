# proot-sphal

Canonical source for running Android vendor Vulkan from an AArch64 glibc PRoot
guest and presenting it through a paired Termux:X11 server.

It contains the complete reproducible path: patched libhybris, sysvk, the
AHardwareBuffer wrapper, patched xMeM X11 WSI, paired Termux:X11 protocol
patches, launchers, probes, and qualification notes. Proprietary vendor
libraries are never bundled.

The initial SPHAL/Vulkan/X11 reference implementation was contributed by
[ZenFox3](https://github.com/ZenFox3). See [third-party notices](THIRD_PARTY_NOTICES.md)
for upstream and adapted-work attribution.

## Prebuilt test stack

The **Artifacts** workflow publishes a protocol-matched test stack from
successful `main` source builds and manual runs:

- `proot-sphal-aarch64.tar.xz`: guest runtime installed at `/opt/proot-sphal`.
- `termux-x11-proot-sphal-debug.apk`: patched display server, signed with the
  public Termux:X11 debug key and intended only for testing.
- `termux-x11-nightly-*-all.deb`: matching Termux companion command package.
- `termux-x11-nightly-*-any.pkg.tar.xz`: the same companion for pacman Termux.

Open the latest successful [Artifacts workflow](../../actions/workflows/artifacts.yml),
download both artifact archives, and verify each adjacent `SHA256SUMS` file.
On a computer with ADB, install the Android app and copy the matching companion
and guest archive into Termux's external-files directory:

```sh
adb install -r termux-x11-proot-sphal-debug.apk
adb push termux-x11-nightly-*-all.deb \
  /sdcard/Android/data/com.termux/files/
adb push proot-sphal-aarch64.tar.xz \
  /sdcard/Android/data/com.termux/files/
```

Then, in Termux, install the companion from the same workflow run. The explicit
downgrade permission is necessary when a newer upstream nightly is installed:

```sh
apt install -y --allow-downgrades \
  /sdcard/Android/data/com.termux/files/termux-x11-nightly-*-all.deb
cp /sdcard/Android/data/com.termux/files/proot-sphal-aarch64.tar.xz "$HOME/"
```

The APK and companion package must come from the same workflow run. uDroid's
embedded display server needs the same patches but does not use this standalone
APK.

### Termux PRoot-Distro smoke test

The following sequence was validated on a Pixel 6a with Android 17 and a clean
Ubuntu PRoot-Distro container. Start the patched server, then share Termux's
temporary directory and home directory with the guest:

```sh
termux-x11 :0 &
proot-distro login --shared-tmp \
  --bind "$HOME:/mnt/termux-home" ubuntu
```

Inside the Ubuntu guest, install the WSI runtime dependencies, extract the
runtime, and run the packaged presentation gate:

```sh
apt-get update
apt-get install -y \
  libxcb1 libxcb-present0 libxcb-dri3-0 libxcb-sync1 libx11-xcb1 libstdc++6
tar -xJf /mnt/termux-home/proot-sphal-aarch64.tar.xz -C /

DISPLAY=:0 /opt/proot-sphal/bin/proot-vulkan-x11-run \
  /vendor/lib64/hw/vulkan.mali.so \
  /opt/proot-sphal/libexec/vulkan-xcb-present --frames 120
```

A passing run ends with `PASS stage=present` and `PASS stage=clean-exit`.
The HAL filename is device-specific; select the Vulkan module present under
`/vendor/lib64/hw/` rather than assuming `vulkan.mali.so` on every device.

## Build

Docker with ARM64 emulation or an ARM64 Docker host is required.

```sh
./scripts/build.sh out
```

The package is staged at `out/stage/opt/proot-sphal`. Every external source is
fetched at the exact revision in `build/source-lock.json`; the build fails if
any patch no longer applies or a required artifact is missing.

For source-only checks of the reusable loader API:

```sh
make check
```

## PRoot mounts

The guest needs Android's runtime/vendor trees, Linux pseudo-filesystems, the
X socket, and this package. The equivalent minimum is:

```sh
proot \
  -r ROOTFS \
  -b /system -b /system_ext -b /product -b /vendor -b /odm -b /apex \
  -b /dev -b /proc -b /sys \
  -b /linkerconfig/ld.config.txt \
  -b X11_RUNTIME/.X11-unix:/tmp/.X11-unix \
  -b "$PWD/out/stage/opt/proot-sphal:/opt/proot-sphal" \
  /bin/bash
```

Use the normal SPHAL launcher to inspect any supported vendor module:

```sh
/opt/proot-sphal/bin/proot-sphal-run \
  /vendor/lib64/hw/vulkan.mali.so \
  /opt/proot-sphal/bin/sphal-probe \
  /vendor/lib64/hw/vulkan.mali.so HMI
```

## Vulkan X11

Start the paired patched Termux:X11 server, set `DISPLAY`, then run a Vulkan
application through the complete stack:

```sh
DISPLAY=:0 /opt/proot-sphal/bin/proot-vulkan-x11-run \
  /vendor/lib64/hw/vulkan.mali.so \
  vkmark --present-mode fifo
```

Deterministic gates are packaged in `libexec`:

```sh
DISPLAY=:0 /opt/proot-sphal/bin/proot-vulkan-x11-run \
  /vendor/lib64/hw/vulkan.mali.so \
  /opt/proot-sphal/libexec/vulkan-thread-lifecycle 8 25

DISPLAY=:0 /opt/proot-sphal/bin/proot-vulkan-x11-run \
  /vendor/lib64/hw/vulkan.mali.so \
  /opt/proot-sphal/libexec/vulkan-xcb-present --frames 60
```

Build or apply the server patches using [their pinned baseline and exact roots](patches/termux-x11/README.md).
See [the architecture](docs/ARCHITECTURE.md) and [qualification gates](docs/QUALIFICATION.md).
The relationship to Android's platform Vulkan loader is documented in
[the AOSP loader boundary](docs/AOSP_LOADER_BOUNDARY.md).

## Boundaries

- Rootless interop cannot bypass SELinux or inaccessible device nodes.
- Vendor libraries must match the running Android system.
- The current package targets Android Q or newer on AArch64.
- FIFO is the qualified presentation mode; MAILBOX is not yet implemented.
- Do not redistribute proprietary Android vendor binaries.
