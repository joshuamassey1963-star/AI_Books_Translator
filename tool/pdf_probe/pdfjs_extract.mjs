// M2b-3b-2b: text of page 1 with PDF.js (pdfjs-dist, pinned in CI).
// usage: node pdfjs_extract.mjs <pdfjs-dist dir> <out_dir> <pdf>...
// Writes <out_dir>/<id>.pdfjs.txt. Evidence only: PDF.js text content,
// not an interactive viewer search.
import fs from 'fs';
import path from 'path';
import { pathToFileURL } from 'url';

const [mod, outDir, ...pdfs] = process.argv.slice(2);
const { getDocument } = await import(
  pathToFileURL(path.join(mod, 'legacy/build/pdf.mjs')).href
);
for (const f of pdfs) {
  const doc = await getDocument({ data: new Uint8Array(fs.readFileSync(f)) }).promise;
  const page = await doc.getPage(1);
  const tc = await page.getTextContent();
  const text = tc.items.map((i) => i.str + (i.hasEOL ? '\n' : '')).join('');
  fs.writeFileSync(path.join(outDir, path.basename(f, '.pdf') + '.pdfjs.txt'), text);
}
