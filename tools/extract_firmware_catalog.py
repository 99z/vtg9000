#!/usr/bin/env python3
"""Extract the 113 human-readable VTG 400 DVI rate labels from firmware.

The catalog stores names, active dimensions, and displayed H/V rates. It does
not contain enough independently decoded information to claim full modelines.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
from pathlib import Path

EXPECTED_SHA256 = "e01f4a4a15b1bb3eeb31c462fb5510005fcc2ce59e98b416a2094c2684661f04"

RATE_RE = re.compile(
    rb"(?P<name>[A-Za-z0-9:+,/ .()\-]{1,30}?)"
    rb"(?P<width>\d{3,4})x(?P<height>\d{3,4})\s*"
    rb"(?P<h_khz>\d{2,3}\.\d{2})kHz\s*"
    rb"(?P<v_hz>\d{2,3}(?:\.\d{2})?|\d+/\d+)Hz"
)

CATEGORY_RANGES = (
    (1, 25, "PC"),
    (26, 53, "CAD workstation"),
    (54, 63, "Stereographics"),
    (64, 67, "Super high resolution"),
    (68, 86, "16:9 high resolution"),
    (87, 108, "HDTV"),
    (109, 113, "Video/other"),
)


def category_for(index: int) -> str:
    for first, last, category in CATEGORY_RANGES:
        if first <= index <= last:
            return category
    raise ValueError(f"catalog index outside known groups: {index}")


def extract(firmware: Path) -> list[dict[str, str | int]]:
    blob = firmware.read_bytes()
    digest = hashlib.sha256(blob).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(
            "firmware SHA-256 does not match the analyzed VTG 400 DVI v2.05 image: "
            f"{digest}"
        )

    marker = blob.index(b"E2_UPD") + len(b"E2_UPD")
    rows: list[dict[str, str | int]] = []
    for index, match in enumerate(RATE_RE.finditer(blob, marker), start=1):
        if index > 113:
            break
        row = {key: value.decode("ascii").strip() for key, value in match.groupdict().items()}
        row["index"] = index
        row["category"] = category_for(index)
        rows.append(row)

    if len(rows) != 113:
        raise ValueError(f"expected 113 rate records, extracted {len(rows)}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("firmware", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    rows = extract(args.firmware)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=("index", "category", "name", "width", "height", "h_khz", "v_hz"),
        )
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} rates to {args.output}")


if __name__ == "__main__":
    main()
