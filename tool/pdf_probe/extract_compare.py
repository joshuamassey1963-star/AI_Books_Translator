#!/usr/bin/env python3
"""M2b-3b-2b: strict multi-extractor comparison for Engine C PDFs.

Run after verify.py (which renders, makes the HarfBuzz/raqm reference,
runs qpdf/pdffonts and applies the visual review). For every PDF this adds:
  poppler  pdftotext (-enc UTF-8 -nopgbrk)
  mupdf    PyMuPDF page.get_text()          (pinned in CI)
  pdfjs4   extracted/<id>.pdfjs4.txt        (pdfjs-dist 4.10.38, pinned in CI)
  pdfjs6   extracted/<id>.pdfjs6.txt        (pdfjs-dist 6.5.438, pinned in CI)
  firefox  viewer/firefox.json copied text  (real Firefox viewer, automated)
  pdfium   extracted/<id>.pdfium.txt        (pdfrx/PDFium chromium/8125)
"Exact" is STRICT: only trailing newlines/form feeds are removed. No NFC,
no whitespace folding. A missing extractor is reported as n/a.

usage: extract_compare.py <out_dir> <hb_dir>
"""
import collections, hashlib, json, subprocess, sys
from pathlib import Path

out, hb_dir = Path(sys.argv[1]), Path(sys.argv[2])
report = json.loads((out / 'report.json').read_text())
gen = json.loads((out / 'generation.json').read_text())
controls = {c['id']: c.get('control') for c in gen['cases']}
experiments = {c['id']: c.get('experiment') for c in gen['cases']}
ff_path = out / 'viewer' / 'firefox.json'
firefox = json.loads(ff_path.read_text()) if ff_path.exists() else {}
gmeta = {g['id']: g for g in gen['generation']}


