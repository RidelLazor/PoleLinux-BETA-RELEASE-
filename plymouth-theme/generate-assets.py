#!/usr/bin/env python3
"""Generate PoleLinux Plymouth boot splash assets and GNOME wallpaper."""

import os
import math
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(__file__)
OUT = os.path.join(SCRIPT_DIR, "assets")
os.makedirs(OUT, exist_ok=True)

FRAMES = 12
BAR_W = 320
BAR_H = 16

# Palette
BG = (10, 10, 18)
DARK_BLUE = (15, 20, 40)
ACCENT = (100, 180, 255)
ACCENT_DIM = (60, 120, 200)
BAR_BG = (30, 32, 48)
TEXT_CLR = (200, 210, 230)
LOGO_SIZE = 180


def make_logo():
    """Create a stylized 'P' logo with a modern look."""
    s = LOGO_SIZE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = s // 2, s // 2
    r = s // 2 - 8

    # Outer glow ring
    for i in range(6, 0, -1):
        alpha = int(40 / i)
        draw.ellipse([cx - r - i, cy - r - i, cx + r + i, cy + r + i],
                      fill=ACCENT + (alpha,))

    # Outer ring
    draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                 outline=ACCENT + (220,), width=4)

    # Inner ring
    ir = r - 20
    draw.ellipse([cx - ir, cy - ir, cx + ir, cy + ir],
                 outline=ACCENT_DIM + (100,), width=2)

    # "P" letter in center
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 80)
    except (OSError, IOError):
        font = ImageFont.load_default()

    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx, ty = (s - tw) // 2, (s - th) // 2 - 2
    draw.text((tx, ty), text, fill=ACCENT + (240,), font=font)

    # Small dots at cardinal points
    dot_r = 4
    for angle in [0, 90, 180, 270]:
        dx = int((r - 10) * math.cos(math.radians(angle)))
        dy = int((r - 10) * math.sin(math.radians(angle)))
        draw.ellipse([cx + dx - dot_r, cy + dy - dot_r,
                       cx + dx + dot_r, cy + dy + dot_r],
                      fill=ACCENT + (200,))

    return img


def make_background():
    """Dark gradient Plymouth background with subtle glow."""
    w, h = 4096, 2160
    img = Image.new("RGBA", (w, h), BG + (255,))
    draw = ImageDraw.Draw(img)

    # Subtle radial glow in center
    cx, cy = w // 2, h // 2
    for r in range(1200, 0, -40):
        alpha = max(0, min(35, int(35 * (1 - r / 1200))))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                      fill=DARK_BLUE + (alpha,))

    # Thin horizontal accent line
    draw.rectangle([0, cy - 1, w, cy + 1], fill=ACCENT + (30,))

    img.save(os.path.join(OUT, "background.png"), optimize=True)


def make_wallpaper():
    """GNOME desktop wallpaper with PoleLinux branding."""
    w, h = 1920, 1080
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)

    cx, cy = w // 2, h // 2

    # Radial glow
    for r in range(600, 0, -20):
        alpha = int(30 * (1 - r / 600))
        c = tuple(int(BG[i] + (ACCENT[i] - BG[i]) * alpha / 255) for i in range(3))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

    # Horizontal accent line
    draw.rectangle([0, cy + 60, w, cy + 62], fill=ACCENT + (80,))

    # PoleLinux text
    try:
        font_lg = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
        font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 28)
    except (OSError, IOError):
        font_lg = ImageFont.load_default()
        font_sm = font_lg

    title = "PoleLinux"
    subtitle = "1.0  —  Powered by Debian"

    bbox = draw.textbbox((0, 0), title, font=font_lg)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) // 2, cy - th - 20), title, fill=ACCENT + (240,), font=font_lg)

    bbox = draw.textbbox((0, 0), subtitle, font=font_sm)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) // 2, cy + 80), subtitle, fill=TEXT_CLR + (180,), font=font_sm)

    # Decorative dots
    dot_positions = [(w // 4, h // 4), (3 * w // 4, h // 4),
                     (w // 4, 3 * h // 4), (3 * w // 4, 3 * h // 4)]
    for dx, dy in dot_positions:
        draw.ellipse([dx - 3, dy - 3, dx + 3, dy + 3], fill=ACCENT + (120,))

    img.save(os.path.join(OUT, "wallpaper.png"), optimize=True)
    thumb = img.copy()
    thumb.thumbnail((320, 180), Image.LANCZOS)
    thumb.save(os.path.join(OUT, "wallpaper-thumb.png"), optimize=True)

    # Also save as the main images/wallpaper.png for build-iso.sh compatibility
    img.save(os.path.join(SCRIPT_DIR, "..", "images", "wallpaper.png"), optimize=True)


def make_throbber_bar():
    bg = Image.new("RGBA", (BAR_W, BAR_H), (0, 0, 0, 0))
    draw_bg = ImageDraw.Draw(bg)
    draw_bg.rounded_rectangle([0, 0, BAR_W - 1, BAR_H - 1], radius=6,
                               fill=BAR_BG + (220,))
    bg.save(os.path.join(OUT, "throbber-bg.png"))

    fg = Image.new("RGBA", (BAR_W, BAR_H), (0, 0, 0, 0))
    draw_fg = ImageDraw.Draw(fg)
    draw_fg.rounded_rectangle([0, 0, BAR_W - 1, BAR_H - 1], radius=6,
                               fill=ACCENT + (220,))
    fg.save(os.path.join(OUT, "throbber-fg.png"))


def make_spinner_frames():
    logo = make_logo()

    s = LOGO_SIZE + 40
    cx, cy = s // 2, s // 2
    ring_r = s // 2 - 12

    for i in range(FRAMES):
        frame = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)

        angle = i * (360 / FRAMES)

        # Rotating arc segments on the ring
        for j in range(4):
            a = angle + j * 90
            start_a = a - 20
            end_a = a + 20
            alpha = 200 if j == 0 else (120 if j == 1 else (60 if j == 2 else 20))
            draw.arc([12, 12, s - 12, s - 12], start_a, end_a,
                      fill=ACCENT + (alpha,), width=5)

        # Rotate and paste the logo
        rot = logo.rotate(-angle, center=(LOGO_SIZE // 2, LOGO_SIZE // 2),
                          resample=Image.BICUBIC, fillcolor=(0, 0, 0, 0))
        paste_x = (s - LOGO_SIZE) // 2
        paste_y = (s - LOGO_SIZE) // 2
        frame.paste(rot, (paste_x, paste_y), rot)

        # Small pulsing dot
        dot_angle = math.radians(angle)
        dot_dist = ring_r
        dot_x = int(cx + dot_dist * math.cos(dot_angle))
        dot_y = int(cy + dot_dist * math.sin(dot_angle))
        dr = 4
        draw.ellipse([dot_x - dr, dot_y - dr, dot_x + dr, dot_y + dr],
                      fill=ACCENT + (255,))

        frame.save(os.path.join(OUT, f"spinner-{i:04d}.png"), optimize=True)


def main():
    print("Generating PoleLinux Plymouth assets...")
    make_background()
    make_wallpaper()
    make_throbber_bar()
    make_spinner_frames()
    print(f"  -> {OUT}/")
    for f in sorted(os.listdir(OUT)):
        sz = os.path.getsize(os.path.join(OUT, f))
        print(f"     {f:30s} {sz:>8} B")


if __name__ == "__main__":
    main()
