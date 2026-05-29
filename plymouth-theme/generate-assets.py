#!/usr/bin/env python3
"""Generate PoleLinux Plymouth boot splash assets."""

import os
from PIL import Image, ImageDraw

SCRIPT_DIR = os.path.dirname(__file__)
OUT = os.path.join(SCRIPT_DIR, "assets")
os.makedirs(OUT, exist_ok=True)

LOGO_PATH = os.path.join(SCRIPT_DIR, "..", "images", "polebrowse.png")
COLOR_BAR_FG = (100, 180, 255)
COLOR_BAR_BG = (50, 50, 70)
BG_COLOR = (20, 20, 30)
FRAMES = 12
BAR_W = 320
BAR_H = 16
LOGO_W = 200
LOGO_H = 200


def make_background():
    img = Image.new("RGBA", (4096, 2160), BG_COLOR + (255,))
    img.save(os.path.join(OUT, "background.png"), optimize=True)


def make_throbber_bar():
    bg = Image.new("RGBA", (BAR_W, BAR_H), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    draw_bg.rounded_rectangle([0, 0, BAR_W - 1, BAR_H - 1], radius=6,
                              fill=COLOR_BAR_BG + (220,))
    bg.save(os.path.join(OUT, "throbber-bg.png"))

    fg = Image.new("RGBA", (BAR_W, BAR_H), (0, 0, 0, 0))
    draw_fg = ImageDraw.Draw(fg)
    draw_fg.rounded_rectangle([0, 0, BAR_W - 1, BAR_H - 1], radius=6,
                              fill=COLOR_BAR_FG + (220,))
    fg.save(os.path.join(OUT, "throbber-fg.png"))


def make_spinner_frames():
    logo = Image.open(LOGO_PATH).convert("RGBA")
    logo = logo.resize((LOGO_W, LOGO_H), Image.LANCZOS)
    cx, cy = LOGO_W // 2, LOGO_H // 2
    for i in range(FRAMES):
        angle = i * (360 / FRAMES)
        rot = logo.rotate(angle, center=(cx, cy), resample=Image.BICUBIC,
                          fillcolor=(0, 0, 0, 0))
        rot.save(os.path.join(OUT, f"spinner-{i:04d}.png"), optimize=True)


def main():
    print("Generating PoleLinux Plymouth assets...")
    make_background()
    make_throbber_bar()
    make_spinner_frames()
    print(f"  -> {OUT}/")
    for f in sorted(os.listdir(OUT)):
        sz = os.path.getsize(os.path.join(OUT, f))
        print(f"     {f:30s} {sz:>8} B")


if __name__ == "__main__":
    main()
