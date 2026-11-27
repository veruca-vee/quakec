# retexture.py -- girly construction debug-map texture pack for ndu.bsp
# Pink paper + grid + debug tags + satirical labels, drawn into the BSP's
# own mip textures (same sizes -> in-place lump replacement, file size
# unchanged). Quantized to the STOCK palette: zombies keep zombie colors.
import struct, math, random
from PIL import Image, ImageDraw, ImageFont

random.seed(1945)
BASE = '/home/hatch/workspace/nzp-bot/texpack/'
BSP_IN = '/home/hatch/workspace/nzp-bot/native/nzp-bot-test/nzp/maps/ndu.bsp'
BSP_OUT = BASE + 'ndu_pink.bsp'
PALB = open('/home/hatch/workspace/nzp-bot/fred/palette_stock_backup.lmp', 'rb').read()
PAL = [tuple(PALB[i*3:i*3+3]) for i in range(256)]

FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FM = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
SS = 4  # supersample

PAPER = (255, 207, 236); PAPER2 = (253, 183, 222); PAPER_D = (238, 158, 203)
GRID_MIN = (244, 158, 214); GRID_MAJ = (228, 90, 182)
INK = (94, 20, 86); INK_SOFT = (156, 56, 136)
MAGENTA = (233, 52, 176); CYAN = (26, 198, 224); WHITE = (255, 255, 255)
CHALK = (255, 121, 205); LILAC = (178, 132, 226)

def font(path, size):
    return ImageFont.truetype(path, size * SS)

def canvas(w, h, color=PAPER):
    img = Image.new('RGB', (w * SS, h * SS), color)
    return img, ImageDraw.Draw(img)

def speckle(dr, w, h, n, colors, rmax=2):
    for _ in range(n):
        x, y = random.uniform(0, w * SS), random.uniform(0, h * SS)
        r = random.uniform(0.6, rmax) * SS / 2
        c = random.choice(colors)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=c)

def grid(dr, w, h, minor=8, major=32):
    x = minor
    while x < w:
        c = GRID_MAJ if x % major == 0 else GRID_MIN
        wd = 1.6 if x % major == 0 else 0.8
        dr.line([x * SS, 0, x * SS, h * SS], fill=c, width=max(1, int(wd * SS / 2)))
        x += minor
    y = minor
    while y < h:
        c = GRID_MAJ if y % major == 0 else GRID_MIN
        wd = 1.6 if y % major == 0 else 0.8
        dr.line([0, y * SS, w * SS, y * SS], fill=c, width=max(1, int(wd * SS / 2)))
        y += minor

def fit_font(path, text, maxw, start):
    s = start
    while s > 5:
        f = font(path, s)
        if ImageDraw.Draw(Image.new('RGB', (8, 8))).textlength(text, font=f) <= maxw * SS:
            return f, s
        s -= 1
    return font(path, 5), 5

def center_text(dr, w, y, text, path=FB, size=14, fill=INK, maxw=None):
    f, _ = fit_font(path, text, (maxw or w) - 4, size)
    tw = dr.textlength(text, font=f)
    dr.text(((w * SS - tw) / 2, y * SS), text, font=f, fill=fill)
    return f

def tag(dr, w, name, tw_):
    f = font(FM, 6)
    t = f'{name} {tw_}px'
    dr.rectangle([0, 0, dr.textlength(t, font=f) + 6, 9 * SS], fill=WHITE)
    dr.text((3, 1 * SS), t, font=f, fill=INK)

def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)

# ---------- per-texture artists (return RGB or RGBA Image at final size) ------
def art_nduwall(w, h, orig, alpha):
    img, dr = canvas(w, h)
    speckle(dr, w, h, 260, [PAPER2, (255, 222, 243)])
    grid(dr, w, h)
    center_text(dr, w, 26, 'WALL', size=30)
    center_text(dr, w, 62, 'load-bearing', size=13, fill=INK_SOFT)
    center_text(dr, w, 78, 'since 1945', size=13, fill=INK_SOFT)
    center_text(dr, w, 104, 'do not lick', path=FM, size=9, fill=INK_SOFT)
    tag(dr, w, 'nduwall', w)
    return finish(img, w, h)

