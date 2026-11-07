#!/usr/bin/env python3
"""M2b-3b-2a: shape a fixture text with HarfBuzz (uharfbuzz, pinned in CI)
and write the glyph run as JSON for the Dart spike writer.

usage: hb_shape_fixture.py <font.ttf> <expected_text_file> <out.json>
Clusters are code point (rune) indices: the buffer is filled with
add_codepoints, so cluster i = i-th code point of the source text.
"""
import hashlib, json, sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

font_path, text_path, out_path = map(Path, sys.argv[1:4])
text = text_path.read_text(encoding='utf-8')
data = font_path.read_bytes()
face = hb.Face(hb.Blob(data))
font = hb.Font(face)
buf = hb.Buffer()
buf.add_codepoints([ord(c) for c in text])
buf.guess_segment_properties()
hb.shape(font, buf, {})
tt = TTFont(str(font_path))
order = tt.getGlyphOrder()
rev = {}
for cp, name in sorted(tt.getBestCmap().items()):
    rev.setdefault(order.index(name), cp)
glyphs = [{'gid': i.codepoint, 'cluster': i.cluster, 'ax': p.x_advance,
           'dx': p.x_offset, 'dy': p.y_offset, 'name': order[i.codepoint]}
          for i, p in zip(buf.glyph_infos, buf.glyph_positions)]
used = {g['gid'] for g in glyphs}
out = {
    'text': text,
    'codepoints': ['U+%04X' % ord(c) for c in text],
    'font': font_path.name,
    'font_sha256': hashlib.sha256(data).hexdigest(),
    'upem': face.upem,
    'direction': buf.direction,
    'script': buf.script,
    'harfbuzz': hb.version_string(),
    'uharfbuzz': hb.__version__,
    'glyphs': glyphs,
    'glyph_to_unicode': {str(g): rev[g] for g in sorted(used) if g in rev},
}
Path(out_path).write_text(json.dumps(out, ensure_ascii=False, indent=2))
print(json.dumps(out, ensure_ascii=False))
