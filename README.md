# proot-sphal

Load Android vendor same-process HALs from an AArch64 glibc PRoot process.
The project packages a pinned, patched libhybris runtime and a small reusable
loader API; it does not include a graphics driver or window-system bridge.

## Why this exists

Android vendor libraries assume Bionic's linker namespaces and thread-control
block layout. Calling them directly from glibc can corrupt glibc TLS. This
runtime uses libhybris' embedded Android linker, reserves an isolated Bionic
TLS region for every host thread, and redirects raw AArch64 `TPIDR_EL0` reads
into that region.

The initial target is Android Q or newer on AArch64. It has been exercised with
the Mali Vulkan HAL on a Pixel 6a running Android 17; another SPHAL remains a
separate device-compatibility test.

## Build

Docker with ARM64 emulation or an ARM64 Docker host is required.

```sh
./scripts/build.sh out
```

The relocatable runtime is staged at `out/stage/opt/proot-sphal`. External
sources are fetched at the exact revisions in `build/source-lock.json`, then
the ordered patches under `patches/libhybris` are applied.

For source-only checks on the loader API:

```sh
make check
```

## PRoot setup

Expose Android's runtime and vendor trees to the guest. At minimum, use the
equivalent of:

```sh
proot \
  -r ROOTFS \
  -b /system -b /system_ext -b /product -b /vendor -b /odm -b /apex \
  -b /dev -b /proc -b /sys \
  -b /linkerconfig/ld.config.txt \
  -b "$PWD/out/stage/opt/proot-sphal:/opt/proot-sphal" \
  /bin/bash
```

Then load and inspect a vendor module:

```sh
/opt/proot-sphal/bin/proot-sphal-run \
  /vendor/lib64/hw/vulkan.mali.so \
  /opt/proot-sphal/bin/sphal-probe \
  /vendor/lib64/hw/vulkan.mali.so HMI
```

Use `proot_sphal_open()` and `proot_sphal_symbol()` from
`include/proot_sphal.h` to embed the loader. Always launch the consumer through
`proot-sphal-run`: `libhybris-common.so.1` must enter the initial ELF load set
so its static TLS reserve exists before `main()`.

## Boundaries

- This is rootless userspace interop, not access to otherwise forbidden device
  nodes or SELinux-restricted files.
- Only `/vendor` and `/odm` root libraries are accepted by the public loader.
- SPHAL loading does not provide Vulkan/GL dispatch, buffer allocation, WSI,
  presentation, or synchronization by itself.
- A vendor library and all of its dependencies must match the running Android
  system. Do not redistribute proprietary vendor binaries.

The raw thread-pointer patch retains links to its upstream authors and commits
in both the patch header and [third-party notices](THIRD_PARTY_NOTICES.md).
