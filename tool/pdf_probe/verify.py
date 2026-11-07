#!/usr/bin/env python3
"""Independent checks of probe PDFs (M2b-3a).

Uses poppler (pdftotext, pdffonts, pdftoppm) and fontTools; makes a
HarfBuzz-shaped reference image (Pillow + libraqm) next to each PDF render so
a person can judge shaping. Writes report.json and report.md.

Visual correctness is NEVER inferred from successful generation: every case
gets visual = "NEEDS_REVIEW" until a person records a verdict.
"""
import base64, io, json, os, re, subprocess, sys, unicodedata
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont, features

out = Path(sys.argv[1])
font_dir = Path(sys.argv[2])
print_b64 = '--print-png-base64' in sys.argv

FONTS = {
    'deva': font_dir / 'NotoSerifDevanagari-Regular.ttf',
    'latin': font_dir / 'NotoSerif-Regular.ttf',
    'hebrew': font_dir / 'NotoSerifHebrew-Regular.ttf',
}
# Engine B (Android native) uses the device's own fonts: CI pulls them from
# the emulator and points the reference at the same files.
if os.environ.get('PROBE_DEVA_FONT'):
    FONTS['deva'] = Path(os.environ['PROBE_DEVA_FONT'])
if os.environ.get('PROBE_LATIN_FONT'):
    FONTS['latin'] = Path(os.environ['PROBE_LATIN_FONT'])
LATIN_FIRST = os.environ.get('PROBE_LATIN_FIRST') == '1'
CMAPS = {k: set(TTFont(str(v)).getBestCmap()) for k, v in FONTS.items()}
ZW = {0x200C, 0x200D}


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, check=False)


def norm_ws(s):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', s)).strip()


def font_for(cp, rtl):
    order = ['hebrew', 'deva', 'latin'] if rtl else ['deva', 'latin', 'hebrew']
    if LATIN_FIRST and cp < 0x0900 and cp in CMAPS['latin']:
        return 'latin'
    for k in order:
        if cp in CMAPS[k]:
            return k
    return None


def pdffonts(pdf):
    rows = run('pdffonts', str(pdf)).stdout.splitlines()[2:]
    fonts = []
    for r in rows:
        parts = r.split()
        if len(parts) < 7:
            continue
        # name type... encoding emb sub uni object ID
        emb, sub, uni = parts[-5], parts[-4], parts[-3]
        fonts.append({'name': parts[0], 'emb': emb, 'sub': sub, 'uni': uni})
    return fonts


def bbox_overflow(pdf):
    html = run('pdftotext', '-bbox', str(pdf), '-').stdout
    pages = re.findall(r'<page width="([\d.]+)" height="([\d.]+)">(.*?)</page>', html, re.S)
    bad = []
    for w, h, body in pages:
        W, H = float(w), float(h)
        for m in re.finditer(r'xMin="([\d.-]+)" yMin="([\d.-]+)" xMax="([\d.-]+)" yMax="([\d.-]+)">([^<]*)<', body):
            x0, y0, x1, y1 = map(float, m.groups()[:4])
            if x0 < 0 or y0 < 0 or x1 > W + 0.5 or y1 > H + 0.5:
                bad.append(m.group(5))
    return len(pages), bad


def reference_image(blocks, rtl, width=560):
    """HarfBuzz (raqm) shaped reference, one font per script run."""
    size = 28
    pil = {k: ImageFont.truetype(str(v), size, layout_engine=ImageFont.Layout.RAQM) for k, v in FONTS.items()}
    lines = []
    for text in blocks:
        words, cur = text.split(' '), ''
        for w in words:
            cand = (cur + ' ' + w).strip()
            if pil['deva'].getlength(cand) > width - 20 and cur:
                lines.append(cur)
                cur = w
            else:
                cur = cand
        lines.append(cur)
    img = Image.new('L', (width, 20 + len(lines) * int(size * 1.9)), 255)
    d = ImageDraw.Draw(img)
    y = 10
    for line in lines:
        runs, cur, key = [], '', None
        for ch in line:
            k = font_for(ord(ch), rtl) or 'deva'
            if ord(ch) in ZW or ch == ' ' or unicodedata.category(ch).startswith('M'):
                k = key or k
            if key is not None and k != key:
                runs.append((key, cur))
                cur = ''
            key, cur = k, cur + ch
        if cur:
            runs.append((key, cur))
        x = 10
        for k, t in runs:
            kw = {'direction': 'rtl'} if rtl else {}
            d.text((x, y), t, font=pil[k], fill=0, **kw)
            x += pil[k].getlength(t, **kw)
        y += int(size * 1.9)
    return img


