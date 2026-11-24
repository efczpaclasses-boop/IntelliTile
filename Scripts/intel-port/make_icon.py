#!/usr/bin/env python3
"""Generate IntelliTile's original app icon (Intel Mac port of k97/dock-tile).

Procedural, no third-party art: a 2x2 grid of rounded tiles in cool colours, with the
bottom-right tile drawn as an outlined chip (pins on every side) for "Intel". Deliberately
unlike the original project's icon (an orange ring with a half-sun and horizon lines).

Writes, relative to the repo root:
  DockTile/Resources/AppIcon.icon/       (Icon Composer bundle; Xcode 26 also renders the
  DockTile/Resources/AppIcon-Dev.icon/    flattened Sequoia icon from it)
  DockTile/Resources/DockTileGlyph.png    (white brand glyph used by the symbol picker; the
                                           resource name is kept so code is unchanged)
  appicon/intellitile/AppIcon.iconset/    (all macOS sizes 16..1024, for reference/DMG use)

Usage: python3 Scripts/intel-port/make_icon.py   (needs Pillow)
"""
import json, os, shutil
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SS = 4            # supersampling factor
N = 1024          # output size

RELEASE = {'tl': ((20, 184, 166), (13, 148, 136)),   # teal
           'tr': ((99, 102, 241), (79, 70, 229)),    # indigo
           'bl': ((14, 165, 233), (2, 132, 199)),    # sky
           'chip': (79, 70, 229), 'bg': ((236, 244, 255), (205, 222, 250))}
DEV = {'tl': ((148, 163, 184), (100, 116, 139)),     # slate
       'tr': ((245, 158, 11), (217, 119, 6)),        # amber
       'bl': ((148, 163, 184), (100, 116, 139)),
       'chip': (217, 119, 6), 'bg': ((245, 245, 244), (214, 211, 209))}


def vgrad(size, top, bottom):
    w, h = size
    g = Image.new('RGBA', (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((w, h))


def rounded_mask(size, box, radius, outline=None):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    if outline:
        d.rounded_rectangle(box, radius, outline=255, width=outline)
    else:
        d.rounded_rectangle(box, radius, fill=255)
    return m


def tiles_geometry(n):
    tile = int(n * 0.30); gap = int(n * 0.055)
    x0 = (n - (2 * tile + gap)) // 2
    pos = {'tl': (x0, x0), 'tr': (x0 + tile + gap, x0), 'bl': (x0, x0 + tile + gap),
           'br': (x0 + tile + gap, x0 + tile + gap)}
    return tile, pos, int(tile * 0.24)


def draw_chip(layer, x, y, tile, radius, color, n):
    """Outlined square with a filled inner die and pins on all four sides."""
    d = ImageDraw.Draw(layer)
    inset = int(tile * 0.16); w = max(4, int(n * 0.022))
    body = (x + inset, y + inset, x + tile - inset, y + tile - inset)
    d.rounded_rectangle(body, int(radius * 0.6), outline=color + (255,), width=w)
    core = int(tile * 0.36)
    cx0 = x + (tile - core) // 2; cy0 = y + (tile - core) // 2
    d.rounded_rectangle((cx0, cy0, cx0 + core, cy0 + core), int(core * 0.18), fill=color + (255,))
    pin_len = inset - int(n * 0.006); pin_w = max(3, int(n * 0.016))
    for i in range(3):
        off = body[0] + (body[2] - body[0]) * (i + 1) // 4 - pin_w // 2
        d.rectangle((off, y + int(n * 0.004), off + pin_w, y + pin_len), fill=color + (255,))
        d.rectangle((off, y + tile - pin_len, off + pin_w, y + tile - int(n * 0.004)), fill=color + (255,))
        d.rectangle((x + int(n * 0.004), off, x + pin_len, off + pin_w), fill=color + (255,))
        d.rectangle((x + tile - pin_len, off, x + tile - int(n * 0.004), off + pin_w), fill=color + (255,))


def glyph_layer(palette, with_background):
    n = N * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    if with_background:
        img.alpha_composite(vgrad((n, n), *palette['bg']))
    tile, pos, r = tiles_geometry(n)
    for key in ('tl', 'tr', 'bl'):
        x, y = pos[key]
        g = vgrad((tile, tile), *palette[key])
        img.paste(g, (x, y), rounded_mask((tile, tile), (0, 0, tile - 1, tile - 1), r))
    x, y = pos['br']
    draw_chip(img, x, y, tile, r, palette['chip'], n)
    return img.resize((N, N), Image.LANCZOS)


def white_glyph():
    n = N * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    tile, pos, r = tiles_geometry(n)
    d = ImageDraw.Draw(img)
    for key in ('tl', 'tr', 'bl'):
        x, y = pos[key]
        d.rounded_rectangle((x, y, x + tile, y + tile), r, fill=(255, 255, 255, 255))
    x, y = pos['br']
    draw_chip(img, x, y, tile, r, (255, 255, 255), n)
    return img.resize((N, N), Image.LANCZOS)


ICON_JSON = {  # same keys/shape as the original project's icon.json (known to compile in Xcode 26.2)
    "fill": "automatic",
    "groups": [{
        "blur-material": None,
        "layers": [{"image-name": "intellitile.png", "name": "intellitile"}],
        "shadow": {"kind": "layer-color", "opacity": 0.5},
        "specular": False,
        "translucency": {"enabled": False, "value": 0.5},
    }],
    "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
}


def write_icon_bundle(path, palette):
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(os.path.join(path, 'Assets'))
    glyph_layer(palette, with_background=False).save(os.path.join(path, 'Assets', 'intellitile.png'))
    with open(os.path.join(path, 'icon.json'), 'w') as f:
        json.dump(ICON_JSON, f, indent=2)
        f.write('\n')


def squircle_icon(palette):
    """Flattened Sequoia-style icon: content on a rounded-rect plate with margins (824/1024)."""
    full = glyph_layer(palette, with_background=True)
    plate = 824; off = (N - plate) // 2
    mask = rounded_mask((N * SS, N * SS), (0, 0, plate * SS - 1, plate * SS - 1), int(plate * SS * 0.225))
    mask = mask.crop((0, 0, plate * SS, plate * SS)).resize((plate, plate), Image.LANCZOS)
    out = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    out.paste(full.resize((plate, plate), Image.LANCZOS), (off, off), mask)
    return out


def main():
    res = os.path.join(ROOT, 'DockTile', 'Resources')
    write_icon_bundle(os.path.join(res, 'AppIcon.icon'), RELEASE)
    write_icon_bundle(os.path.join(res, 'AppIcon-Dev.icon'), DEV)
    white_glyph().save(os.path.join(res, 'DockTileGlyph.png'))
    iconset = os.path.join(ROOT, 'appicon', 'intellitile', 'AppIcon.iconset')
    os.makedirs(iconset, exist_ok=True)
    master = squircle_icon(RELEASE)
    master.save(os.path.join(ROOT, 'appicon', 'intellitile', 'icon-1024.png'))
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f'icon_{pt}x{pt}' + ('@2x' if scale == 2 else '') + '.png'
            master.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))
    print('IntelliTile icon written')


if __name__ == '__main__':
    main()
