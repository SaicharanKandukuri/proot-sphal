# Third-party notices

The build fetches pinned revisions of:

- [libhybris](https://github.com/libhybris/libhybris)
- [Linux-on-droid Android headers](https://github.com/Linux-on-droid/android-headers-30)
- [sysvk](https://github.com/xMeM/sysvk)
- [xMeM Vulkan WSI layer](https://github.com/xMeM/vulkan-wsi-layer)
- [Khronos Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers)
- [Khronos Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)

Their licenses remain applicable to the resulting sources, binaries and
headers. Exact revisions are recorded in `build/source-lock.json`.

The initial SPHAL loader, Vulkan dispatch, and X11 AHardwareBuffer reference
implementations shared for this bring-up were written by
[ZenFox3](https://github.com/ZenFox3). The production code in this repository
was subsequently split across pinned libhybris, sysvk, Khronos Loader, and
xMeM WSI components, but retains that work's architectural contribution.

The raw AArch64 thread-pointer patch is adapted from work by Nikita Ukhrenkov
and Sophie Winter in the wmww/libhybris fork:

- [TLS instruction patcher](https://github.com/wmww/libhybris/commit/77bda7a0e47b4426998c0b13fd2d8dd15c4c0b36)
- [Thunk and instruction fixes](https://github.com/wmww/libhybris/commit/56954bf7bc4b0408b29273fbe838b429d600d597)
- [Thread-ID TLS shadow](https://github.com/wmww/libhybris/commit/a7674b19cbd52600e14c990d3897a692140db2ed)

See the source repositories and patch headers for copyright and license details.

The paired server patch set targets
[Termux:X11](https://github.com/termux/termux-x11), which is GPL-3.0 licensed.
Redistributors of a combined Termux:X11 binary must meet its corresponding
source and license obligations. This repository does not bundle that binary.
