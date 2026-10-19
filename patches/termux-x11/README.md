# Paired Termux:X11 server patches

The AHardwareBuffer WSI and the X server form one private protocol revision.
Apply these patches in numeric order to Termux:X11 commit
`0cb0203c283bfafbad380b90444296aa42af058d`.

For a clean checkout, the repository helper validates the pinned revision and
applies every patch at its correct nested repository root:

```sh
./scripts/apply-termux-x11-patches.sh /path/to/termux-x11
```

Patch roots differ because Xorg is a nested source repository:

```sh
git -C termux-x11 apply /path/to/0001-import-rgba-ahardwarebuffer-content-without-swizzle.patch
git -C termux-x11/lorie/src/main/cpp/xserver apply /path/to/0002-import-linux-sync-file-fences.patch
git -C termux-x11/lorie/src/main/cpp/lorie apply /path/to/0003-use-realtime-for-timed-mutex-deadline.patch
git -C termux-x11/lorie/src/main/cpp/lorie apply /path/to/0004-gate-gpu-copy-hot-path-logging.patch
git -C termux-x11 apply /path/to/0005-advertise-buffer-transport-protocol.patch
git -C termux-x11 apply /path/to/0006-publish-present-offload-statistics.patch
```

The server publishes `_UDROID_X11_BUFFER_TRANSPORT` only when it supports the
paired AHardwareBuffer socket, RGBA/BGRA content identifiers, sync-file acquire
fences and GPU-copy Present path. It publishes cumulative offload/fallback
counters in `_UDROID_X11_PRESENT_STATS`.

These patches were validated as a series against the pinned revision. uDroid
carries additional embedding and lifecycle patches; those remain in the
uDroid app repository rather than being duplicated here.
