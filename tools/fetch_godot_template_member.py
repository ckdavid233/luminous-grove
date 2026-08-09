#!/usr/bin/env python3
"""Range-download selected members from Godot's official export-template TPZ."""

from __future__ import annotations

import argparse
import binascii
import concurrent.futures
import struct
import sys
import time
import urllib.request
import zlib
from dataclasses import dataclass
from pathlib import Path


DEFAULT_URL = (
    "https://godot-releases.nbg1.your-objectstorage.com/4.7.1-stable/"
    "Godot_v4.7.1-stable_export_templates.tpz"
)
EOCD_SIGNATURE = b"PK\x05\x06"
CENTRAL_SIGNATURE = b"PK\x01\x02"
LOCAL_SIGNATURE = b"PK\x03\x04"


@dataclass(frozen=True)
class ZipMember:
    name: str
    compression: int
    crc32: int
    compressed_size: int
    uncompressed_size: int
    local_offset: int


def fetch_range(url: str, start: int, end: int, attempts: int = 5) -> bytes:
    expected = end - start + 1
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(
            url,
            headers={
                "Range": f"bytes={start}-{end}",
                "User-Agent": "LuminousGroveBuild/0.6",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                data = response.read()
            if len(data) != expected:
                raise OSError(f"expected {expected} bytes, received {len(data)}")
            return data
        except Exception as error:  # noqa: BLE001 - retry transport failures.
            if attempt == attempts:
                raise RuntimeError(
                    f"range {start}-{end} failed after {attempts} attempts"
                ) from error
            time.sleep(float(attempt))
    raise AssertionError("unreachable")


def remote_size(url: str) -> int:
    request = urllib.request.Request(
        url,
        headers={"Range": "bytes=0-0", "User-Agent": "LuminousGroveBuild/0.6"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        content_range = response.headers.get("Content-Range", "")
    if "/" not in content_range:
        raise RuntimeError("official host did not return a ranged Content-Range header")
    return int(content_range.rsplit("/", 1)[1])


def read_central_directory(url: str) -> dict[str, ZipMember]:
    size = remote_size(url)
    tail_start = max(0, size - 131_072)
    tail = fetch_range(url, tail_start, size - 1)
    eocd_index = tail.rfind(EOCD_SIGNATURE)
    if eocd_index < 0:
        raise RuntimeError("ZIP end-of-central-directory record was not found")
    eocd = struct.unpack_from("<4s4H2LH", tail, eocd_index)
    entry_count = eocd[4]
    central_size = eocd[5]
    central_offset = eocd[6]
    central = fetch_range(url, central_offset, central_offset + central_size - 1)
    members: dict[str, ZipMember] = {}
    cursor = 0
    for _ in range(entry_count):
        values = struct.unpack_from("<4s6H3L5H2L", central, cursor)
        if values[0] != CENTRAL_SIGNATURE:
            raise RuntimeError(f"invalid central-directory record at {cursor}")
        compression = values[4]
        crc32 = values[7]
        compressed_size = values[8]
        uncompressed_size = values[9]
        name_length = values[10]
        extra_length = values[11]
        comment_length = values[12]
        local_offset = values[16]
        name_start = cursor + 46
        name = central[name_start : name_start + name_length].decode("utf-8")
        members[name] = ZipMember(
            name,
            compression,
            crc32,
            compressed_size,
            uncompressed_size,
            local_offset,
        )
        cursor = name_start + name_length + extra_length + comment_length
    return members


def member_data_offset(url: str, member: ZipMember) -> int:
    header = fetch_range(url, member.local_offset, member.local_offset + 29)
    values = struct.unpack("<4s5H3L2H", header)
    if values[0] != LOCAL_SIGNATURE:
        raise RuntimeError(f"invalid local header for {member.name}")
    return member.local_offset + 30 + values[9] + values[10]


def extract_member(
    url: str,
    member: ZipMember,
    destination: Path,
    workers: int,
    chunk_size: int,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and destination.stat().st_size == member.uncompressed_size:
        if binascii.crc32(destination.read_bytes()) & 0xFFFFFFFF == member.crc32:
            print(f"SKIP verified {destination}", flush=True)
            return
    data_start = member_data_offset(url, member)
    ranges = []
    cursor = 0
    while cursor < member.compressed_size:
        length = min(chunk_size, member.compressed_size - cursor)
        ranges.append((data_start + cursor, data_start + cursor + length - 1))
        cursor += length
    print(
        f"FETCH {member.name} compressed={member.compressed_size} "
        f"uncompressed={member.uncompressed_size} chunks={len(ranges)}",
        flush=True,
    )
    chunks: list[bytes | None] = [None] * len(ranges)
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        future_indexes = {
            executor.submit(fetch_range, url, start, end): index
            for index, (start, end) in enumerate(ranges)
        }
        completed = 0
        for future in concurrent.futures.as_completed(future_indexes):
            index = future_indexes[future]
            chunks[index] = future.result()
            completed += 1
            print(f"PROGRESS {member.name} {completed}/{len(ranges)}", flush=True)
    compressed = b"".join(chunk for chunk in chunks if chunk is not None)
    if member.compression == 0:
        unpacked = compressed
    elif member.compression == 8:
        unpacked = zlib.decompress(compressed, -zlib.MAX_WBITS)
    else:
        raise RuntimeError(f"unsupported ZIP compression method {member.compression}")
    if len(unpacked) != member.uncompressed_size:
        raise RuntimeError(f"size mismatch while extracting {member.name}")
    if binascii.crc32(unpacked) & 0xFFFFFFFF != member.crc32:
        raise RuntimeError(f"CRC mismatch while extracting {member.name}")
    partial = destination.with_suffix(destination.suffix + ".part")
    partial.write_bytes(unpacked)
    partial.replace(destination)
    print(f"OK {destination} bytes={len(unpacked)} crc32={member.crc32:08x}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--chunk-mib", type=int, default=4)
    parser.add_argument("--list-windows", action="store_true")
    parser.add_argument(
        "members",
        nargs="*",
        default=["templates/windows_release_x86_64.exe", "templates/version.txt"],
    )
    arguments = parser.parse_args()
    members = read_central_directory(arguments.url)
    if arguments.list_windows:
        for name, member in members.items():
            if "windows" in name or name.endswith("version.txt"):
                print(
                    f"{name}\t{member.compressed_size}\t{member.uncompressed_size}"
                )
        return 0
    for name in arguments.members:
        if name not in members:
            print(f"missing TPZ member: {name}", file=sys.stderr)
            return 2
        output_name = name.removeprefix("templates/")
        extract_member(
            arguments.url,
            members[name],
            arguments.output_dir / output_name,
            max(1, arguments.workers),
            max(1, arguments.chunk_mib) * 1024 * 1024,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
