#!/usr/bin/env python3
"""M2b-3b-2c-3 decision gate for the word-1:1 ToUnicode candidate (D-033).

Reads <out>/report.json written by extract_compare.py and compares, per case
C01–C06, the established default (<case>_word_subset, Dart Engine C writer)
with the candidate (<case>_cand) and its control (<case>_cand0).
Exact code points only; nothing is normalised, folded or ignored.
Stop conditions (any one => candidate FAIL):
  Poppler / MuPDF / PDFium not EXACT on _cand; any duplicated source text;
  _cand not pixel-identical to _cand0 (ToUnicode must not change rendering);
  qpdf not ok.
Writes <out>/candidate_verdict.json and candidate_verdict.md. Exit code is 0:
this is an experiment result; the interop gate stays the CI blocker.
usage: candidate_verdict.py <out_dir>
"""
import json, sys
from pathlib import Path

out = Path(sys.argv[1])
rep = {r['id']: r for r in json.loads((out / 'report.json').read_text())['cases']}
CASES = ['c01_kitab', 'c02_kshetra', 'c03_rashtra_mixed', 'c04_zwj', 'c05_zwnj', 'c06_composite']
VIEW = ['pdfjs4', 'pdfjs6', 'firefox']


def same_png(a, b):
    try:
        from PIL import Image, ImageChops
    except ImportError:
        return None
    pa, pb = sorted((out / 'png').glob(f'{a}-*.png')), sorted((out / 'png').glob(f'{b}-*.png'))
    if not pa or not pb:
        return None
    ia, ib = Image.open(pa[0]).convert('L'), Image.open(pb[0]).convert('L')
    return ia.size == ib.size and ImageChops.difference(ia, ib).getbbox() is None


def find_score(r):
    f = (r or {}).get('firefox_find') or {}
    return f"{sum(1 for v in f.values() if v)}/{len(f)}" if f else 'n/a'


rows, stops, counts = [], [], {n: {'improved': 0, 'regressed': 0, 'unchanged': 0} for n in VIEW + ['firefox_find']}
for c in CASES:
    base, cand, ctl = rep.get(f'{c}_word_subset'), rep.get(f'{c}_cand'), rep.get(f'{c}_cand0')
    if not (base and cand and ctl):
        stops.append(f'{c}: missing PDFs')
        continue
    row = {'case': c, 'baseline_sha256': base['pdf_sha256'], 'candidate_sha256': cand['pdf_sha256'],
           'control_sha256': ctl['pdf_sha256'], 'qpdf': cand.get('qpdf_check')}
    for n in ['poppler', 'mupdf', 'pdfium']:
        v = cand['extractors'][n]
        row[n] = v['result']
        if v['result'] != 'EXACT':
            stops.append(f"{c}/{n}: {v['result']} {v.get('codepoints')}")
        if v.get('duplicated_source'):
            stops.append(f'{c}/{n}: duplicated text')
    for n in VIEW:
        b, a = base['extractors'][n]['result'], cand['extractors'][n]['result']
        row[n] = f'{b} -> {a}'
        k = 'improved' if (b != 'EXACT' and a == 'EXACT') else 'regressed' if (b == 'EXACT' and a != 'EXACT') else 'unchanged'
        counts[n][k] += 1
        if cand['extractors'][n].get('duplicated_source'):
            stops.append(f'{c}/{n}: duplicated text')
    fb, fa = find_score(base), find_score(cand)
    row['firefox_find'] = f'{fb} -> {fa}'
    try:
        nb, na = int(fb.split('/')[0]), int(fa.split('/')[0])
        counts['firefox_find']['improved' if na > nb else 'regressed' if na < nb else 'unchanged'] += 1
    except ValueError:
        counts['firefox_find']['unchanged'] += 1
    row['pixel_cand_eq_control'] = same_png(f'{c}_cand', f'{c}_cand0')
    row['pixel_cand_eq_default'] = same_png(f'{c}_cand', f'{c}_word_subset')
    if row['pixel_cand_eq_control'] is not True:
        stops.append(f"{c}: render changed by ToUnicode ({row['pixel_cand_eq_control']})")
    if row['qpdf'] != 'ok':
        stops.append(f"{c}: qpdf {row['qpdf']}")
    rows.append(row)

controls = {k: {n: rep[k]['extractors'][n].get('codepoints') + ' ' + rep[k]['extractors'][n]['result']
                for n in ['poppler', 'mupdf', 'pdfium']}
            for k in ('c01_kitab_ctl_lastglyph', 'c06_composite_ctl_lastglyph') if k in rep}
gain = sum(counts[n]['improved'] for n in counts)
verdict = 'FAIL' if stops else ('PASS' if gain else 'INCONCLUSIVE')
res = {'candidate': 'word-1:1 ToUnicode + word /ActualText (D-033)', 'verdict': verdict,
       'stop_conditions_hit': stops, 'counts': counts, 'rows': rows, 'mupdf_last_glyph_controls': controls}
(out / 'candidate_verdict.json').write_text(json.dumps(res, ensure_ascii=False, indent=2))
md = ['## M2b-3b-2c-3 candidate verdict: **' + verdict + '**', '',
      '| case | qpdf | poppler | mupdf | pdfium | pdfjs4 | pdfjs6 | firefox copy | firefox find | px cand=ctl | px cand=default |',
      '|---|---|---|---|---|---|---|---|---|---|---|']
for r in rows:
    md.append(f"| {r['case']} | {r['qpdf']} | {r['poppler']} | {r['mupdf']} | {r['pdfium']} | {r['pdfjs4']} | {r['pdfjs6']} | {r['firefox']} | {r['firefox_find']} | {r['pixel_cand_eq_control']} | {r['pixel_cand_eq_default']} |")
md += ['', f'counts: {json.dumps(counts)}', f'stop conditions: {stops or "none"}', f'MuPDF last-glyph controls: {json.dumps(controls, ensure_ascii=False)}']
(out / 'candidate_verdict.md').write_text('\n'.join(md) + '\n')
print('\n'.join(md))
