#!/usr/bin/env python3
"""
Generates all platform app icons for move-item-sorter.

Design concept:
  • Deep-blue rounded square background with a subtle radial highlight
  • White open moving-box with an up-arrow indicating items being sorted
  • Three coloured category dots (blue/green/orange) as a visual motif
  • Clean, modern, legible at every size from 16 px to 1024 px

Run from the repo root:
    python3 scripts/generate_icons.py
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).parent.parent

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
BG_TOP    = (21,  101, 192)   # #1565C0  primary blue
BG_BOT    = (13,   71, 161)   # #0D47A1  deeper blue
GLOW      = (66,  165, 245, 60)  # soft highlight (RGBA)
WHITE     = (255, 255, 255)
SHADOW    = (0,   0,   0,  50)

CAT_MOVE    = (33,  150, 243)   # blue
CAT_DONATE  = (76,  175,  80)   # green
CAT_SELL    = (255, 152,   0)   # orange
CAT_STORE   = (156,  39, 176)   # purple
CAT_RECYCLE = (0,   188, 212)   # cyan
CAT_TRASH   = (158, 158, 158)   # grey

# ---------------------------------------------------------------------------
# Core drawing
# ---------------------------------------------------------------------------

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def draw_icon(size: int) -> Image.Image:
    """Render one square icon at the given pixel size."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    radius = max(1, int(s * 0.22))

    # ---- Background gradient (top-left bright, bottom-right dark) ----------
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(s):
        t = y / s
        colour = lerp(BG_TOP, BG_BOT, t)
        bg_draw.line([(0, y), (s, y)], fill=colour)

    # Paste gradient, then mask with rounded rect
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius, fill=255)
    img.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(img, "RGBA")

    # ---- Subtle inner glow (top-centre radial highlight) -------------------
    glow_r = int(s * 0.45)
    gx, gy = s // 2, int(s * 0.18)
    for step in range(glow_r, 0, -1):
        alpha = int(40 * (1 - step / glow_r))
        draw.ellipse(
            [gx - step, gy - step, gx + step, gy + step],
            fill=(255, 255, 255, alpha),
        )

    # ---- Moving box --------------------------------------------------------
    # Box occupies roughly the middle 55 % of the icon
    bx = int(s * 0.20)
    by = int(s * 0.38)
    bw = int(s * 0.60)
    bh = int(s * 0.42)
    lw = max(1, s // 64)

    # Box body (filled semi-transparent white, then white stroke)
    draw.rectangle([bx, by, bx + bw, by + bh],
                   fill=(255, 255, 255, 38), outline=WHITE, width=lw)

    # Flap fold line (horizontal, at top of box, offset inward)
    flap_y = by + int(bh * 0.28)
    draw.line([(bx, flap_y), (bx + bw, flap_y)], fill=WHITE, width=lw)

    # Left flap (angled up-left)
    flap_tip_x = bx + int(bw * 0.30)
    flap_tip_y = by - int(bh * 0.12)
    draw.polygon(
        [(bx, flap_y), (bx + int(bw * 0.50), flap_y),
         (flap_tip_x, flap_tip_y), (bx, by)],
        fill=(255, 255, 255, 55), outline=WHITE,
    )

    # Right flap (angled up-right)
    flap_tip_rx = bx + int(bw * 0.70)
    draw.polygon(
        [(bx + int(bw * 0.50), flap_y), (bx + bw, flap_y),
         (bx + bw, by), (flap_tip_rx, flap_tip_y)],
        fill=(255, 255, 255, 55), outline=WHITE,
    )

    # ---- Up-arrow inside box (items being sorted / lifted out) -------------
    ax = bx + bw // 2
    ay_top = flap_tip_y - int(s * 0.07)  # arrow tip
    ay_mid = by + int(bh * 0.22)         # arrow shaft top
    ay_bot = by + int(bh * 0.66)         # arrow shaft bottom
    aw = max(2, int(s * 0.045))          # half shaft width
    ah = max(2, int(s * 0.085))          # arrowhead half-width

    # Arrowhead
    draw.polygon(
        [(ax, ay_top), (ax - ah, ay_mid), (ax + ah, ay_mid)],
        fill=WHITE,
    )
    # Shaft
    draw.rectangle(
        [ax - aw, ay_mid, ax + aw, ay_bot],
        fill=WHITE,
    )

    # ---- Category colour dots (bottom row) ---------------------------------
    dot_colours = [CAT_MOVE, CAT_DONATE, CAT_SELL]
    n = len(dot_colours)
    dot_r = max(2, int(s * 0.045))
    dot_y = by + bh + int(s * 0.065)
    spacing = bw // (n + 1)
    for i, col in enumerate(dot_colours):
        cx = bx + spacing * (i + 1)
        draw.ellipse([cx - dot_r, dot_y - dot_r, cx + dot_r, dot_y + dot_r],
                     fill=col)

    # ---- Drop shadow (faint, bottom-right) — only for large sizes ----------
    if s >= 64:
        shadow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        sh_draw = ImageDraw.Draw(shadow_layer)
        sh_offset = max(1, s // 40)
        sh_draw.rounded_rectangle(
            [sh_offset, sh_offset, s - 1, s - 1],
            radius=radius, fill=(0, 0, 0, 35),
        )
        img = Image.alpha_composite(shadow_layer, img)

    return img


# ---------------------------------------------------------------------------
# Maskable (safe-zone) variant — icon padded to 80 % of canvas
# ---------------------------------------------------------------------------

def draw_maskable_icon(size: int) -> Image.Image:
    """Same icon but padded to keep content in the safe zone for maskable icons."""
    inner = draw_icon(int(size * 0.80))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - inner.size[0]) // 2
    canvas.paste(inner, (offset, offset), inner)
    return canvas


# ---------------------------------------------------------------------------
# Windows ICO helper
# ---------------------------------------------------------------------------

def save_ico(path: Path, sizes=(16, 24, 32, 48, 64, 128, 256)):
    images = [draw_icon(s).convert("RGBA") for s in sizes]
    images[0].save(
        path,
        format="ICO",
        sizes=[(img.size[0], img.size[1]) for img in images],
        append_images=images[1:],
    )
    print(f"  Saved  {path}")


# ---------------------------------------------------------------------------
# iOS Contents.json helper
# ---------------------------------------------------------------------------

def ios_contents_json(entries):
    import json
    images = []
    for size, scale, fname in entries:
        images.append({
            "filename": fname,
            "idiom": "universal",
            "platform": "ios",
            "size": size,
            "scale": scale,
        })
    return json.dumps({"images": images, "info": {"author": "xcode", "version": 1}},
                      indent=2)


def macos_contents_json(entries):
    import json
    images = []
    for size, scale, fname in entries:
        images.append({
            "filename": fname,
            "idiom": "mac",
            "size": size,
            "scale": scale,
        })
    return json.dumps({"images": images, "info": {"author": "xcode", "version": 1}},
                      indent=2)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGBA").save(path, "PNG")
    print(f"  Saved  {path.relative_to(ROOT)}")


def main():
    print("Generating Move Item Sorter app icons…\n")

    # ── Android ─────────────────────────────────────────────────────────────
    print("Android mipmap icons")
    android_sizes = {
        "mipmap-mdpi":    48,
        "mipmap-hdpi":    72,
        "mipmap-xhdpi":   96,
        "mipmap-xxhdpi":  144,
        "mipmap-xxxhdpi": 192,
    }
    base = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, sz in android_sizes.items():
        save(draw_icon(sz), base / folder / "ic_launcher.png")
        # round icon variant
        save(draw_icon(sz), base / folder / "ic_launcher_round.png")

    # Adaptive icon foreground / background (xxxhdpi canvas = 432 px)
    fg = draw_maskable_icon(432)
    bg = Image.new("RGBA", (432, 432), (*BG_BOT, 255))
    save(fg, base / "mipmap-anydpi-v26" / "ic_launcher_foreground.png")
    save(bg, base / "mipmap-anydpi-v26" / "ic_launcher_background.png")

    # ── iOS ─────────────────────────────────────────────────────────────────
    print("\niOS AppIcon sizes")
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_entries = [
        # (size_string, scale_string, pixel_size)
        ("20x20",   "1x",  20),
        ("20x20",   "2x",  40),
        ("20x20",   "3x",  60),
        ("29x29",   "1x",  29),
        ("29x29",   "2x",  58),
        ("29x29",   "3x",  87),
        ("40x40",   "1x",  40),
        ("40x40",   "2x",  80),
        ("40x40",   "3x",  120),
        ("60x60",   "2x",  120),
        ("60x60",   "3x",  180),
        ("76x76",   "1x",  76),
        ("76x76",   "2x",  152),
        ("83.5x83.5","2x", 167),
        ("1024x1024","1x", 1024),
    ]
    contents_entries = []
    seen_px = {}
    for size_str, scale_str, px in ios_entries:
        fname = f"Icon-{px}.png"
        if px not in seen_px:
            save(draw_icon(px), ios_dir / fname)
            seen_px[px] = fname
        contents_entries.append((size_str, scale_str, seen_px[px]))
    (ios_dir / "Contents.json").write_text(ios_contents_json(contents_entries))
    print(f"  Saved  ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json")

    # ── macOS ────────────────────────────────────────────────────────────────
    print("\nmacOS AppIcon sizes")
    macos_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos_entries = [
        ("16x16",   "1x",  16), ("16x16",   "2x",  32),
        ("32x32",   "1x",  32), ("32x32",   "2x",  64),
        ("128x128", "1x",  128),("128x128", "2x",  256),
        ("256x256", "1x",  256),("256x256", "2x",  512),
        ("512x512", "1x",  512),("512x512", "2x",  1024),
    ]
    seen_px = {}
    macos_contents = []
    for size_str, scale_str, px in macos_entries:
        fname = f"app_icon_{px}.png"
        if px not in seen_px:
            save(draw_icon(px), macos_dir / fname)
            seen_px[px] = fname
        macos_contents.append((size_str, scale_str, seen_px[px]))
    (macos_dir / "Contents.json").write_text(macos_contents_json(macos_contents))
    print(f"  Saved  macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json")

    # ── Web ──────────────────────────────────────────────────────────────────
    print("\nWeb PWA icons")
    web_dir = ROOT / "web"
    save(draw_icon(192),  web_dir / "icons" / "Icon-192.png")
    save(draw_icon(512),  web_dir / "icons" / "Icon-512.png")
    save(draw_maskable_icon(192), web_dir / "icons" / "Icon-maskable-192.png")
    save(draw_maskable_icon(512), web_dir / "icons" / "Icon-maskable-512.png")
    # favicon
    fav16  = draw_icon(16).convert("RGB")
    fav32  = draw_icon(32).convert("RGB")
    fav48  = draw_icon(48).convert("RGB")
    fav16.save(web_dir / "favicon.png", "PNG")
    fav16.save(web_dir / "favicon.ico", format="ICO",
               sizes=[(16, 16), (32, 32), (48, 48)],
               append_images=[fav32, fav48])
    print(f"  Saved  web/favicon.png + web/favicon.ico")

    # ── Windows ──────────────────────────────────────────────────────────────
    print("\nWindows ICO")
    save_ico(ROOT / "windows" / "runner" / "resources" / "app_icon.ico")

    # ── Linux ────────────────────────────────────────────────────────────────
    print("\nLinux icons (hicolor)")
    linux_sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    for sz in linux_sizes:
        save(draw_icon(sz),
             ROOT / "linux" / "data" / "icons" / f"move_item_sorter_{sz}.png")

    # ── Generic assets ───────────────────────────────────────────────────────
    print("\nGeneric assets")
    save(draw_icon(1024), ROOT / "assets" / "icons" / "app_icon_1024.png")
    save(draw_icon(512),  ROOT / "assets" / "icons" / "app_icon_512.png")
    save(draw_icon(192),  ROOT / "assets" / "icons" / "app_icon_192.png")

    print("\nAll icons generated successfully.")


if __name__ == "__main__":
    main()
