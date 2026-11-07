#!/usr/bin/env python3
"""M2b-3b-2b: strict multi-extractor comparison for Engine C PDFs.

Run after verify.py (which renders, makes the HarfBuzz/raqm reference,
runs qpdf/pdffonts and applies the visual review). For every PDF this adds:
  poppler  pdftotext (-enc UTF-8 -nopgbrk)
  mupdf    PyMuPDF page.get_text()          (pinned in CI)
  pdfjs    extracted/<id>.pdfjs.txt         (pdfjs-dist, pinned in CI)
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


EXTRACTORS = ['poppler', 'mupdf', 'pdfjs', 'pdfium']
for r in report['cases']:
    cid = r['id']
    pdf = out / 'pdf' / f'{cid}.pdf'
    expected = (out / 'expected' / f'{cid}.txt').read_text(encoding='utf-8')
    r['expected_codepoints'] = cps(expected)
    r['pdf_sha256'] = hashlib.sha256(pdf.read_bytes()).hexdigest()
    r['pdf_bytes'] = pdf.stat().st_size
    r['embedded_font_bytes'] = gmeta[cid].get('fonts')
    r['control'] = controls.get(cid)
    r['extractors'] = {n: compare(expected, extract(n, pdf, cid)) for n in EXTRACTORS}
    for n, v in r['extractors'].items():
        if 'text' in v:
            (out / 'extracted' / f'{cid}.{n}.strict.txt').write_text(v['text'], encoding='utf-8')
    primary = [r['extractors'][n]['result'] for n in ('poppler', 'mupdf')]
    agree = len({v['result'] for v in r['extractors'].values() if v['result'] != 'n/a'}) == 1
    r['extractors_agree'] = agree
    if r['control']:
        r['overall_c'] = 'CONTROL'
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
    'pdfjs': (out / 'extracted' / 'PDFJS_VERSION').read_text().strip()
    if (out / 'extracted' / 'PDFJS_VERSION').exists() else 'n/a',
    'pdfium': 'bblanchon/pdfium-binaries chromium/8125 via pdfrx_engine (D-021)',
    'harfbuzz': fonts[0]['harfbuzz'] if fonts else 'n/a',
    'uharfbuzz': fonts[0]['uharfbuzz'] if fonts else 'n/a',
}
report['note_c'] = ('Exact = strict string equality after removing trailing newlines only. '
                    'Word match is a programmatic substring test on extracted text, not an '
                    'interactive viewer search. overall_c = qpdf ok + visual PASS + poppler '
                    'and MuPDF exact; PDF.js and PDFium are reported as interoperability evidence.')
(out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))

md = ['# Engine C (HarfBuzz + /ActualText) – M2b-3b-2b', '',
      '| case | qpdf | visual | poppler | MuPDF | PDF.js | PDFium | words (poppler) | fonts embedded | ToUnicode | PDF bytes | overall |',
      '|---|---|---|---|---|---|---|---|---|---|---|---|']
for r in report['cases']:
    x = r['extractors']
    md.append('| {id} | {q} | {v} | {p} | {m} | {j} | {f} | {w} | {e} | {u} | {b} | {o} |'.format(
        id=r['id'], q=r.get('qpdf_check'), v=r['visual'], p=x['poppler']['result'], m=x['mupdf']['result'],
        j=x['pdfjs']['result'], f=x['pdfium']['result'], w=x['poppler'].get('words_found', ''),
        e=r.get('fonts_embedded'), u=' '.join(f['uni'] for f in r.get('fonts', [])), b=r['pdf_bytes'],
        o=r['overall_c']))
md += ['', '## Extractor output (code points)', '']
for r in report['cases']:
    md.append(f"- **{r['id']}** expected `{r['expected_codepoints']}`" + (f" (control: {r['control']})" if r['control'] else ''))
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