def sh(*a):
    try:
        return subprocess.run(a, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return None


def strip_end(s):
    return s.rstrip('\n\f')


def cps(s):
    return ' '.join(f'{ord(c):04X}' for c in s)


try:
    import pymupdf
    mupdf_version = f'PyMuPDF {pymupdf.VersionBind} / MuPDF {pymupdf.VersionFitz}'
except ImportError:
    pymupdf = None
    mupdf_version = 'n/a'


def extract(name, pdf, cid):
    if name == 'poppler':
        r = sh('pdftotext', '-enc', 'UTF-8', '-nopgbrk', str(pdf), '-')
        return None if r is None else r.stdout
    if name == 'mupdf':
        return None if pymupdf is None else pymupdf.open(str(pdf))[0].get_text()
    if name == 'firefox':
        c = firefox.get('cases', {}).get(cid)
        if not c or 'error' in c or not c.get('opened'):
            return None
        return c.get('copied') or c.get('selection')
    f = out / 'extracted' / f'{cid}.{name}.txt'
    return f.read_text(encoding='utf-8') if f.exists() else None


def compare(expected, raw):
    if raw is None:
        return {'result': 'n/a'}
    got = strip_end(raw)
    e, g = collections.Counter(expected), collections.Counter(got)
    missing = sorted(f'U+{ord(c):04X}' for c in (e - g).elements())
    extra = sorted(f'U+{ord(c):04X}' for c in (g - e).elements())
    words = [w for w in expected.split(' ') if w]
    return {
        'result': 'EXACT' if got == expected else 'DIFF',
        'text': got, 'codepoints': cps(got),
        'missing': missing, 'extra': extra,
        'duplicated_source': len(got) > len(expected) and expected in got,
        'words_found': f'{sum(1 for w in words if w in got)}/{len(words)}',
    }


EXTRACTORS = ['poppler', 'mupdf', 'pdfium', 'pdfjs4', 'pdfjs6', 'firefox']
for r in report['cases']:
    cid = r['id']
    pdf = out / 'pdf' / f'{cid}.pdf'
    expected = (out / 'expected' / f'{cid}.txt').read_text(encoding='utf-8')
    r['expected_codepoints'] = cps(expected)
    r['pdf_sha256'] = hashlib.sha256(pdf.read_bytes()).hexdigest()
    r['pdf_bytes'] = pdf.stat().st_size
    r['embedded_font_bytes'] = gmeta[cid].get('fonts')
    r['control'] = controls.get(cid)
    r['experiment'] = experiments.get(cid)
    fc = firefox.get('cases', {}).get(cid)
    if fc:
        r['firefox_find'] = fc.get('find')
        r['firefox_find_all_words'] = fc.get('find_all_words')
    r['extractors'] = {n: compare(expected, extract(n, pdf, cid)) for n in EXTRACTORS}
    for n, v in r['extractors'].items():
        if 'text' in v:
            (out / 'extracted' / f'{cid}.{n}.strict.txt').write_text(v['text'], encoding='utf-8')
    primary = [r['extractors'][n]['result'] for n in ('poppler', 'mupdf')]
    agree = len({v['result'] for v in r['extractors'].values() if v['result'] != 'n/a'}) == 1
    r['extractors_agree'] = agree
    if r['control']:
        r['overall_c'] = 'CONTROL'
    elif r['experiment']:
        r['overall_c'] = 'EXPERIMENT'
    elif r.get('qpdf_check') != 'ok':
        r['overall_c'] = 'FAIL (structure)'
    elif r['visual'] == 'NEEDS_REVIEW':
        r['overall_c'] = 'NEEDS_REVIEW'
    elif r['visual'] == 'PASS' and all(p == 'EXACT' for p in primary):
        r['overall_c'] = 'PASS'
    elif r['visual'] == 'FAIL' and all(p != 'EXACT' for p in primary):
        r['overall_c'] = 'FAIL'
    else:
        r['overall_c'] = 'PARTIAL'

# full-font vs subset-font render, pixel by pixel (same pdftoppm settings)
try:
    from PIL import Image, ImageChops
    for r in report['cases']:
        if r['id'].endswith('_subset'):
            base = r['id'][:-len('_subset')]
            pa, pb = sorted((out / 'png').glob(f'{base}-*.png')), sorted((out / 'png').glob(f"{r['id']}-*.png"))
            if pa and pb:
                ia, ib = Image.open(pa[0]).convert('L'), Image.open(pb[0]).convert('L')
                r['subset_render_identical_to_full'] = ia.size == ib.size and ImageChops.difference(ia, ib).getbbox() is None
except ImportError:
    pass

# fonts report
fr = out / 'fonts-report'
fr.mkdir(exist_ok=True)
fonts = []
for j in sorted(hb_dir.glob('*.hb.json')):
    d = json.loads(j.read_text())
    (fr / j.name).write_text(j.read_text())
    for f in d['fonts']:
        fonts.append({'case': d['id'], 'font': f['file'], 'sha256': f['sha256'], 'bytes': f['bytes'],
                      'subset_bytes': f.get('subset', {}).get('bytes'),
                      'reduction_pct': f.get('subset', {}).get('reduction_pct'),
                      'subset_checks': f.get('subset', {}).get('checks'),
                      'subset_problems': f.get('subset', {}).get('problems'),
                      'harfbuzz': d['harfbuzz'], 'uharfbuzz': d['uharfbuzz']})
pdffonts = {p.stem: (sh('pdffonts', str(p)).stdout if sh('pdffonts', str(p)) else 'n/a')
            for p in sorted((out / 'pdf').glob('*.pdf'))}
(fr / 'fonts.json').write_text(json.dumps({'fonts': fonts, 'pdffonts': pdffonts}, ensure_ascii=False, indent=2))


def first_line(*a):
    r = sh(*a)
    return 'n/a' if r is None else ((r.stdout or r.stderr).strip().splitlines() or ['n/a'])[0]


report['tools'] = {
    'pdftotext': first_line('pdftotext', '-v'),
    'qpdf': first_line('qpdf', '--version'),
    'mupdf': mupdf_version,
    'pdfjs4': (out / 'extracted' / 'PDFJS_VERSION_pdfjs4').read_text().strip()
    if (out / 'extracted' / 'PDFJS_VERSION_pdfjs4').exists() else 'n/a',
    'pdfjs6': (out / 'extracted' / 'PDFJS_VERSION_pdfjs6').read_text().strip()
    if (out / 'extracted' / 'PDFJS_VERSION_pdfjs6').exists() else 'n/a',
    'firefox': f"Firefox {firefox.get('firefox')} ({firefox.get('os')}), built-in PDF.js {firefox.get('pdfjs_in_firefox')}"
    if firefox.get('firefox') else firefox.get('error', 'n/a'),
    'pdfium': 'bblanchon/pdfium-binaries chromium/8125 via pdfrx_engine (D-021)',
    'harfbuzz': fonts[0]['harfbuzz'] if fonts else 'n/a',
    'uharfbuzz': fonts[0]['uharfbuzz'] if fonts else 'n/a',
}
report['note_c'] = ('Exact = strict string equality after removing trailing newlines only. '
                    'Word match is a programmatic substring test on extracted text, not an '
                    'interactive viewer search. overall_c = qpdf ok + visual PASS + poppler '
                    'and MuPDF exact; PDFium, PDF.js and the Firefox viewer are reported as interoperability evidence. '
                    'firefox = automated Selenium run of the real Firefox viewer (copy handler + find), not a human test.')
(out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))

