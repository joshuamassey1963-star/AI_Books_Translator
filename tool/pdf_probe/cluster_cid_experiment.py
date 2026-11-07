#!/usr/bin/env python3
"""M2b-3b-2c-1 EXPERIMENT (probe only, not the app writer): cluster-level
ToUnicode through per-occurrence CIDs, for readers that ignore /ActualText
(PDF.js 4.10.38 and 6.5.438 read only MCID/tag from BDC properties).

Same HarfBuzz glyphs, positions and word-level /ActualText spans as Engine C
(D-030). Difference: every drawn glyph gets its own CID (CIDToGIDMap is a
stream, so the glyph drawn is unchanged), and the ToUnicode CMap maps
  - the first drawn glyph of each cluster -> the cluster's full source text
    (like a ligature: one glyph code -> several code points), and
  - every further glyph of that cluster -> an empty string (it adds no text).
No glyph is mapped to a code point it does not stand for in visual order;
no invisible text is added; the source string is never reordered.

usage: cluster_cid_experiment.py <hb_dir> <out_dir> [--subset]
writes <out_dir>/pdf/<case>_cidmap.pdf and expected/<case>_cidmap.txt and
appends to <out_dir>/generation.json.
"""
import hashlib, json, sys
from pathlib import Path

FONT_DIR = None


def utf16(s):
    return 'FEFF' + s.encode('utf-16-be').hex().upper()


def build(fx, font_bytes, actual_text=True, size=28, x0=20.0, base=50.0, page=(360, 100)):
    text = fx['text']
    glyphs = fx['glyphs']
    fonts = {f['index']: f for f in fx['fonts']}
    # clusters (same rules as ShapedRun.clusters) and word groups (same as
    # ActualTextScope.word)
    clusters = []
    for g in glyphs:
        if clusters and clusters[-1]['start'] == g['cluster']:
            clusters[-1]['glyphs'].append(g)
        else:
            clusters.append({'start': g['cluster'], 'font': g['font'], 'glyphs': [g]})
    for i, c in enumerate(clusters):
        c['end'] = clusters[i + 1]['start'] if i + 1 < len(clusters) else len(text)
        c['text'] = text[c['start']:c['end']]
    words = []
    for c in clusters:
        sp = c['text'].strip() == ''
        if words and not sp and words[-1][-1]['text'].strip() and words[-1][-1]['font'] == c['font']:
            words[-1].append(c)
        else:
            words.append([c])
    next_cid = {fi: 1 for fi in fonts}
    cid_gid = {fi: {} for fi in fonts}
    cid_uni = {fi: {} for fi in fonts}
    cid_w = {fi: {} for fi in fonts}
    ops, x, cur = ['BT'], x0, None
    for w in words:
        if actual_text:
            ops.append(f"/Span <</ActualText <{utf16(''.join(c['text'] for c in w))}>>> BDC")
        for c in w:
            for k, g in enumerate(c['glyphs']):
                fi = g['font']
                cid = next_cid[fi]
                next_cid[fi] += 1
                cid_gid[fi][cid] = g['gid']
                cid_uni[fi][cid] = c['text'] if k == 0 else ''
                upem = fonts[fi]['upem']
                cid_w[fi][cid] = round(g['ax'] * 1000 / upem)
                if fi != cur:
                    cur = fi
                    ops.append(f'/F{fi + 1} {size} Tf')
                sc = size / upem
                ops.append(f"1 0 0 1 {x + g['dx'] * sc:.3f} {base + g['dy'] * sc:.3f} Tm <{cid:04X}> Tj")
                x += g['ax'] * sc
        if actual_text:
            ops.append('EMC')
    ops.append('ET')
    content = '\n'.join(ops).encode()

    def stream(extra, data):
        return b'<< /Length %d%s >>\nstream\n' % (len(data), extra.encode()) + data + b'\nendstream'

    objs = [b'<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked true >> >>',
            b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>', None, stream('', content)]
    refs = []
    for fi in sorted(fonts):
        f = fonts[fi]
        name = f['file'][:-4]
        n = len(objs) + 1
        maxcid = next_cid[fi] - 1
        gidmap = bytearray(2 * (maxcid + 1))
        for cid, gid in cid_gid[fi].items():
            gidmap[2 * cid:2 * cid + 2] = gid.to_bytes(2, 'big')
        W = ' '.join(f'{c} [{w}]' for c, w in sorted(cid_w[fi].items()))
        bf = [f"<{c:04X}> <{u.encode('utf-16-be').hex().upper()}>" for c, u in sorted(cid_uni[fi].items())]
        cmap = ('/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n'
                '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n'
                '/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\n'
                'endcodespacerange\n%d beginbfchar\n%s\nendbfchar\nendcmap\n'
                'CMapName currentdict /CMap defineresource pop\nend\nend' % (len(bf), '\n'.join(bf))).encode()
        fb = font_bytes(fi)
        bb = ' '.join(map(str, f['bbox']))
        objs += [
            f'<< /Type /Font /Subtype /Type0 /BaseFont /{name} /Encoding /Identity-H /DescendantFonts [{n + 1} 0 R] /ToUnicode {n + 5} 0 R >>'.encode(),
            f'<< /Type /Font /Subtype /CIDFontType2 /BaseFont /{name} /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor {n + 2} 0 R /CIDToGIDMap {n + 4} 0 R /W [{W}] /DW 1000 >>'.encode(),
            f"<< /Type /FontDescriptor /FontName /{name} /Flags 4 /FontBBox [{bb}] /ItalicAngle 0 /Ascent {f['ascent']} /Descent {f['descent']} /CapHeight {f['cap_height']} /StemV 80 /FontFile2 {n + 3} 0 R >>".encode(),
            stream(f' /Length1 {len(fb)}', fb),
            stream('', bytes(gidmap)),
            stream('', cmap),
        ]
        refs.append(f'/F{fi + 1} {n} 0 R')
    objs[2] = (f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {page[0]} {page[1]}] '
               f"/Resources << /Font << {' '.join(refs)} >> >> /Contents 4 0 R >>").encode()
    out = bytearray(b'%PDF-1.7\n%\xe2\xe3\xcf\xd3\n')
    offs = []
    for k, o in enumerate(objs, 1):
        offs.append(len(out))
        out += b'%d 0 obj\n' % k + o + b'\nendobj\n'
    xr = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % (len(objs) + 1)
    for o in offs:
        out += b'%010d 00000 n \n' % o
    out += b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' % (len(objs) + 1, xr)
    return bytes(out)


