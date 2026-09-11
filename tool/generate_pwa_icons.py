#!/usr/bin/env python3
"""RELEASE.FINAL: icone PWA = Azzurro Capri #00BFFF + logo bianco (no testo)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "assets/branding/logo_mark_white.png"
OUT = ROOT / "web/icons"
FAVICON = ROOT / "web/favicon.png"

CAPRI = (0x00, 0xBF, 0xFF)

# (path, size, logo_fraction of canvas — maskable più piccolo per safe zone)
SPECS = [
    (OUT / "apple-touch-icon.png", 180, 0.58),
    (OUT / "apple-touch-icon-capri-2026.png", 180, 0.58),
    (OUT / "Icon-192.png", 192, 0.58),
    (OUT / "Icon-192-capri-2026.png", 192, 0.58),
    (OUT / "Icon-512.png", 512, 0.58),
    (OUT / "Icon-512-capri-2026.png", 512, 0.58),
    (OUT / "Icon-1024.png", 1024, 0.58),
    (OUT / "Icon-maskable-192.png", 192, 0.42),
    (OUT / "Icon-maskable-192-capri-2026.png", 192, 0.42),
    (OUT / "Icon-maskable-512.png", 512, 0.42),
    (OUT / "Icon-maskable-512-capri-2026.png", 512, 0.42),
    (FAVICON, 32, 0.58),
]


def render(size: int, logo_frac: float) -> Image.Image:
    canvas = Image.new("RGB", (size, size), CAPRI)
    logo = Image.open(LOGO).convert("RGBA")
    target = max(1, int(round(size * logo_frac)))
    lw, lh = logo.size
    if lw >= lh:
        nw, nh = target, max(1, int(round(target * lh / lw)))
    else:
        nh, nw = target, max(1, int(round(target * lw / lh)))
    logo_r = logo.resize((nw, nh), Image.Resampling.LANCZOS)
    # Hard alpha: evita fringe antialias (solo Capri o bianco puro).
    r, g, b, a = logo_r.split()
    a = a.point(lambda v: 255 if v >= 128 else 0)
    # Forza RGB bianco dove opaco.
    white = Image.new("RGB", logo_r.size, (255, 255, 255))
    logo_hard = Image.merge("RGBA", (*white.split(), a))
    x = (size - nw) // 2
    y = (size - nh) // 2
    canvas.paste(logo_hard, (x, y), logo_hard)
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path, size, frac in SPECS:
        img = render(size, frac)
        img.save(path, format="PNG", optimize=True, compress_level=9)
        print(f"Wrote {path} {size}x{size} logo≈{int(frac*100)}% ({path.stat().st_size} B)")


if __name__ == "__main__":
    main()
