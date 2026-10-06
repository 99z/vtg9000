#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Export verified simulation frames as a README preview (requires Pillow)."""
from hashlib import sha256
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FRAMES = [(17, "MONOSCOPE"), (13, "SMPTE BARS / PLUGE")]


def main():
    expected = {}
    for line in (ROOT / "tb/golden_frames.sha256").read_text().splitlines():
        digest, path = line.split(None, 1)
        expected[path] = digest
    canvas = Image.new("RGB", (1488, 620), "#101a2b")
    draw = ImageDraw.Draw(canvas)
    try:
        label_font = ImageFont.truetype("DejaVuSans.ttf", 18)
        caption_font = ImageFont.truetype("DejaVuSans.ttf", 14)
    except OSError:
        label_font = caption_font = ImageFont.load_default()
    for column, (pattern, label) in enumerate(FRAMES):
        relative = f"build/frames/pattern_{pattern}.ppm"
        source = ROOT / relative
        if sha256(source.read_bytes()).hexdigest() != expected[relative]:
            raise SystemExit(f"Frame differs from golden hash: {relative}")
        # Native SD samples have 8:9 pixel aspect. Expand rows for a 4:3
        # presentation preview; these images are not a pixel-analysis source.
        image = Image.open(source).convert("RGB")
        image = image.resize((720, 540), Image.Resampling.NEAREST)
        left = 16 + column * 736
        draw.text((left, 14), label, font=label_font, fill="#e8eef8")
        canvas.paste(image, (left, 44))
    draw.text((16, 596), "SIMULATION PREVIEWS  /  0 IRE  /  4:3 DISPLAY ASPECT", font=caption_font, fill="#a4b4cd")
    target = ROOT / "docs/images/pattern-previews.png"
    canvas.save(target, optimize=True)
    print(f"Wrote {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
