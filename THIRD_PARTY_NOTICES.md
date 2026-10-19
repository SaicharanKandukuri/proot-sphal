# Third-party notices

The build fetches pinned revisions of [libhybris](https://github.com/libhybris/libhybris)
and [Linux-on-droid Android headers](https://github.com/Linux-on-droid/android-headers-30).
Their licenses remain applicable to the resulting binaries and headers.

The raw AArch64 thread-pointer patch is adapted from work by Nikita Ukhrenkov
and Sophie Winter in the wmww/libhybris fork:

- [TLS instruction patcher](https://github.com/wmww/libhybris/commit/77bda7a0e47b4426998c0b13fd2d8dd15c4c0b36)
- [Thunk and instruction fixes](https://github.com/wmww/libhybris/commit/56954bf7bc4b0408b29273fbe838b429d600d597)
- [Thread-ID TLS shadow](https://github.com/wmww/libhybris/commit/a7674b19cbd52600e14c990d3897a692140db2ed)

See the source repositories and patch headers for copyright and license details.
