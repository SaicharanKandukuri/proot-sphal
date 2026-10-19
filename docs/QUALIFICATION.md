# Qualification

A Pixel 6a running Android 17 with an Ubuntu Noble PRoot guest passed:

- isolated Bionic TLS and explicit Mali Vulkan HAL loading;
- concurrent Vulkan instance lifecycle without corrupting glibc TLS;
- XCB surface creation and four-image AHardwareBuffer swapchain;
- visible FIFO presentation through the paired Termux:X11 server;
- `vkmark --present-mode fifo` at 59 FPS / 16.949 ms in the first scene.

The last number is an observed device result, not a cross-device guarantee.
Every Android build and vendor HAL must repeat the gates below.

1. `vulkan-thread-lifecycle 8 25`
2. `vulkan-xcb-present --frames 60`
3. verify `_UDROID_X11_BUFFER_TRANSPORT` compatibility
4. verify `_UDROID_X11_PRESENT_STATS` records GPU-copy offloads
5. FIFO application run, resize, surface loss and clean teardown
6. compositor and desktop soak

Open work: asynchronous server-side fence waiting, strict presentation-mode
advertising, broader Tensor/Exynos/MediaTek qualification, and automatic
fallback when the paired server protocol is absent.