md = ['# Engine C (HarfBuzz + /ActualText) – M2b-3b-2b', '',
      '| case | qpdf | visual | poppler | MuPDF | PDFium | PDF.js 4 | PDF.js 6 | Firefox copy | Firefox find | ToUnicode | PDF bytes | overall |',
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|']
for r in report['cases']:
    x = r['extractors']
    ff = r.get('firefox_find')
    md.append('| {id} | {q} | {v} | {p} | {m} | {f} | {j4} | {j6} | {fc} | {fw} | {u} | {b} | {o} |'.format(
        id=r['id'], q=r.get('qpdf_check'), v=r['visual'], p=x['poppler']['result'], m=x['mupdf']['result'],
        f=x['pdfium']['result'], j4=x['pdfjs4']['result'], j6=x['pdfjs6']['result'], fc=x['firefox']['result'],
        fw='n/a' if ff is None else f"{sum(1 for v in ff.values() if (v or 0) >= 1)}/{len(ff)}",
        u=' '.join(f['uni'] for f in r.get('fonts', [])), b=r['pdf_bytes'], o=r['overall_c']))
md += ['', '## Full vs subset render (pixel identical)', '']
md += [f"- {r['id']}: {r.get('subset_render_identical_to_full')}" for r in report['cases'] if r['id'].endswith('_subset')]
md += ['', '## Extractor output (code points)', '']
for r in report['cases']:
    md.append(f"- **{r['id']}** expected `{r['expected_codepoints']}`" + (f" (control: {r['control']})" if r['control'] else '') + (f" (experiment: {r['experiment']})" if r['experiment'] else '') + (f" firefox find {r.get('firefox_find')}" if r.get('firefox_find') is not None else ''))
    for n, v in r['extractors'].items():
        if v['result'] == 'n/a':
            md.append(f'  - {n}: n/a')
        else:
            md.append(f"  - {n}: {v['result']} `{v['codepoints']}` missing={v['missing']} extra={v['extra']} dup={v['duplicated_source']}")
md += ['', '## Fonts', '', '| case | font | full bytes | subset bytes | reduction | subset checks |', '|---|---|---|---|---|---|']
for f in fonts:
    md.append(f"| {f['case']} | {f['font']} | {f['bytes']} | {f['subset_bytes']} | {f['reduction_pct']}% | {f['subset_checks']} {f['subset_problems'] or ''} |")
md += ['', '## Tools', ''] + [f'- {k}: {v}' for k, v in report['tools'].items()] + ['', report['note_c']]
(out / 'report.md').write_text('\n'.join(md) + '\n')
print('\n'.join(md))

# Regression gate (M2b-3b-2c-1): EXACT must stay EXACT.
gate = json.loads((Path(__file__).with_name('interop_expectations.json')).read_text())
regressions, improved = [], []
for r in report['cases']:
    for name, want in gate['cases'].get(r['id'], {}).items():
        got = r['extractors'].get(name, {}).get('result')
        if want == 'EXACT' and got != 'EXACT':
            regressions.append(f"{r['id']}/{name}: expected EXACT, got {got}")
        if want == 'KNOWN_DIFF' and got == 'EXACT':
            improved.append(f"{r['id']}/{name}: IMPROVED (was KNOWN_DIFF)")
for line in improved:
    print('IMPROVED', line)
if regressions:
    print('INTEROP REGRESSION:\n  ' + '\n  '.join(regressions))
    sys.exit(1)
print('interop gate: no regression;', len(improved), 'improvement(s)')
