"""Generate app icon PNGs for Clinix.
Run: python _generate_icon.py
Produces app_icon.png (full icon) and app_icon_foreground.png (transparent fg).
"""
from PIL import Image, ImageDraw


def _rounded_square(size: int, radius: int, fill):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=fill)
    return img


def _draw_spa_glyph(img: Image.Image, color=(255, 255, 255, 255)):
    """Draw a simplified 'spa' / leaf / wellness glyph (matches Icons.spa_rounded)."""
    draw = ImageDraw.Draw(img)
    w, h = img.size
    cx, cy = w // 2, h // 2
    r = w // 6  # central circle radius

    # Center circle (flower core)
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=color)

    # 6 leaves around the circle
    leaf_w = w // 4
    leaf_h = w // 3
    import math
    for i in range(6):
        angle = math.radians(i * 60 - 90)
        lx = cx + int(math.cos(angle) * r * 2.2)
        ly = cy + int(math.sin(angle) * r * 2.2)
        # Draw ellipse rotated toward center
        leaf = Image.new('RGBA', (leaf_w, leaf_h), (0, 0, 0, 0))
        ldraw = ImageDraw.Draw(leaf)
        ldraw.ellipse([(0, 0), (leaf_w - 1, leaf_h - 1)], fill=color)
        rotated = leaf.rotate(-i * 60, resample=Image.BICUBIC, expand=True)
        rx = lx - rotated.width // 2
        ry = ly - rotated.height // 2
        img.alpha_composite(rotated, (rx, ry))


def generate():
    size = 1024
    radius = int(size * 0.22)

    # Full icon: dark slate background + white spa glyph
    bg = _rounded_square(size, radius, fill=(15, 23, 42, 255))  # #0F172A
    _draw_spa_glyph(bg, color=(255, 255, 255, 255))
    bg.save('app_icon.png', 'PNG')
    print('Wrote app_icon.png')

    # Foreground: transparent background, just the white glyph, smaller
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    _draw_spa_glyph(fg, color=(255, 255, 255, 255))
    fg.save('app_icon_foreground.png', 'PNG')
    print('Wrote app_icon_foreground.png')


if __name__ == '__main__':
    generate()
