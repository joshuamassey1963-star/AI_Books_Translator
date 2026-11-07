#!/usr/bin/env python3
"""M2b-3b-2: shape fixture texts with HarfBuzz (uharfbuzz, pinned in CI),
optionally subset the fonts with hb-subset (retain-gids) and check the subsets.

usage:
  hb_shape_fixture.py <font_dir> <out_dir> <case.txt>... [--subset]
  hb_shape_fixture.py <font_dir> --self-test-subset

For each case writes <out_dir>/<case>.hb.json. With --subset also writes
<out_dir>/fonts/<case>.<font>.subset.ttf and the subset checks into the JSON.

Font runs: Devanagari letters/marks (and ZWJ/ZWNJ) use the Devanagari font,
everything else the Latin font; a space stays in the run before it. Each run
is shaped with the whole text as context (add_codepoints with item offset),
so clusters are code point indices into the full source text.
"""
import hashlib, json, sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

FONT_FILES = ['NotoSerifDevanagari-Regular.ttf', 'NotoSerif-Regular.ttf']


def font_of(ch, prev):
    o = ord(ch)
    if 0x0900 <= o <= 0x097F or o in (0x200C, 0x200D):
        return 0
    if ch == ' ':
        return 0 if prev is None else prev
    return 1


def runs_of(text):
    runs, prev = [], None
    for i, ch in enumerate(text):
        f = font_of(ch, prev)
        if runs and runs[-1]['font'] == f:
            runs[-1]['end'] = i + 1
        else:
            runs.append({'font': f, 'start': i, 'end': i + 1})
        prev = f
    return runs


def shape_run(data, cps, start, end):
    face = hb.Face(hb.Blob(data))
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_codepoints(cps, start, end - start)
    buf.guess_segment_properties()
    hb.shape(font, buf, {})
    return [(i.codepoint, i.cluster, p.x_advance, p.y_advance, p.x_offset, p.y_offset)
            for i, p in zip(buf.glyph_infos, buf.glyph_positions)]


def metrics(tt):
    head, hhea = tt['head'], tt['hhea']
    s = 1000 / head.unitsPerEm
    os2 = tt['OS/2'] if 'OS/2' in tt else None
    return {
        'upem': head.unitsPerEm,
        'bbox': [round(v * s) for v in (head.xMin, head.yMin, head.xMax, head.yMax)],
        'ascent': round(hhea.ascent * s),
        'descent': round(hhea.descent * s),
        'cap_height': round((getattr(os2, 'sCapHeight', 0) or hhea.ascent) * s),
    }


def subset(data, gids, unicodes, closure=True):
    inp = hb.SubsetInput()
    inp.flags = hb.SubsetFlags.RETAIN_GIDS if closure else (
        hb.SubsetFlags.RETAIN_GIDS | hb.SubsetFlags.NO_LAYOUT_CLOSURE)
    for g in gids:
        inp.glyph_set.add(g)
    for u in unicodes:
        inp.unicode_set.add(u)
    out = hb.subset(hb.Face(hb.Blob(data)), inp)
    if out is None:
        raise RuntimeError('hb-subset failed')
    return bytes(out.blob.data)