def main():
    hb_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
    (out / 'pdf').mkdir(parents=True, exist_ok=True)
    (out / 'expected').mkdir(parents=True, exist_ok=True)
    gen_path = out / 'generation.json'
    gen = json.loads(gen_path.read_text()) if gen_path.exists() else {'engine': 'engine_c_hb_actualtext', 'cases': [], 'generation': []}
    for j in sorted(hb_dir.glob('*.hb.json')):
        fx = json.loads(j.read_text())
        fonts = {f['index']: f for f in fx['fonts']}
        def fb(i):
            return (hb_dir / fonts[i]['subset']['file']).read_bytes()
        for at, suffix, label in ((True, '_cidmap', 'cluster-CID ToUnicode + word /ActualText'),
                                  (False, '_cidmap_noat', 'cluster-CID ToUnicode only, no /ActualText')):
            pdf = build(fx, fb, actual_text=at)
            cid = f"{fx['id']}{suffix}"
            (out / 'pdf' / f'{cid}.pdf').write_bytes(pdf)
            (out / 'expected' / f'{cid}.txt').write_text(fx['text'], encoding='utf-8')
            gen['cases'].append({'id': cid, 'title': f"{fx['id']} EXPERIMENT {label}, subset fonts",
                                 'tCases': [], 'rtl': False, 'experiment': 'cluster_cid'})
            gen['generation'].append({'id': cid, 'generated': True, 'bytes': len(pdf),
                                      'sha256': hashlib.sha256(pdf).hexdigest(),
                                      'fonts': [len(fb(i)) for i in sorted(fonts)]})
            print(cid, len(pdf))
    gen_path.write_text(json.dumps(gen, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
