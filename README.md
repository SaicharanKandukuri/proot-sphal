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

The **Artifacts** workflow publishes a protocol-matched test stack from every
successful `main` build:

- `proot-sphal-aarch64.tar.xz`: guest runtime installed at `/opt/proot-sphal`.
- `termux-x11-proot-sphal-debug.apk`: patched display server, signed with the
  public Termux:X11 debug key and intended only for testing.
- `termux-x11-nightly-*-all.deb`: matching Termux companion command package.
- `termux-x11-nightly-*-any.pkg.tar.xz`: the same companion for pacman Termux.

Open the latest successful [Artifacts workflow](../../actions/workflows/artifacts.yml),
download both artifact archives, and verify each adjacent `SHA256SUMS` file.
Install the Android and Termux pieces with:

```sh
adb install -r termux-x11-proot-sphal-debug.apk
apt install ./termux-x11-nightly-*-all.deb
```

Extract the guest archive into the Linux rootfs, or bind its `opt/proot-sphal`
directory at `/opt/proot-sphal`:

```sh
tar -xJf proot-sphal-aarch64.tar.xz -C ROOTFS
```

The APK and companion package must come from the same workflow run. uDroid's
embedded display server needs the same patches but does not use this standalone
APK.

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