def check_subset(full_path, sub_path, gids, cps, start, end, shaped_full):
    """Checks, never assumes, that the subset keeps what the PDF uses."""
    problems = []
    full, sub = TTFont(str(full_path)), TTFont(str(sub_path))
    if sub['maxp'].numGlyphs <= max(gids):
        problems.append(f"numGlyphs {sub['maxp'].numGlyphs} <= max gid {max(gids)}")
        return problems
    fo, so = full.getGlyphOrder(), sub.getGlyphOrder()
    fg, sg = full['glyf'], sub['glyf']
    for g in gids:
        a, b = fg[fo[g]], sg[so[g]]
        ca, _, _ = a.getCoordinates(fg)
        try:
            cb, _, _ = b.getCoordinates(sg)
        except Exception as e:  # missing composite component
            problems.append(f'gid {g}: outline error {e!r}')
            continue
        if list(ca) != list(cb):
            problems.append(f'gid {g}: outline differs ({len(ca)} vs {len(cb)} points)')
        if a.isComposite():
            for comp in a.components:
                cg = full.getGlyphID(comp.glyphName)
                if sg[so[cg]].numberOfContours == 0 and fg[comp.glyphName].numberOfContours != 0:
                    problems.append(f'gid {g}: component gid {cg} empty in subset')
        if full['hmtx'][fo[g]][0] != sub['hmtx'][so[g]][0]:
            problems.append(f'gid {g}: advance differs')
    reshaped = shape_run(Path(sub_path).read_bytes(), cps, start, end)
    if reshaped != shaped_full:
        problems.append('re-shaping with the subset gives different glyphs/positions')
    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    font_dir = Path(args[0])
    datas = [(font_dir / f).read_bytes() for f in FONT_FILES]
    if '--self-test-composite' in sys.argv:
        # Negative test (M2b-3b-2c-2): hb-subset always keeps composite
        # components, so we blank one component AFTER subsetting and the
        # check must detect it. Glyph: uni0906 (आ) = uni0905 + uni093E.
        text = '\u0906\u091c'
        cps = [ord(c) for c in text]
        shaped = shape_run(datas[0], cps, 0, len(cps))
        gids = sorted({g[0] for g in shaped})
        good = Path('/tmp/selftest.composite.good.ttf')
        good.write_bytes(subset(datas[0], gids, cps))
        ok = check_subset(font_dir / FONT_FILES[0], good, gids, cps, 0, len(cps), shaped)
        tt = TTFont(str(good))
        comp = tt['glyf']['uni0906']
        assert comp.isComposite(), 'uni0906 must be composite'
        victim = comp.components[-1].glyphName
        from fontTools.ttLib.tables._g_l_y_f import Glyph
        tt['glyf'][victim] = Glyph()
        bad = Path('/tmp/selftest.composite.bad.ttf')
        tt.save(str(bad))
        problems = check_subset(font_dir / FONT_FILES[0], bad, gids, cps, 0, len(cps), shaped)
        print('composite self-test: complete subset problems:', ok)
        print(f'composite self-test: blanked component {victim} -> problems:', problems)
        sys.exit(0 if (not ok and problems) else 1)
    if '--self-test-subset' in sys.argv:
        # Negative test: a subset missing one used glyph must be detected.
        text = 'क्षेत्र'
        cps = [ord(c) for c in text]
        shaped = shape_run(datas[0], cps, 0, len(cps))
        gids = sorted({g[0] for g in shaped})
        bad = subset(datas[0], gids[1:], [], closure=False)  # drop the e-matra glyph (lowest gid), keep max gid
        p = Path('/tmp/selftest.subset.ttf')
        p.write_bytes(bad)
        problems = check_subset(font_dir / FONT_FILES[0], p, gids, cps, 0, len(cps), shaped)
        print('self-test problems:', problems)
        sys.exit(0 if problems else 1)
    out = Path(args[1])
    (out / 'fonts').mkdir(parents=True, exist_ok=True)
    do_subset = '--subset' in sys.argv
    tts = [TTFont(str(font_dir / f)) for f in FONT_FILES]
    for case in map(Path, args[2:]):
        cid = case.name[:-4]
        text = case.read_text(encoding='utf-8')
        cps = [ord(c) for c in text]
        runs = runs_of(text)
        glyphs = []
        for r in runs:
            order = tts[r['font']].getGlyphOrder()
            for gid, cl, ax, ay, dx, dy in shape_run(datas[r['font']], cps, r['start'], r['end']):
                if gid == 0:
                    raise SystemExit(f'{cid}: .notdef (missing glyph) at cluster {cl}')
                glyphs.append({'font': r['font'], 'gid': gid, 'cluster': cl, 'ax': ax,
                               'ay': ay, 'dx': dx, 'dy': dy, 'name': order[gid]})
        fonts = []
        for fi, f in enumerate(FONT_FILES):
            used = sorted({g['gid'] for g in glyphs if g['font'] == fi})
            if not used:
                continue
            tt = tts[fi]
            order = tt.getGlyphOrder()
            rev = {}
            for cp, name in sorted(tt.getBestCmap().items()):
                rev.setdefault(order.index(name), cp)
            entry = {'index': fi, 'file': f,
                     'sha256': hashlib.sha256(datas[fi]).hexdigest(),
                     'bytes': len(datas[fi]), 'num_glyphs': tt['maxp'].numGlyphs,
                     **metrics(tt),
                     'glyph_to_unicode': {str(g): rev[g] for g in used if g in rev},
                     # Verified with fontTools, never assumed from appearance.
                     'composites': [{'gid': g, 'name': order[g],
                                     'components': [{'name': c.glyphName, 'gid': tt.getGlyphID(c.glyphName)}
                                                    for c in tt['glyf'][order[g]].components]}
                                    for g in used if tt['glyf'][order[g]].isComposite()]}
            if do_subset and entry['composites']:
                print(cid, 'composite glyphs used:', entry['composites'])
            if do_subset:
                run_cps = [cps[i] for r in runs if r['font'] == fi for i in range(r['start'], r['end'])]
                sub = subset(datas[fi], used, run_cps)
                sp = out / 'fonts' / f'{cid}.{f[:-4]}.subset.ttf'
                sp.write_bytes(sub)
                problems = []
                st = TTFont(str(sp))
                for c in entry['composites']:
                    sg = st['glyf'][st.getGlyphOrder()[c['gid']]]
                    if not sg.isComposite():
                        problems.append(f"gid {c['gid']}: not composite in subset")
                    for k in c['components']:
                        if st['glyf'][st.getGlyphOrder()[k['gid']]].numberOfContours == 0:
                            problems.append(f"gid {c['gid']}: component {k['name']} (gid {k['gid']}) empty in subset")
                for r in runs:
                    if r['font'] != fi:
                        continue
                    shaped = shape_run(datas[fi], cps, r['start'], r['end'])
                    problems += check_subset(font_dir / f, sp, used, cps, r['start'], r['end'], shaped)
                entry['subset'] = {'file': f'fonts/{sp.name}', 'bytes': len(sub),
                                   'sha256': hashlib.sha256(sub).hexdigest(),
                                   'reduction_pct': round(100 * (1 - len(sub) / len(datas[fi])), 1),
                                   'checks': 'PASS' if not problems else 'FAIL',
                                   'problems': problems}
            fonts.append(entry)
        res = {'id': cid, 'text': text, 'codepoints': ['U+%04X' % c for c in cps],
               'harfbuzz': hb.version_string(), 'uharfbuzz': hb.__version__,
               'runs': runs, 'fonts': fonts, 'glyphs': glyphs}
        (out / f'{cid}.hb.json').write_text(json.dumps(res, ensure_ascii=False, indent=2))
        print(cid, json.dumps({k: res[k] for k in ('codepoints', 'runs')}),
              [(f['file'], f['bytes'], f.get('subset', {}).get('bytes'), f.get('subset', {}).get('checks')) for f in fonts])


if __name__ == '__main__':
    main()