cases = json.loads((out / 'generation.json').read_text())
gen = {g['id']: g for g in cases['generation']}
(out / 'png').mkdir(exist_ok=True)
(out / 'compare').mkdir(exist_ok=True)
results = []
for c in cases['cases']:
    cid = c['id']
    expected = (out / 'expected' / f'{cid}.txt').read_text()
    pdf = out / 'pdf' / f'{cid}.pdf'
    r = {'id': cid, 'title': c['title'], 'tCases': c['tCases'],
         'generated': gen[cid]['generated'], 'visual': 'NEEDS_REVIEW'}
    if not r['generated'] or not pdf.exists():
        r['error'] = gen[cid].get('error')
        results.append(r)
        continue
    extracted = run('pdftotext', '-enc', 'UTF-8', '-nopgbrk', str(pdf), '-').stdout
    (out / 'extracted').mkdir(exist_ok=True)
    (out / 'extracted' / f'{cid}.txt').write_text(extracted)
    e, x = norm_ws(expected), norm_ws(extracted)
    strip = lambda s: ''.join(ch for ch in s if ord(ch) not in ZW)
    r['extract_exact'] = e == x
    r['extract_ignoring_zw'] = strip(e) == strip(x)
    r['missing_in_extract'] = sorted({f'U+{ord(ch):04X}' for ch in e if ch not in x and ch != ' '})
    hindi_words = [w for w in re.findall(r'[\u0900-\u097F\u200C\u200D]+', e) if len(w) > 1]
    r['hindi_words_found'] = f"{sum(1 for w in hindi_words if w in x)}/{len(hindi_words)}"
    unsupported = sorted({f'U+{ord(ch):04X}' for ch in expected
                          if not ch.isspace() and ord(ch) not in ZW and font_for(ord(ch), c['rtl']) is None})
    r['chars_without_glyph_in_fonts'] = unsupported
    fonts = pdffonts(pdf)
    r['fonts'] = fonts
    r['fonts_embedded'] = bool(fonts) and all(f['emb'] == 'yes' for f in fonts)
    r['fonts_tounicode'] = bool(fonts) and all(f['uni'] == 'yes' for f in fonts)
    pages, overflow = bbox_overflow(pdf)
    r['pages'] = pages
    r['words_outside_page'] = overflow
    run('pdftoppm', '-r', '110', '-png', str(pdf), str(out / 'png' / cid))
    first = sorted((out / 'png').glob(f'{cid}-*.png'))[0]
    left = Image.open(first).convert('L')
    ref = reference_image(expected.split('\n'), c['rtl'], width=left.width)
    comp = Image.new('L', (left.width * 2 + 10, max(left.height, ref.height)), 200)
    comp.paste(left, (0, 0))
    comp.paste(ref, (left.width + 10, 0))
    comp_path = out / 'compare' / f'{cid}.png'
    comp.save(comp_path, optimize=True)
    r['compare_png'] = f'compare/{cid}.png'
    results.append(r)
    if print_b64:
        small = comp.crop((0, 0, comp.width, min(comp.height, 520)))
        buf = io.BytesIO()
        small.save(buf, 'PNG', optimize=True)
        print(f'PNGB64 {cid} {base64.b64encode(buf.getvalue()).decode()}')

review_file = Path(__file__).with_name(f"{cases['engine'].replace('engine_a_dart_pdf', 'engine_a')}_visual_review.json")
review = json.loads(review_file.read_text()) if review_file.exists() else {'cases': {}}
for r in results:
    v = review['cases'].get(r['id'])
    if v:
        r['visual'] = v['visual']
        r['visual_why'] = v['why']

report = {'engine': cases['engine'], 'device': cases.get('device'),
          'reference_fonts': {k: v.name for k, v in FONTS.items()}, 'raqm': features.check('raqm'), 'cases': results,
          'visual_review': review.get('reviewed_by'),
          'note': 'visual = NEEDS_REVIEW: generation success is not visual correctness.'}
(out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
md = ['| case | gen | extract exact | extract w/o ZW | Hindi words | embedded | ToUnicode | no-glyph chars | outside page | visual |',
      '|---|---|---|---|---|---|---|---|---|---|']
for r in results:
    if not r['generated']:
        md.append(f"| {r['id']} | FAIL | | | | | | | | |")
        continue
    md.append('| {id} | ok | {a} | {b} | {w} | {e} | {u} | {n} | {o} | {v} |'.format(
        id=r['id'], a=r['extract_exact'], b=r['extract_ignoring_zw'], w=r['hindi_words_found'],
        e=r['fonts_embedded'], u=r['fonts_tounicode'], n=' '.join(r['chars_without_glyph_in_fonts']) or '-',
        o=len(r['words_outside_page']), v=r['visual']))
(out / 'report.md').write_text('\n'.join(md) + '\n')
print('\n'.join(md))
for r in results:
    if r.get('generated') and not r['extract_exact']:
        print('MISSING', r['id'], r['missing_in_extract'])
        exp = norm_ws((out / 'expected' / f"{r['id']}.txt").read_text())
        got = norm_ws((out / 'extracted' / f"{r['id']}.txt").read_text())
        print('  expected:', ' '.join(f'{ord(c):04X}' for c in exp))
        print('  got     :', ' '.join(f'{ord(c):04X}' for c in got))
