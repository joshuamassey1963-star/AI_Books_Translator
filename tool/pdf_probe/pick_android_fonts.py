#!/usr/bin/env python3
"""Pick the emulator font files that Engine B's PDFs actually embed, so the
HarfBuzz reference uses the same fonts. Prints KEY=path lines for $GITHUB_ENV.
usage: pick_android_fonts.py <probe_out_dir> <pulled_fonts_dir>
"""
import re, subprocess, sys
from pathlib import Path

out, fdir = Path(sys.argv[1]), Path(sys.argv[2])
norm = lambda s: re.sub(r'(regular|vf|[^a-z0-9])', '', s.lower())
names = set()
for pdf in sorted((out / 'pdf').glob('*.pdf')):
    rows = subprocess.run(['pdffonts', str(pdf)], capture_output=True, text=True).stdout.splitlines()[2:]
    names |= {r.split()[0].split('+')[-1] for r in rows if r.strip()}
files = sorted(p for p in fdir.iterdir() if p.suffix.lower() in ('.ttf', '.otf', '.ttc'))
print('# embedded fonts:', sorted(names), file=sys.stderr)
deva = latin = None
for n in names:
    match = next((f for f in files if norm(f.stem) == norm(n)), None) or \
        next((f for f in files if norm(n).startswith(norm(f.stem)) or norm(f.stem).startswith(norm(n))), None)
    print(f'# {n} -> {match}', file=sys.stderr)
    if match is None:
        continue
    if 'devanagari' in match.name.lower():
        deva = deva or match
    else:
        latin = latin or match
deva = deva or next((f for f in files if 'Devanagari' in f.name and 'Serif' not in f.name), None)
latin = latin or next((f for f in files if f.name.startswith('Roboto-Regular')), None)
if deva:
    print(f'PROBE_DEVA_FONT={deva}')
if latin:
    print(f'PROBE_LATIN_FONT={latin}')
print('PROBE_LATIN_FIRST=1')