def art_ground(w, h, orig, alpha):
    img, dr = canvas(w, h, PAPER2)
    speckle(dr, w, h, 420, [PAPER_D, PAPER, (226, 120, 190)])
    grid(dr, w, h)
    center_text(dr, w, 34, 'FLOOR', size=28)
    center_text(dr, w, 70, 'mind the gap', size=13, fill=INK_SOFT)
    center_text(dr, w, 88, '(the gap is winning)', size=10, fill=INK_SOFT)
    tag(dr, w, 'ground', w)
    return finish(img, w, h)

def art_concrete(w, h, orig, alpha):
    img, dr = canvas(w, h, (250, 190, 224))
    speckle(dr, w, h, 500, [PAPER_D, (214, 130, 190), (255, 226, 244)], rmax=3)
    grid(dr, w, h)
    center_text(dr, w, 18, 'CONCRETE', size=12)
    center_text(dr, w, 38, 'emotionally', size=9, fill=INK_SOFT)
    center_text(dr, w, 48, 'unavailable', size=9, fill=INK_SOFT)
    tag(dr, w, 'cons', w)
    return finish(img, w, h)

def art_tiles(w, h, orig, alpha):
    img, dr = canvas(w, h, PAPER)
    t = w // 2
    for i in range(2):
        for j in range(2):
            if (i + j) % 2:
                dr.rectangle([i * t * SS, j * t * SS, (i + 1) * t * SS, (j + 1) * t * SS], fill=PAPER2)
    grid(dr, w, h, minor=16, major=32)
    dr.line([0, 0, 0, h * SS], fill=INK_SOFT, width=SS)
    center_text(dr, w, 8, 'TILES', size=13)
    center_text(dr, w, 40, 'slippery', size=9, fill=INK_SOFT)
    center_text(dr, w, 50, 'when dead', size=9, fill=INK_SOFT)
    tag(dr, w, 'tiles', w)
    return finish(img, w, h)

