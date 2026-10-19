#!/usr/bin/env bash
set -euo pipefail

usage()
{
    printf 'Usage: %s TERMUX_X11_SOURCE\n' "${0##*/}" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
source_dir=$1
expected_revision=$(python3 - "$repo_root/build/source-lock.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)["sources"]["termux_x11"]["revision"])
PY
)

[[ $(git -C "$source_dir" rev-parse --is-inside-work-tree \
    2>/dev/null || true) == true ]] || {
    printf 'termux-x11 patches: not a Git checkout: %s\n' "$source_dir" >&2
    exit 2
}
actual_revision=$(git -C "$source_dir" rev-parse HEAD)
[[ $actual_revision == "$expected_revision" ]] || {
    printf 'termux-x11 patches: expected %s, found %s\n' \
        "$expected_revision" "$actual_revision" >&2
    exit 3
}
[[ $(git -C "$source_dir/lorie/src/main/cpp/xserver" \
    rev-parse --is-inside-work-tree 2>/dev/null || true) == true ]] || {
    printf 'termux-x11 patches: recursive submodules are not initialized\n' >&2
    exit 3
}

apply_patch()
{
    local root=$1 patch=$2
    git -C "$root" apply --check "$patch"
    git -C "$root" apply "$patch"
}

apply_patch "$source_dir" \
    "$repo_root/patches/termux-x11/0001-import-rgba-ahardwarebuffer-content-without-swizzle.patch"
apply_patch "$source_dir/lorie/src/main/cpp/xserver" \
    "$repo_root/patches/termux-x11/0002-import-linux-sync-file-fences.patch"
apply_patch "$source_dir/lorie/src/main/cpp/lorie" \
    "$repo_root/patches/termux-x11/0003-use-realtime-for-timed-mutex-deadline.patch"
apply_patch "$source_dir/lorie/src/main/cpp/lorie" \
    "$repo_root/patches/termux-x11/0004-gate-gpu-copy-hot-path-logging.patch"
apply_patch "$source_dir" \
    "$repo_root/patches/termux-x11/0005-advertise-buffer-transport-protocol.patch"
apply_patch "$source_dir" \
    "$repo_root/patches/termux-x11/0006-publish-present-offload-statistics.patch"

git -C "$source_dir" diff --check
git -C "$source_dir/lorie/src/main/cpp/xserver" diff --check
printf 'PASS Termux:X11 patch series applied to %s\n' "$actual_revision"
