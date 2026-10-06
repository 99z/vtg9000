#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Reject missing, malformed or failing Quartus 17.0.2 timing summaries."""
import math
import re
import sys
from pathlib import Path

REQUIRED = {"Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width"}


def check_summary(path):
    summary = Path(path).read_text()
    blocks = re.split(r"^Type\s*:\s*", summary, flags=re.MULTILINE)[1:]
    seen = set()
    failures = []
    for block in blocks:
        kind = block.split(" '", 1)[0].splitlines()[0].strip()
        if kind not in REQUIRED:
            raise ValueError(f"Unknown timing category: {kind}")
        values = re.findall(r"^Slack\s*:\s*(\S+)\s*$", block, flags=re.MULTILINE)
        if len(values) != 1:
            raise ValueError(f"Missing or ambiguous slack for {kind}")
        slack = float(values[0])
        if not math.isfinite(slack):
            raise ValueError(f"Non-finite slack for {kind}")
        seen.add(kind)
        if slack < 0:
            failures.append(f"{kind}: {slack:+.3f} ns")
    missing = REQUIRED - seen
    if missing:
        raise ValueError("Missing timing categories: " + ", ".join(sorted(missing)))
    if failures:
        raise ValueError("Timing violations: " + "; ".join(failures))


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check_quartus_timing.py VTG9000.sta.summary")
    try:
        check_summary(sys.argv[1])
    except (OSError, ValueError) as error:
        print(f"Timing check failed: {error}", file=sys.stderr)
        return 1
    print("PASS: all reported setup/hold/recovery/removal/pulse-width slacks are nonnegative")
    return 0


if __name__ == "__main__":
    sys.exit(main())
