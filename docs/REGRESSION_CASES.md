# Regression Cases

Known problems from the owner's earlier **All-in-One Document Reader** project (private repo, not yet reviewed by Hark – access pending) plus gaps found in this project. Each case must become an automated test where possible, otherwise a dated manual check.

Rules:
- No copyrighted books or licensed font files in git. Real samples stay on the owner's device or a private location; tests use synthetic strings or documents we generate with OFL fonts.
- A case is closed only with evidence (CI run id or dated manual check), never by code review alone.

Status: `OPEN` (no test yet) · `TEST WRITTEN` · `PASS` · `FAIL`.

| ID | Problem (old project / found here) | Source | Expected behaviour now | Test type | Feature IDs | Sub-milestone | Status |
|---|---|---|---|---|---|---|---|
| RC-001 | PDF text in **Walkman-Chanakya905** extracted as wrong letters (ASCII gibberish) | owner report | span detected as legacy Chanakya-family font; converted with its own table; raw kept; confidence shown; unknown chars flagged | unit (synthetic strings) + manual (owner PDF) | V1-LEG-01..08, V1-PDF-04 | M2b-2b | OPEN |
| RC-002 | **Kruti Dev**-type legacy text extracted as gibberish | owner report (legacy fonts) | Kruti Dev 010 table converts; i-matra and reph reordered correctly | unit (synthetic) + manual | V1-LEG-02/03 | M2b-2a | OPEN |
| RC-003 | One legacy mapping applied to a different font gave wrong output | owner requirement | table only applied to the font family it was built for; unknown legacy font → warning + OCR route | unit | V1-LEG-01/02/08 | M2b-2a | OPEN |
| RC-004 | English words and digits converted into Hindi by mistake | owner requirement | only legacy-font spans converted; Latin/Unicode spans and user-protected digits untouched | unit (mixed-font paragraph) | V1-LEG-05, V1-TRP-03 | M2b-2c | OPEN |
| RC-005 | **Word mapping** errors: words split or merged after extraction | owner report | word boundaries rebuilt from glyph gaps/coordinates; checked against source on generated PDFs | unit on generated PDFs | V1-PDF-05 | M2b-1b | OPEN |
| RC-006 | Visual order ≠ extraction order (columns, headers mixed into text) | owner report | reading-order reconstruction; headers/footers/page numbers detected and separated | unit on generated multi-column PDF | V1-PDF-02/03 | M2b-1b | OPEN |
| RC-007 | Missing or repeated characters in extracted Hindi | owner report | diagnostics count repeats/missing; low score → warning before translation | unit | V1-PDF-04/07 | M2b-1b | OPEN |
| RC-008 | PDFs without ToUnicode CMap produced unusable text | owner report (character encoding) | CMap absence detected per font; span marked unreliable; OCR route offered | unit + manual | V1-PDF-04, V1-OCR-02 | M2b-1a | PASS (detection only, generated PDFs, run 42158726040); garbled-text gate → M2b-1b; owner PDFs not tried |
| RC-009 | Character-encoding errors on import (mojibake) | owner report | detection is a suggestion; preview + user choice; original kept | unit | V1-ENC-01..05 | M2b-1c | OPEN |
| RC-010 | OCR output treated as correct | owner report (OCR) | OCR text is a separate layer with confidence; never auto-trusted | unit (interface) | V1-OCR-03, V2-OCR-09 | M2b-1a (interface) / V2 | TEST WRITTEN (interface: `validated` always false, run 42158726040); engine V2 |
| RC-011 | Hindi **rendering** problems (broken matras/conjuncts) | owner report (rendering) | §4 test strings render correctly on Android + iOS; exported PDF passes X01–X10 | golden + manual | V1-FNT-05, V1-EXP-06 | M2b-3 | OPEN |
| RC-012 | UTF-16 TXT rejected as binary | found in M2a review | BOM detection before NUL heuristic; UTF-16 LE/BE decoded | unit | V1-ENC-01 | M2b-1c | OPEN |
| RC-013 | Scanned PDF imported as "empty book" | roadmap + owner (OCR) | page status `OCR required`; no silent empty import | unit (generated image-only PDF) | V1-OCR-01, V1-IMP-03 | M2b-1a | PASS (engine level, run 42158726040); no import UI yet |
| RC-014 | Ligatures (fi, fl, Devanagari conjunct glyphs) extracted as single odd characters | owner report (PDF extraction) | ligatures decomposed to Unicode sequences; PUA flagged | unit | V1-PDF-04, EN13 | M2b-1b | OPEN |
| RC-015 | Hindi PDF export: file created but copy/search returns wrong text | owner requirement | X05–X07 checked with pdftotext in CI + viewer | CI + manual | V1-EXP-06 | M2b-3 | OPEN |

When the owner grants access to `all-in-one-document-reader-app`, review its issues/commits and add concrete cases (file types, fonts, exact wrong outputs) here.
