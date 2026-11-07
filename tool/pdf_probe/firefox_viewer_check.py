#!/usr/bin/env python3
"""M2b-3b-2c-1: automated check in the REAL Firefox PDF viewer (built-in
PDF.js), driven by Selenium + geckodriver as preinstalled on GitHub's
ubuntu runners. Headless. For each PDF:
  1. open file:// URL in Firefox (built-in viewer, not pdfjs-dist),
  2. wait for the text layer, take a screenshot,
  3. select the whole text layer and fire the viewer's own copy handler
     (synthetic ClipboardEvent with a DataTransfer) -> copied text,
  4. run the viewer's find (PDFViewerApplication.eventBus 'find') for every
     space-separated word and read the match count.
This is automated browser interaction with Firefox's viewer code, not a
human test; the system clipboard and the find bar UI are not used.

usage: firefox_viewer_check.py <out_dir>   (reads pdf/, expected/)
writes viewer/firefox.json and viewer/firefox-<id>.png
"""
import json, sys, time, traceback
from pathlib import Path

out = Path(sys.argv[1])
vdir = out / 'viewer'
vdir.mkdir(exist_ok=True)
result = {'viewer': 'Firefox built-in PDF viewer (PDF.js)', 'mode': 'automated, headless, Selenium/geckodriver', 'cases': {}}
try:
    from selenium import webdriver
    from selenium.webdriver.firefox.options import Options
    opts = Options()
    opts.add_argument('-headless')
    opts.set_preference('pdfjs.disabled', False)
    opts.set_preference('browser.download.open_pdf_attachments_inline', True)
    drv = webdriver.Firefox(options=opts)
    drv.set_window_size(1100, 700)
    result['firefox'] = drv.capabilities.get('browserVersion')
    result['os'] = drv.capabilities.get('platformName')
except Exception as e:  # noqa: BLE001
    result['error'] = f'could not start Firefox: {e!r}'
    (vdir / 'firefox.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(result['error'])
    sys.exit(0)

JS_READY = """
const app = window.PDFViewerApplication || (window.wrappedJSObject && window.wrappedJSObject.PDFViewerApplication);
if (!app || !app.pdfDocument) return null;
const spans = document.querySelectorAll('.textLayer span');
return {spans: spans.length, version: (window.pdfjsLib && window.pdfjsLib.version) || app.pdfDocument._transport?.constructor?.name || null};
"""
JS_COPY = """
const layer = document.querySelector('.textLayer');
const range = document.createRange();
range.selectNodeContents(layer);
const sel = window.getSelection();
sel.removeAllRanges(); sel.addRange(range);
const selection = sel.toString();
const dt = new DataTransfer();
const ev = new ClipboardEvent('copy', {clipboardData: dt, bubbles: true, cancelable: true});
(layer.querySelector('span') || layer).dispatchEvent(ev);
return {selection, copied: dt.getData('text/plain'), handled: ev.defaultPrevented};
"""
JS_FIND = """
const app = window.PDFViewerApplication || window.wrappedJSObject.PDFViewerApplication;
const q = arguments[0];
window.__hark_count = null;
if (!window.__hark_listen) {
  app.eventBus.on('updatefindmatchescount', (e) => { window.__hark_count = e.matchesCount ? e.matchesCount.total : null; });
  app.eventBus.on('updatefindcontrolstate', (e) => { if (e.matchesCount) window.__hark_count = e.matchesCount.total; window.__hark_state = e.state; });
  window.__hark_listen = true;
}
app.eventBus.dispatch('find', {source: null, type: '', query: q, caseSensitive: false, entireWord: false,
  highlightAll: true, findPrevious: false, matchDiacritics: true});
return true;
"""
for pdf in sorted((out / 'pdf').glob('*.pdf')):
    cid = pdf.stem
    expected = (out / 'expected' / f'{cid}.txt').read_text(encoding='utf-8')
    r = {}
    try:
        drv.get(pdf.resolve().as_uri())
        ready = None
        for _ in range(60):
            try:
                ready = drv.execute_script(JS_READY)
            except Exception as e:  # noqa: BLE001
                r['ready_error'] = repr(e)[:300]
            if ready and ready['spans'] > 0:
                break
            time.sleep(0.5)
        r['opened'] = bool(ready)
        r['text_layer_spans'] = ready['spans'] if ready else 0
        result.setdefault('pdfjs_in_firefox', ready.get('version') if ready else None)
        time.sleep(0.5)
        drv.save_screenshot(str(vdir / f'firefox-{cid}.png'))
        r['screenshot'] = f'viewer/firefox-{cid}.png'
        c = drv.execute_script(JS_COPY)
        r['selection'] = c['selection']
        r['copied'] = c['copied']
        r['copy_handler_ran'] = c['handled']
        got = (c['copied'] or c['selection']).rstrip('\n')
        r['copy_exact'] = got == expected
        r['copy_codepoints'] = ' '.join(f'{ord(ch):04X}' for ch in got)
        finds = {}
        for w in [w for w in expected.split(' ') if w]:
            drv.execute_script(JS_FIND, w)
            cnt = None
            for _ in range(20):
                time.sleep(0.25)
                cnt = drv.execute_script('return window.__hark_count;')
                if cnt is not None:
                    break
            finds[w] = cnt
        r['find'] = finds
        r['find_all_words'] = all((v or 0) >= 1 for v in finds.values())
    except Exception:  # noqa: BLE001
        r['error'] = traceback.format_exc()[-800:]
    result['cases'][cid] = r
    print(cid, json.dumps({k: r.get(k) for k in ('opened', 'copy_exact', 'copy_codepoints', 'find', 'error')}, ensure_ascii=False))
drv.quit()
# Small screenshots in the job log so the run can be reviewed without the
# artifact (agent review; owner check still pending).
import base64, io
try:
    from PIL import Image
    for cid in ('c01_kitab_word', 'c02_kshetra_word', 'c03_rashtra_mixed_word'):
        p = vdir / f'firefox-{cid}.png'
        if p.exists():
            im = Image.open(p).convert('RGB')
            im.thumbnail((900, 600))
            buf = io.BytesIO()
            im.save(buf, 'PNG', optimize=True)
            print(f'FFPNGB64 {cid} {base64.b64encode(buf.getvalue()).decode()}')
except Exception as e:  # noqa: BLE001
    print('screenshot log skipped', e)
(vdir / 'firefox.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
print('firefox', result.get('firefox'), 'pdf.js in firefox', result.get('pdfjs_in_firefox'))
