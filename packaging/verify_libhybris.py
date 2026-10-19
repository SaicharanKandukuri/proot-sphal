#!/usr/bin/env python3
"""Verify the load-time contract of the packaged AArch64 libhybris."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

PT_DYNAMIC = 2
PT_TLS = 7
DT_NULL = 0
DT_RPATH = 15
DT_RUNPATH = 29
TLS_MIN = 64 * 1024
TLS_MAX = 128 * 1024


def fail(message: str) -> None:
    raise SystemExit(f"verify-libhybris: {message}")


def verify(path: Path) -> int:
    data = path.read_bytes()
    if len(data) < 64 or data[:4] != b"\x7fELF":
        fail(f"not an ELF file: {path}")
    if data[4:7] != bytes((2, 1, 1)):
        fail(f"expected a 64-bit little-endian ELF: {path}")
    elf_type, machine = struct.unpack_from("<HH", data, 16)
    if elf_type != 3 or machine != 183:
        fail(f"expected an AArch64 shared object: {path}")

    table_offset = struct.unpack_from("<Q", data, 32)[0]
    entry_size, count = struct.unpack_from("<HH", data, 54)
    if entry_size < 56 or count == 0 or count > 4096:
        fail("invalid program-header table")

    segments: list[tuple[int, int, int]] = []
    tls_sizes: list[int] = []
    for index in range(count):
        offset = table_offset + index * entry_size
        if offset + 56 > len(data):
            fail("truncated program-header table")
        kind, _flags, file_offset, _vaddr, _paddr, file_size, memory_size, _align = (
            struct.unpack_from("<IIQQQQQQ", data, offset)
        )
        if file_offset > len(data) or file_size > len(data) - file_offset:
            fail("ELF segment lies outside the file")
        segments.append((kind, file_offset, file_size))
        if kind == PT_TLS:
            tls_sizes.append(memory_size)

    if len(tls_sizes) != 1 or not TLS_MIN <= tls_sizes[0] <= TLS_MAX:
        fail(f"expected one {TLS_MIN}..{TLS_MAX}-byte PT_TLS reserve; got {tls_sizes}")

    for kind, file_offset, file_size in segments:
        if kind != PT_DYNAMIC:
            continue
        if file_size % 16:
            fail("malformed dynamic segment")
        for offset in range(file_offset, file_offset + file_size, 16):
            tag, _value = struct.unpack_from("<qQ", data, offset)
            if tag == DT_NULL:
                break
            if tag in (DT_RPATH, DT_RUNPATH):
                fail("libhybris-common must not contain RPATH or RUNPATH")
    return tls_sizes[0]


if __name__ == "__main__":
    if len(sys.argv) != 2:
        fail("usage: verify_libhybris.py LIBHYBRIS_COMMON")
    size = verify(Path(sys.argv[1]))
    print(f"PASS libhybris load contract tls-bytes={size}")
