#!/usr/bin/env python3
"""STARTUP.DECISIVE: apple-touch-startup-image = Capri + logo + titolo."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "assets/branding/logo_mark_white.png"
FONT_BOLD = ROOT / "google_fonts/Montserrat-Bold.ttf"
OUT_DIR = ROOT / "web/icons/startup"

SPECS = [
    ("launch-1125x2436.png", 375, 812),
    ("launch-1170x2532.png", 390, 844),
    ("launch-1179x2556.png", 393, 852),
    ("launch-1206x2622.png", 402, 874),
    ("launch-1242x2688.png", 414, 896),
    ("launch-1284x2778.png", 428, 926),
    ("launch-1290x2796.png", 430, 932),
]

DPR = 3
BG = (0x00, 0xBF, 0xFF)
LOGO_H_LOGICAL = 100
GAP_LOGICAL = 24
TITLE_SIZE_LOGICAL = 22
TITLE = "Scuola Nautica Liana"


def render(logical_w: int, logical_h: int) -> Image.Image:
    w, h = logical_w * DPR, logical_h * DPR
    canvas = Image.new("RGB", (w, h), BG)
    logo = Image.open(LOGO).convert("RGBA")
    logo_h = LOGO_H_LOGICAL * DPR
    logo_w = int(round(logo.width * (logo_h / logo.height)))
    logo_r = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)

    font = ImageFont.truetype(str(FONT_BOLD), TITLE_SIZE_LOGICAL * DPR)
    draw = ImageDraw.Draw(canvas)
    bbox = draw.textbbox((0, 0), TITLE, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    gap = GAP_LOGICAL * DPR
    block_h = logo_h + gap + th
    top = (h - block_h) // 2

    lx = (w - logo_w) // 2
    canvas.paste(logo_r, (lx, top), logo_r)
    tx = (w - tw) // 2
    ty = top + logo_h + gap - bbox[1]
    draw.text((tx, ty), TITLE, font=font, fill=(255, 255, 255, 255))
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, lw, lh in SPECS:
        img = render(lw, lh)
        out = OUT_DIR / name
        img.save(out, format="PNG", optimize=True, compress_level=9)
        print(f"Wrote {out} {img.size[0]}x{img.size[1]} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
