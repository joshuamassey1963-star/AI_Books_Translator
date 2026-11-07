#!/usr/bin/env python3
"""M2b-3b-2c-3: ONE bounded PDF.js mitigation candidate (probe only, D-033).

Candidate "word-1:1 ToUnicode": keep word-level /ActualText (Engine C default)
and add a ToUnicode entry for a glyph ONLY when
  1. every cluster of every word the glyph occurs in is exactly one glyph and
     one source code point (the word's glyph text then equals its /ActualText
     exactly, so no reader gets conflicting text), and
  2. the glyph maps to the same code point at every occurrence in the PDF.
Glyphs in conjuncts, reordered matras, ligatures, half forms or any word
containing such a cluster stay unmapped (strict policy). No invisible text,
no reordering, no normalisation.

Why whole words: the M2b-3b-2c-3 controls showed that MuPDF 1.28.6 duplicates
the last character when a span's LAST glyph is mapped to a multi-byte UTF-8
character but earlier glyphs are not (stext-device.c postfix path: flush
length uses strlen() bytes minus a rune count). A fully mapped word takes the
prefix path, which consumes the whole span.

Writes, per case (subset fonts, same glyphs/positions as Engine C):
  <case>_cand0   same Python writer, NO ToUnicode entries (control: isolates
                 the ToUnicode change; must render pixel-identical to _cand)
  <case>_cand    the candidate
and two minimal MuPDF controls that map only the last glyph of a word:
  c01_kitab_ctl_lastglyph (ब)   c06_composite_ctl_lastglyph (ज)
usage: tounicode_candidate.py <hb_dir> <out_dir>
"""
import hashlib, json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from cluster_cid_experiment import build  # noqa: E402


def words_of(fx):
    text = fx['text']
    clusters = []
    for g in fx['glyphs']:
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
    return words


def candidate_map(fx):
    """{font: {gid: text}} plus a per-word explanation."""
    seen, why = {}, []
    for w in words_of(fx):
        one = all(len(c['glyphs']) == 1 and len(c['text']) == 1 for c in w)
        why.append({'word': ''.join(c['text'] for c in w), 'all_1to1': one})
        for c in w:
            for g in c['glyphs']:
                k = (g['font'], g['gid'])
                s = seen.setdefault(k, {'texts': set(), 'all_1to1': True})
                s['texts'].add(c['text'] if one else None)
                s['all_1to1'] &= one
    out = {}
    for (fi, gid), s in seen.items():
        if s['all_1to1'] and len(s['texts']) == 1 and None not in s['texts']:
            out.setdefault(fi, {})[gid] = next(iter(s['texts']))
    return out, why


def main():
    hb_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
    (out / 'pdf').mkdir(parents=True, exist_ok=True)
    (out / 'expected').mkdir(parents=True, exist_ok=True)
    gen_path = out / 'generation.json'
    gen = json.loads(gen_path.read_text())
    plan = {}
    for j in sorted(hb_dir.glob('c0[1-6]_*.hb.json')):
        fx = json.loads(j.read_text())
        fonts = {f['index']: f for f in fx['fonts']}

        def fb(i):
            return (hb_dir / fonts[i]['subset']['file']).read_bytes()
        cmap, why = candidate_map(fx)
        variants = [('_cand0', {}, 'control: Python writer, word /ActualText, no ToUnicode'),
                    ('_cand', cmap, 'CANDIDATE word-1:1 ToUnicode + word /ActualText')]
        last = fx['glyphs'][-1]
        if fx['id'] in ('c01_kitab', 'c06_composite'):
            ch = fx['text'][last['cluster']:]
            variants.append(('_ctl_lastglyph', {last['font']: {last['gid']: ch}},
                             f'MuPDF control: only the last glyph mapped ({ch})'))
        for suffix, tu, label in variants:
            pdf = build(fx, fb, actual_text=True, per_occurrence=False, tu_override=tu)
            cid = f"{fx['id']}{suffix}"
            (out / 'pdf' / f'{cid}.pdf').write_bytes(pdf)
            (out / 'expected' / f'{cid}.txt').write_text(fx['text'], encoding='utf-8')
            gen['cases'].append({'id': cid, 'title': f"{fx['id']} {label}, subset fonts",
                                 'tCases': [], 'rtl': False, 'experiment': 'tounicode_candidate'})
            gen['generation'].append({'id': cid, 'generated': True, 'bytes': len(pdf),
                                      'sha256': hashlib.sha256(pdf).hexdigest(),
                                      'fonts': [len(fb(i)) for i in sorted(fonts)]})
        plan[fx['id']] = {'mapped': {str(fi): {str(g): 'U+%04X' % ord(t) for g, t in m.items()} for fi, m in cmap.items()},
                          'words': why}
        print(fx['id'], 'candidate ToUnicode:', plan[fx['id']]['mapped'] or 'none')
    gen_path.write_text(json.dumps(gen, ensure_ascii=False, indent=2))
    (out / 'candidate_plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
