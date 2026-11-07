# Session ledger — AI Books Translator

**Last synced from GitHub:** 2026-11-07 (end of Session 14). Historical facts / evidence only; current state may have changed. Read [AGENTS.md](../AGENTS.md) and [PROJECT_MEMORY.md](PROJECT_MEMORY.md) first.

## Milestone and PR timeline

| Session / milestone | Result supported by GitHub evidence | Commits / CI | Remaining limitations |
| --- | --- | --- | --- |
| S1: M0 Foundation | Flutter shell, placeholders, basic navigation, initial test/CI scaffolding | CI [42146771459](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42146771459), 14 tests | Not a functioning translation app |
| S2: M1 Platform folders and CI | Android/iOS projects committed; format, analyzer, tests, debug Android/iOS unsigned builds established | CI [42149165709](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42149165709) | iOS device not tested |
| S3: M2a Parsers | TXT, EPUB, DOCX → BookDocument; ZIP/XML hardening, SHA-256 | `feature/m2-parsers`; CI [42152743112](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42152743112), 34 tests | Mostly synthetic fixtures, no production import UI |
| S4: M2b-1a | PDFium/pdfrx text source, pages/glyph coordinates, font dictionary diagnostics, OCR-needed detection, OCR interface only | PR #1 merged into `develop` as `d29b0cd`; [42158726040](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42158726040), 63 tests | Font metadata only page-level; no actual OCR; real-book tests pending |
| S5 (A–C) | Requirements-only update: system translation and read-aloud/TTS, +29 feature IDs, V1/V2/V3 staged | Docs commit `405c7fc`; `develop` CI [42163428127](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42163428127) | New modules are **planned**, not implemented |
| S5 (D): M2b-1b | Basic 2-column PDF reading order, word/paragraph boundaries, header/footer candidates, quality score/gate | PR #2 merged as `d7e9601`; [42164510713](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42164510713), 84 tests | Thresholds provisional, tables/footnotes/more columns/rotated text pending |
| S6: M2b-1c | Strict UTF-8 BOM/no BOM, UTF-16 LE/BE BOM, no-BOM suggestion/override, NFC helper; RC-012 fixed | PR #3 merged as `ca887a5`; [42171873273](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42171873273), 112 tests | EN06 ZIP-level integration partial; UI/storage not integrated |
| S7: M2b-2a | Explicit Kruti Dev 010 → Unicode converter from SIL MIT mapping, safe failure paths | PR #4 merged as `721fe4f`; [42174654507](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42174654507), 130 tests | Synthetic only, not run on real legacy PDFs; 3 ambiguous bytes intentionally unmapped |
| S8: DEV-01 | Debug-only Developer Tests UI: encoding, Kruti Dev, TXT parser diagnostics. APK artifact identification | PR #5 merged as `bb5a8cb`; [42176973417](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42176973417), 142 tests | No production reader/import/translation, device tests pending |
| S9: M-DEV-02a | User-initiated real TXT system picker inside debug diagnostics, preview and encoding options; More → build information; v0.1.1+2 | PR #6 merged as `f39b5d8`; [42202007273](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42202007273) successful; 162 tests reported before merge | `file_selector` full memory read, 200MB limit is not peak-memory guarantee; tracked [Issue #7](https://github.com/joshuamassey1963-star/AI_Books_Translator/issues/7) |
| S10: M2b-3a | **Dart PDF Engine A tested and REJECTED for Hindi shaping**, source Unicode extractable in 11/13 synthetic cases; embedded fonts+ToUnicode; evidence PDF/PNG/HarfBuzz comparisons | [PR #8](https://github.com/joshuamassey1963-star/AI_Books_Translator/pull/8) open at snapshot, head `527a3e7`; latest runs [42204479441](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42204479441) and [42204486293](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42204486293) passed. Report: 165 tests passed, 1 skipped in regular test phase; generator passed in dedicated probe | Engine B/C/D untested, visual phone checks not done, Hindi production PDF export remains blocked by shaping |
| S11: PR #9 + PR #8 merge, M2b-3b-1 | PR #9 merged `74606e6`, PR #8 merged `19f3630`. **Engine B (Android native PdfDocument) PoC: visual PASS 3/3, Unicode copy FAIL 3/3 → PARTIAL, rejected as-is (D-028)** | Develop CI [42365226139](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42365226139), [42365707590](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42365707590). Branch `feature/m2b-3b-1-shaped-pdf-poc`, run [42367039900](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42367039900): 170 passed + 1 skipped, emulator test passed, artifact `pdf-export-probe-engine-b-android` | Only 3 cases; emulator only; iOS not evaluated; owner visual check pending; PR not merged |
| S12: PR #10 merge, M2b-3b-2a | PR #10 merged `5b07941`. **Engine C spike (HarfBuzz glyphs + /ActualText, own writer): 1 case किताब — qpdf ok, visual PASS, pdftotext exact → PASS; control without /ActualText loses i-matra (D-029)** | Develop CI [42372944456](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42372944456). Branch `feature/m2b-3b-2a-actualtext-spike`, run [42373414737](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42373414737): 179 passed + 2 skipped, artifact `pdf-export-probe-engine-c-spike` | 1 case; host-side HarfBuzz; no subsetting; poppler only; owner visual check pending; PR not merged |
| S13: PR #11 merge, M2b-3b-2b | PR #11 merged `478aa01`. **Engine C C01–C03: Poppler + MuPDF exact (full + subset), qpdf ok, visual PASS (agent); subsets −93…97 %; PDFium exact only with word spans; PDF.js FAIL (D-030)** | Develop CI [42379956758](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42379956758). Branch `feature/m2b-3b-2b-engine-c-three-cases`, run [42381200825](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42381200825): 184 passed + 3 skipped, artifact `pdf-export-probe-engine-c-3cases` | Host-side only; interactive viewer search untested; PDF.js fails; owner visual check pending; PR not merged |
| S14: PR #12 merge, M2b-3b-2c-1 | PR #12 merged `96858c7`. **PDF.js 4.10.38 + 6.5.438 FAIL (ignore /ActualText); Firefox 159 viewer: render OK, Hindi copy/search FAIL; Chrome/Acrobat/Android NOT TESTED (D-031)** | Develop CI [42383903169](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42383903169). Branch `feature/m2b-3b-2c-1-pdfjs-viewers`, run [42385050495](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42385050495), artifact `pdf-export-probe-engine-c-interop` | Owner decision on PDF.js; manual viewer tests; PR not merged |

### Why the Engine A failure matters
- The `pdf` 3.13.1 probe had fonts embedded, subset and ToUnicode; that is **not enough** for Devanagari visual correctness. GSUB/GPOS positioning, i-matra, conjunct, reph/half-form shaping failed; Hebrew mark positioning also failed.
- D-027 rejects Engine A for Hindi. Do not “fix” by unverified manual Unicode reordering or present it as production ready.
- The runner's `pdf-export-probe-engine-a` artifact includes generated PDFs, expected and extracted text, images, comparisons and JSON/Markdown reports. Artifact expires according to GitHub retention; do not assume perpetual availability.

## Current task handoff (as at snapshot)
**Update, end of Session 14:** PR #12 merged. PDF.js/Firefox Hindi copy-search unsupported (D-031). Next: **M2b-3b-2c-2** after owner go.

**Update, end of Session 13:** PR #11 merged. M2b-3b-2b: 3/3 PASS on Poppler + MuPDF. Next: **M2b-3b-2c** after owner go.

**Update, end of Session 12:** PR #10 merged. M2b-3b-2a spike PASS for 1 case. Next: **M2b-3b-2b** after owner go.

**Update, end of Session 11:** PR #8 and PR #9 are merged. M2b-3b-1 is done as a PARTIAL result (Engine B shapes Hindi correctly but breaks copy/search). Next: **M2b-3b-2**, HarfBuzz-shaped glyph writer with `/ActualText`, only after owner go. The paragraphs below are the Session 10 snapshot.

**Immediate integration gate:** PR #8 is **open and mergeable** against `develop` at snapshot. Verify its current head and all latest checks, review code and licensing, then merge to `develop` only if safe and approved in the next owner-directed session. `main` must remain untouched.

**Next coding step after integration:** **M2b-3b**, select and evaluate one valid shaped export approach, either:
- a native platform PDF route that actually shapes Devanagari and exposes reliable text extraction on Android/iOS; OR
- HarfBuzz-shaped glyph placement with PDF font/glyph embedding and independently tested copy/search text mapping.

Reuse the same T01–T11 / X01–X10 and the 13 synthetic cases, render to PNG, compare to a HarfBuzz reference, test pdftotext and pdffonts, and report accurate pass/fail/partial outcomes. Do not implement production export UI, OCR, provider engines or unrelated features during this experiment. Keep artifacts as PDF/PNG/reports rather than publishing another user APK.

**Blocked or scheduled later:** Chanakya M2b-2b needs lawful real samples; M2b-2c mixed font/span confidence; M2b-3c selection; M2b-4 provider mock; M2b-5 real-book regression; M3+ storage/import/glossary/translation/editor/TTS.

## Recovery questions every successor must answer
1. What is the exact live HEAD of `develop`, and what branch does the new work use?
2. Which PRs are open or merged? What is the latest HEAD and CI for each relevant PR?
3. What *exactly* was tested in CI, and what is not device/real-book verified?
4. Is this feature already in `FEATURE_MATRIX.md`? Is its status supported by evidence?
5. What is the smallest independently mergeable next task?
6. Were implementation code/tests committed and pushed, with documentation in a separate change when appropriate?
7. Does the change require an APK for the owner? **Only if it materially changes visible UI or user functionality.**

## Update protocol
At the end of **every** future session, append a dated row to this ledger, with milestone, PR, commits, exact CI runs, pass/fail/partial evidence, and unresolved issues. Refresh only the **current-state snapshot** in PROJECT_MEMORY.md; do not rewrite older historical results as if later work had always been present. Keep secrets, personal data and private book/font samples out of GitHub.
