#!/usr/bin/env python3
"""Rebuild probe output (pdf/, expected/, generation.json) for Engine B.

Source: manifest.json pulled from the emulator, or, if the app was removed,
the `PROBE i/n <base64>` lines printed by the integration test.
usage: unpack_manifest.py <out_dir> <manifest.json or test log>
"""
import base64, json, re, sys
from pathlib import Path

out, src = Path(sys.argv[1]), Path(sys.argv[2])
text = src.read_text(errors='replace')
if src.suffix == '.json':
    manifest = json.loads(text)
else:
    chunks = {}
    total = None
    for m in re.finditer(r'PROBE (\d+)/(\d+) ([A-Za-z0-9+/=]+)', text):
        chunks[int(m.group(1))] = m.group(3)
        total = int(m.group(2))
    if total is None or len(chunks) != total:
        sys.exit(f'incomplete PROBE output: {len(chunks)}/{total}')
    manifest = json.loads(base64.b64decode(''.join(chunks[i] for i in range(total))))
(out / 'pdf').mkdir(parents=True, exist_ok=True)
(out / 'expected').mkdir(exist_ok=True)
for cid, b64 in manifest['pdfs'].items():
    (out / 'pdf' / f'{cid}.pdf').write_bytes(base64.b64decode(b64))
for cid, t in manifest['expected'].items():
    (out / 'expected' / f'{cid}.txt').write_text(t)
gen = {k: manifest[k] for k in ('engine', 'device', 'cases', 'generation')}
(out / 'generation.json').write_text(json.dumps(gen, ensure_ascii=False, indent=2))
print('unpacked', len(manifest['pdfs']), 'PDFs; device', manifest.get('device'))
