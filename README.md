# proot-sphal

Canonical source for running Android vendor Vulkan from an AArch64 glibc PRoot
guest and presenting it through a paired Termux:X11 server.

It contains the complete reproducible path: patched libhybris, sysvk, the
AHardwareBuffer wrapper, patched xMeM X11 WSI, paired Termux:X11 protocol
patches, launchers, probes, and qualification notes. Proprietary vendor
libraries are never bundled.

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

Apply the server patches using [their pinned baseline and exact roots](patches/termux-x11/README.md).
See [the architecture](docs/ARCHITECTURE.md) and [qualification gates](docs/QUALIFICATION.md).

## Boundaries

- Rootless interop cannot bypass SELinux or inaccessible device nodes.
- Vendor libraries must match the running Android system.
- The current package targets Android Q or newer on AArch64.
- FIFO is the qualified presentation mode; MAILBOX is not yet implemented.
- Do not redistribute proprietary Android vendor binaries.
