# AOSP Vulkan loader boundary

Reviewed against AOSP `frameworks/native` commit
`4f463a6b1de9198963dc6aff74154a504ba3f8f6` on 2026-10-19.

Android's [platform Vulkan loader](https://android.googlesource.com/platform/frameworks/native/+/4f463a6b1de9198963dc6aff74154a504ba3f8f6/vulkan/libvulkan/)
is the behavioral reference for HAL negotiation, dispatch, promoted extensions,
and create-info sanitization. It is not the guest loader in this project.

The platform loader is built for Bionic and Android native-window surfaces. A
glibc X11 application instead needs the Khronos loader and XCB/Xlib surface
entry points. Replacing it with AOSP `libvulkan` would remove that contract and
pull Android framework dependencies into the guest.

The maintained boundary is:

```text
Linux application
  -> Khronos Vulkan Loader (XCB/Xlib ABI)
  -> xMeM X11 WSI layer (AHardwareBuffer transport)
  -> sysvk HAL adapter (AOSP-compatible driver contract)
  -> vendor Vulkan SPHAL
```

Changes to sysvk should be audited against AOSP's `driver.cpp` behavior, while
window-system presentation remains in the explicit X11 WSI layer.
