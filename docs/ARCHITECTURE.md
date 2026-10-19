# Rootless vendor Vulkan architecture

```text
Linux Vulkan application
  -> pinned Khronos Vulkan Loader (XCB/Xlib enabled)
  -> patched xMeM AHardwareBuffer X11 WSI layer
  -> patched sysvk ICD
  -> patched libhybris embedded Android linker and isolated Bionic TLS
  -> Android vendor Vulkan HAL
  -> AHardwareBuffer + sync-file private DRI3 transport
  -> paired Termux:X11/Lorie GPU-copy Present path
  -> Android Surface
```

No Mesa, Zink, Panfrost, DRM render node, root access, or proprietary binary is
part of this package. Vendor libraries are loaded from the running Android
system and remain subject to SELinux and device permissions.

## Why each layer exists

- **libhybris** loads the Bionic vendor graph from glibc without writing vendor
  TLS state into glibc's thread-control block.
- **sysvk** exposes a Vulkan ICD and selects a validated absolute HAL path.
- **AHardwareBuffer wrapper** resolves the narrow native-window allocation and
  Unix-socket transport API through the embedded Android linker.
- **xMeM WSI** turns XCB/Xlib swapchains into AHardwareBuffer-backed images and
  negotiates the private transport with the server.
- **Termux:X11 patches** import those buffers, honor acquire fences, copy using
  Android GLES, and delay Present idle notification until the copy is safe.

The xMeM and Termux:X11 patch sets are one protocol. Do not ship one side
without the other. FIFO is the qualified presentation mode; producer FPS is
not proof of physical scanout cadence.

## Source ownership

All external revisions are pinned in `build/source-lock.json`. Reviewable
changes live under `patches/`. The build fetches clean upstream trees and
fails if a patch no longer applies. Proprietary Android libraries must never be
committed or redistributed.