def art_door(w, h, orig, alpha):
    img, dr = canvas(w, h, PAPER2)
    dr.rectangle([4 * SS, 4 * SS, (w - 4) * SS, (h - 4) * SS], outline=INK, width=SS)
    dr.rectangle([10 * SS, 12 * SS, (w - 10) * SS, 30 * SS], outline=INK_SOFT, width=max(1, SS // 2))
    dr.rectangle([10 * SS, 36 * SS, (w - 10) * SS, 48 * SS], outline=INK_SOFT, width=max(1, SS // 2))
    dr.ellipse([50 * SS, 30 * SS, 55 * SS, 35 * SS], fill=CYAN, outline=INK)
    center_text(dr, w, 1, 'DOOR', size=11)
    for i in range(-2, 10):  # caution band, girly construction stripes
        x0 = i * 8
        dr.polygon([(x0 * SS, h * SS), ((x0 + 8) * SS, h * SS),
                    ((x0 + 2) * SS, (h - 8) * SS), ((x0 - 6) * SS, (h - 8) * SS)],
                   fill=MAGENTA if i % 2 else WHITE)
    center_text(dr, w, h - 18, '1000 pts', size=9, fill=INK)
    tag(dr, w, 'door', w)
    return finish(img, w, h)

def art_doorway(w, h, orig, alpha):
    img, dr = canvas(w, h, MAGENTA)
    dr.rectangle([3 * SS, 0, 5 * SS, h * SS], fill=PAPER2)
    dr.rectangle([10 * SS, 0, 12 * SS, h * SS], fill=PAPER2)
    for y in range(4, h, 8):
        dr.ellipse([6 * SS, y * SS, 9 * SS, (y + 3) * SS], fill=WHITE)
    return finish(img, w, h)

def pink_wood(dr, w, h, bands):
    bh = h / bands
    for b in range(bands):
        y0 = b * bh
        dr.rectangle([0, y0 * SS, w * SS, (y0 + bh) * SS], fill=PAPER2 if b % 2 else PAPER)
        for _ in range(7):
            yy = random.uniform(y0 + 1, y0 + bh - 1)
            dr.line([0, yy * SS, w * SS, yy * SS], fill=(226, 120, 190), width=max(1, SS // 2))
        dr.line([0, (y0 + bh) * SS - 1, w * SS, (y0 + bh) * SS - 1], fill=INK_SOFT, width=max(1, SS // 2))
        for x in (3, w - 4):
            dr.ellipse([x * SS - 2, (y0 + bh / 2) * SS - 2, x * SS + 2, (y0 + bh / 2) * SS + 2], fill=INK)

def art_board(w, h, orig, alpha):
    # keep the original see-through slits; planks become pink wood
    img = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for y in range(h):
        rowopaque = sum(1 for x in range(w) if not alpha[y * w + x]) / w
        if rowopaque > 0.5:
            c = PAPER2 if (y // 8) % 2 else PAPER
            dr.rectangle([0, y * SS, w * SS, (y + 1) * SS], fill=c + (255,))
            for _ in range(3):
                yy = y + random.uniform(0.2, 0.8)
                dr.line([0, yy * SS, w * SS, yy * SS], fill=(226, 120, 190, 255), width=max(1, SS // 2))
    f1, _ = fit_font(FB, 'zombies', w - 6, 13)
    dr.text((3 * SS, 20 * SS), 'zombies', font=f1, fill=INK + (255,))
    f2, _ = fit_font(FB, 'awee!! ->', w - 6, 13)
    dr.text((3 * SS, 36 * SS), 'awee!! ->', font=f2, fill=MAGENTA + (255,))
    return img.resize((w, h), Image.LANCZOS)

def art_wood64(w, h, orig, alpha):
    img, dr = canvas(w, h)
    pink_wood(dr, w, h, 4)
    grid(dr, w, h, minor=16, major=64)
    center_text(dr, w, 24, 'WOOD', size=13)
    center_text(dr, w, 42, "tree's revenge", size=8, fill=INK_SOFT)
    tag(dr, w, 'wood', w)
    return finish(img, w, h)

def art_wood32(w, h, orig, alpha):
    img, dr = canvas(w, h)
    pink_wood(dr, w, h, 2)
    center_text(dr, w, 10, 'wood (small)', size=10)
    return finish(img, w, h)

def art_box(w, h, orig, alpha):
    img, dr = canvas(w, h, PAPER2)
    dr.rectangle([2 * SS, 2 * SS, (w - 2) * SS, (h - 2) * SS], outline=INK, width=SS)
    dr.line([2 * SS, 2 * SS, (w - 2) * SS, (h - 2) * SS], fill=INK_SOFT, width=max(1, SS // 2))
    dr.line([(w - 2) * SS, 2 * SS, 2 * SS, (h - 2) * SS], fill=INK_SOFT, width=max(1, SS // 2))
    center_text(dr, w, 6, 'BOX', size=12)
    center_text(dr, w, 20, 'contains: box', size=8, fill=INK_SOFT)
    return finish(img, w, h)

def art_cupboard(w, h, orig, alpha):
    img, dr = canvas(w, h, PAPER2)
    dr.rectangle([2 * SS, 2 * SS, (w / 2 - 1) * SS, (h - 2) * SS], outline=INK, width=max(1, SS // 2))
    dr.rectangle([(w / 2 + 1) * SS, 2 * SS, (w - 2) * SS, (h - 2) * SS], outline=INK, width=max(1, SS // 2))
    dr.ellipse([12 * SS, 14 * SS, 15 * SS, 17 * SS], fill=CYAN)
    dr.ellipse([17 * SS, 14 * SS, 20 * SS, 17 * SS], fill=CYAN)
    center_text(dr, w, 20, 'snacks? no', size=8)
    return finish(img, w, h)

def recolor_alpha(orig_rgb, alpha, w, h, fn):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not alpha[i]:
                px[x, y] = fn(orig_rgb[i]) + (255,)
    return img

def art_grate(w, h, orig, alpha):
    img, dr = canvas(w, h, (216, 110, 180))
    speckle(dr, w, h, 200, [(190, 84, 160), (232, 150, 205)])
    dr.line([4 * SS, 4 * SS, (w - 4) * SS, (h - 4) * SS], fill=INK, width=SS)
    dr.line([(w - 4) * SS, 4 * SS, 4 * SS, (h - 4) * SS], fill=INK, width=SS)
    dr.rectangle([4 * SS, 4 * SS, (w - 4) * SS, (h - 4) * SS], outline=INK, width=SS)
    for cx, cy in ((8, 8), (w - 8, 8), (8, h - 8), (w - 8, h - 8)):
        dr.ellipse([(cx - 2) * SS, (cy - 2) * SS, (cx + 2) * SS, (cy + 2) * SS], fill=WHITE, outline=INK)
    center_text(dr, w, 26, 'GRATE', size=12)
    center_text(dr, w, 42, 'expectations', size=8, fill=INK)
    return finish(img, w, h)

def art_wire(w, h, orig, alpha):
    def fn(rgb):
        lum = (rgb[0] + rgb[1] + rgb[2]) / 765
        return (int(150 + 83 * lum), int(40 + 60 * lum), int(130 + 90 * lum))
    return recolor_alpha(orig, alpha, w, h, fn)

def art_railing(w, h, orig, alpha):
    def fn(rgb):
        lum = (rgb[0] + rgb[1] + rgb[2]) / 765
        return (int(140 + 93 * lum), int(36 + 50 * lum), int(120 + 86 * lum))
    return recolor_alpha(orig, alpha, w, h, fn)

def art_debris(w, h, orig, alpha):
    img, dr = canvas(w, h, (232, 148, 198))
    shades = [(196, 120, 190), (214, 150, 205), (168, 110, 180), (226, 170, 214), LILAC]
    for _ in range(26):
        x, y = random.uniform(0, w), random.uniform(0, h)
        r = random.uniform(3, 9)
        pts = [(x + random.uniform(-r, r), y + random.uniform(-r, r)) for _ in range(5)]
        dr.polygon([(px * SS, py * SS) for px, py in pts], fill=random.choice(shades))
    grid(dr, w, h, minor=16, major=32)
    center_text(dr, w, 6, 'DEBRIS', size=12)
    center_text(dr, w, 48, 'osha notified', path=FM, size=8, fill=INK)
    tag(dr, w, 'debris', w)
    return finish(img, w, h)

def art_camo(w, h, orig, alpha):
    img = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.rectangle([0, 0, w * SS, h * SS], fill=PAPER + (255,))
    for _ in range(14):
        x, y = random.uniform(0, w), random.uniform(0, h)
        r = random.uniform(3, 7)
        c = random.choice([MAGENTA, LILAC, PAPER2, CYAN])
        dr.ellipse([(x - r) * SS, (y - r / 2) * SS, (x + r) * SS, (y + r / 2) * SS], fill=c + (255,))
    return img.resize((w, h), Image.LANCZOS)

def art_clfnd(w, h, orig, alpha):
    img = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.ellipse([SS, SS, (w - 1) * SS, (h - 1) * SS], fill=MAGENTA + (255,))
    dr.ellipse([6 * SS, 6 * SS, 10 * SS, 10 * SS], fill=WHITE + (255,))
    return img.resize((w, h), Image.LANCZOS)

def art_sky(w, h, orig, alpha):
    img = Image.new('RGB', (w * SS, h * SS))
    dr = ImageDraw.Draw(img)
    top, mid, bot = WHITE, (140, 225, 245), (205, 170, 245)
    for y in range(h * SS):
        t = y / (h * SS)
        if t < 0.5:
            c = tuple(int(top[i] + (mid[i] - top[i]) * t * 2) for i in range(3))
        else:
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * (t - 0.5) * 2) for i in range(3))
        dr.line([0, y, w * SS, y], fill=c)
    center_text(dr, w, 12, 'SKY', size=10, fill=INK_SOFT)
    return finish(img, w, h)

def chalk_art(lines, sub):
    def artist(w, h, orig, alpha):
        img = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
        y = 8
        for text, size in lines:
            layer = Image.new('RGBA', (w * SS, 40 * SS), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            f, _ = fit_font(FB, text, w - 14, size)
            tw = ld.textlength(text, font=f)
            ld.text(((w * SS - tw) / 2 + 2, 2), text, font=f, fill=(255, 190, 230, 160))
            ld.text(((w * SS - tw) / 2, 0), text, font=f, fill=CHALK + (255,))
            layer = layer.rotate(random.uniform(-2, 2), resample=Image.BICUBIC, center=(w * SS / 2, 20 * SS))
            img.alpha_composite(layer, (0, y * SS))
            y += int(size * 1.25)
        if sub:
            layer = Image.new('RGBA', (w * SS, 24 * SS), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            f, _ = fit_font(FM, sub, w - 10, 9)
            tw = ld.textlength(sub, font=f)
            ld.text(((w * SS - tw) / 2, 0), sub, font=f, fill=(255, 220, 245, 255))
            img.alpha_composite(layer, (0, (h - 16) * SS))
        return img.resize((w, h), Image.LANCZOS)
    return artist

ART = {
    'nduwall': art_nduwall,
    'ground_hb3': art_ground,
    'cons5nny3': art_concrete,
    '3tiles_grey_64': art_tiles,
    'ndu_doors_64': art_door,
    'doorway_met': art_doorway,
    '{board_fe': art_board,
    'w_wood_brown_re': art_wood64,
    'w_s_wooden_b64': art_wood32,
    'box_side_o': art_box,
    'm_cupb_front': art_cupboard,
    'm_metal_darkblu': art_grate,
    'debris_hnf3p': art_debris,
    '{barbed_wire_v': art_wire,
    '{railling_ndu': art_railing,
    '{metal_rail7': art_railing,
    '{camo_2': art_camo,
    '{clfnd': art_clfnd,
    'sky': art_sky,
    '{chk_ascend': chalk_art([('You MUST', 17), ('ASCEND', 21), ('FROM', 15), ('DARKNESS', 19)],
                             '(stairs are right there)'),
    '{chk_salvat': chalk_art([('SALVATION', 19), ('LIES', 17), ('ABOVE', 19)],
                             "(it's a gun. it's always a gun)"),
}

# ---------- palette quantization ----------
_cache = {}
def nearest(rgb):
    if rgb in _cache:
        return _cache[rgb]
    best, bd = 0, 1e18
    for i in range(255):
        p = PAL[i]
        d = (rgb[0] - p[0]) ** 2 + (rgb[1] - p[1]) ** 2 + (rgb[2] - p[2]) ** 2
        if d < bd:
            bd, best = d, i
    _cache[rgb] = best
    return best

def quantize(img_rgba, fence):
    w, h = img_rgba.size
    px = img_rgba.load()
    out = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if fence and a < 128:
                out[y * w + x] = 255
            else:
                out[y * w + x] = nearest((r, g, b))
    return bytes(out)

def mip_chain(img_rgba, w, h, fence):
    levels = []
    cur = img_rgba
    for k in range(4):
        lw, lh = max(1, w >> k), max(1, h >> k)
        if k:
            cur = img_rgba.resize((lw, lh), Image.LANCZOS)
        levels.append(quantize(cur, fence))
    return levels

# ---------- BSP surgery ----------
d = bytearray(open(BSP_IN, 'rb').read())
lumps = [struct.unpack('<ii', d[4 + i * 8:12 + i * 8]) for i in range(15)]
toff, tlen = lumps[2]
n = struct.unpack('<i', d[toff:toff + 4])[0]
offs = struct.unpack(f'<{n}i', d[toff + 4:toff + 4 + 4 * n])
done = []
for o in offs:
    if o < 0:
        continue
    p = toff + o
    name = d[p:p + 16].split(b'\0')[0].decode('ascii', 'replace')
    w, h = struct.unpack('<ii', d[p + 16:p + 24])
    mipoff = struct.unpack('<4i', d[p + 24:p + 40])
    orig_idx = bytes(d[p + mipoff[0]:p + mipoff[0] + w * h])
    orig_rgb = [PAL[b] if b != 255 else (0, 0, 0) for b in orig_idx]
    alpha = [b == 255 for b in orig_idx]
    if name == 'trigger':
        continue
    artist = ART.get(name)
    if artist is None:
        print('SKIP (no artist):', name)
        continue
    fence = name.startswith('{')
    art = artist(w, h, orig_rgb, alpha)
    if art.mode == 'RGB':
        art = art.convert('RGBA')
    levels = mip_chain(art, w, h, fence)
    for k in range(4):
        start = p + mipoff[k]
        d[start:start + len(levels[k])] = levels[k]
    done.append(name)
    print('done', name, w, h)
open(BSP_OUT, 'wb').write(bytes(d))
print('WROTE', BSP_OUT, len(d), 'bytes (orig', len(open(BSP_IN, 'rb').read()), ')')
print('textures replaced:', len(done))
