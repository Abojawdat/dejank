import io
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'site' / 'out'
ART = ROOT / 'art'

SCALE = 2
COLS = 100
FONT_SIZE = 14 * SCALE
LINE = 21 * SCALE
PAD = 24 * SCALE
BAR = 40 * SCALE

BG = (11, 18, 32)
TEXT = (226, 232, 240)
DIM = (100, 116, 139)
CYAN = (56, 189, 248)

MONO = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', FONT_SIZE, index=0)
BOLD = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', FONT_SIZE, index=1)
TITLE = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 13 * SCALE)
EMOJI = ImageFont.truetype('/System/Library/Fonts/Apple Color Emoji.ttc', 160)
CHAR = MONO.getlength('M')
WIDTH = int(PAD * 2 + COLS * CHAR)

MEASURE = 'dejank measure integration_test/search_test.dart -d BKQ'
STORY = [('dejank scan', 'scan'), ('dejank fix', 'fix'), (MEASURE, 'measure_compare')]

SGR = re.compile(r'\x1b\[([0-9;]*)m')


def xterm(n):
    if n < 16:
        return [(0, 0, 0), (205, 49, 49), (13, 188, 121), (229, 229, 16), (36, 114, 200), (188, 63, 188),
                (17, 168, 205), (229, 229, 229)][n % 8]
    if n < 232:
        n -= 16
        level = [0, 95, 135, 175, 215, 255]
        return level[n // 36], level[n // 6 % 6], level[n % 6]
    v = 8 + 10 * (n - 232)
    return v, v, v


def emoji(c):
    o = ord(c)
    return 0x2300 <= o <= 0x23FF or 0x2600 <= o <= 0x27BF or 0x2B00 <= o <= 0x2BFF or o >= 0x1F000


def cells(line, fg=TEXT, bold=False):
    out, bg, pos = [], None, 0
    for m in list(SGR.finditer(line)) + [None]:
        end = m.start() if m else len(line)
        out += [(c, fg, bg, bold) for c in line[pos:end] if c not in '️\r']
        if not m:
            break
        codes = [int(x) for x in m.group(1).split(';') if x] or [0]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0:
                fg, bg, bold = TEXT, None, False
            elif c == 1:
                bold = True
            elif c in (38, 48) and codes[i + 1] == 5:
                if c == 38:
                    fg = xterm(codes[i + 2])
                else:
                    bg = xterm(codes[i + 2])
                i += 2
            i += 1
        pos = m.end()
    return out


def width(row):
    return sum(2 if emoji(c[0]) else 1 for c in row)


def wrap(row):
    rows, indent = [], len(row) - len(''.join(c[0] for c in row).lstrip(' '))
    while width(row) > COLS:
        w, cut = 0, None
        for i, c in enumerate(row):
            w += 2 if emoji(c[0]) else 1
            if w > COLS:
                break
            if c[0] == ' ' and i > indent:
                cut = i
        cut = cut or i
        rows.append(row[:cut])
        rest = row[cut:]
        while rest and rest[0][0] == ' ':
            rest = rest[1:]
        row = [(' ', TEXT, None, False)] * (indent + 2) + rest
    return rows + [row]


def prompt(command):
    return [('$', DIM, None, False), (' ', TEXT, None, False)] + [(c, CYAN, None, True) for c in command]


def output(name):
    return [r for line in (OUT / f'{name}.ans').read_text().rstrip('\n').split('\n') for r in wrap(cells(line))]


_emoji_cache, _row_cache = {}, {}


def glyph(c):
    if c not in _emoji_cache:
        big = Image.new('RGBA', (170, 170))
        ImageDraw.Draw(big).text((5, 5), c, font=EMOJI, embedded_color=True)
        size = int(FONT_SIZE * 1.12)
        _emoji_cache[c] = big.crop(big.getbbox() or (0, 0, 1, 1)).resize((size, size), Image.LANCZOS)
    return _emoji_cache[c]


def strip(row):
    key = tuple(row)
    if key not in _row_cache:
        img = Image.new('RGB', (WIDTH - PAD * 2, LINE), BG)
        d = ImageDraw.Draw(img)
        x = 0
        for c, fg, bg, bold in row:
            w = (2 if emoji(c) else 1) * CHAR
            if bg:
                d.rectangle([x, 2, x + w, LINE - 4], fill=bg)
            if emoji(c):
                g = glyph(c)
                img.paste(g, (int(x + (w - g.width) / 2), int((LINE - g.height) / 2) - 2), g)
            elif c != ' ':
                d.text((x, (LINE - FONT_SIZE) / 2 - 3), c, font=BOLD if bold else MONO, fill=fg)
            x += w
        _row_cache[key] = img
    return _row_cache[key]


def window(rows, height_rows, cursor=False):
    img = Image.new('RGB', (WIDTH, BAR + PAD // 2 + height_rows * LINE + PAD), BG)
    d = ImageDraw.Draw(img)
    for i, c in enumerate([(239, 68, 68), (245, 158, 11), (34, 197, 94)]):
        cx, cy, r = (26 + 20 * i) * SCALE, 22 * SCALE, 6 * SCALE
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    d.text((WIDTH / 2, 22 * SCALE), '~/slow_app', font=TITLE, fill=DIM, anchor='mm')
    for i, row in enumerate(rows):
        y = BAR + PAD // 2 + i * LINE
        img.paste(strip(row), (PAD, y))
        if cursor and i == len(rows) - 1:
            x = PAD + width(row) * CHAR + 2
            d.rectangle([x, y + 6, x + CHAR - 2, y + LINE - 8], fill=(148, 163, 184))
    return img


def still(name, command, out):
    rows = [prompt(command)] + output(out)
    window(rows, len(rows)).save(ART / f'{name}.png', optimize=True)


def animation(name):
    steps = [(command, output(out)) for command, out in STORY]
    height = max(len(rows) for _, rows in steps) + 1
    frames, durations = [], []

    def show(rows, ms, cursor=False):
        frames.append(window(rows, height, cursor))
        durations.append(ms)

    for command, rows in steps:
        show([prompt('')], 600, True)
        for n in range(2, len(command) + 2, 2):
            show([prompt(command[:n])], 40, True)
        show([prompt(command)], 300, True)
        screen = [prompt(command)]
        for i, row in enumerate(rows):
            screen.append(row)
            if any('⏱' in c[0] for c in row):
                show(list(screen), 1800)
            elif i % 3 == 2 or i == len(rows) - 1:
                show(list(screen), 70)
        durations[-1] = 3200
    durations[-1] = 5000
    frames[0].save(
        ART / f'{name}.webp', save_all=True, append_images=frames[1:], duration=durations, loop=0, lossless=True,
        minimize_size=True,
    )


def social(name):
    w, h = 1280, 640
    img = Image.new('RGB', (w, h), (7, 11, 20))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = max(0.0, 1 - y / 420)
        d.line([(0, y), (w, y)], fill=(int(7 + 19 * t), int(11 + 23 * t), int(20 + 36 * t)))
    png = subprocess.run(['rsvg-convert', '-w', '220', str(ART / 'logo.svg')], capture_output=True, check=True).stdout
    logo = Image.open(io.BytesIO(png)).convert('RGBA')
    img.paste(logo, (90, 150), logo)
    heavy = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 112, index=1)
    body = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 40)
    small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 28)
    d.text((360, 140), 'dejank', font=heavy, fill=TEXT)
    d.text((364, 282), 'Find slow Flutter code. Fix it. Prove it.', font=body, fill=(148, 163, 184))
    x = 364
    for big, label in [('93%', 'fewer widget builds'), ('84%', 'fewer slow frames')]:
        d.text((x, 360), big, font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 64, index=1), fill=(34, 197, 94))
        d.text((x, 436), label, font=small, fill=(148, 163, 184))
        x += 360
    gradient = [(234, 88, 12), (250, 204, 21), (34, 197, 94)]
    for i in range(w - 180):
        t = i / (w - 181) * 2
        a, b = gradient[int(min(t, 1.999))], gradient[int(min(t, 1.999)) + 1]
        f = t - int(min(t, 1.999))
        d.line([(90 + i, 528), (90 + i, 533)], fill=tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    d.text((90, 556), 'made with', font=small, fill=DIM)
    d.text((90 + small.getlength('made with ') + 46, 556), 'by Abojawdat  ·  pub.dev/packages/dejank', font=small, fill=DIM)
    heart = glyph('💙').resize((34, 34), Image.LANCZOS)
    img.paste(heart, (int(90 + small.getlength('made with ') + 4), 556), heart)
    img.save(ART / f'{name}.png', optimize=True)


if __name__ == '__main__':
    ART.mkdir(exist_ok=True)
    social('social')
    still('scan', 'dejank scan', 'scan')
    still('fix', 'dejank fix', 'fix')
    still('measure', MEASURE, 'measure_compare')
    animation('session')
    for f in ['scan.png', 'fix.png', 'measure.png', 'session.webp']:
        p = ART / f
        print(f'{p.relative_to(ROOT)}  {Image.open(p).size}  {p.stat().st_size // 1024} KB')
