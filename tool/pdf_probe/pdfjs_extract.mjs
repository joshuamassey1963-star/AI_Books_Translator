// M2b-3b-2b/2c-1: text of page 1 with PDF.js (pdfjs-dist, pinned in CI).
// usage: node pdfjs_extract.mjs <pdfjs-dist dir> <out_dir> <tag> <pdf>...
// Writes <out_dir>/<id>.<tag>.txt (official getTextContent API, items joined
// with hasEOL as newline) and <out_dir>/<id>.<tag>.marked.json (the same
// call with includeMarkedContent: true, to show which marked-content data
// PDF.js hands over). Programmatic extraction only, not a viewer test.
import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';

const [mod, outDir, tag, ...pdfs] = process.argv.slice(2);
const pdfjs = await import(pathToFileURL(path.join(mod, 'legacy/build/pdf.mjs')).href);
for (const f of pdfs) {
  const doc = await pdfjs.getDocument({ data: new Uint8Array(fs.readFileSync(f)) }).promise;
  const page = await doc.getPage(1);
  const tc = await page.getTextContent();
  const text = tc.items.map((i) => i.str + (i.hasEOL ? '\n' : '')).join('');
  const id = path.basename(f, '.pdf');
  fs.writeFileSync(path.join(outDir, `${id}.${tag}.txt`), text);
  const marked = await page.getTextContent({ includeMarkedContent: true });
  fs.writeFileSync(
    path.join(outDir, `${id}.${tag}.marked.json`),
    JSON.stringify(marked.items.map((i) => (i.type ? i : { str: i.str })), null, 1),
  );
  await doc.destroy();
}
fs.writeFileSync(path.join(outDir, `PDFJS_VERSION_${tag}`), `pdfjs-dist ${pdfjs.version}`);
