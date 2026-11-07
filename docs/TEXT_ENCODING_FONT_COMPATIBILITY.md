# Text, Encoding & Font Compatibility

Owner requirement of 2026-11-06 (see `OWNER_REQUESTS.md`). This file is the single reference for fonts, character encodings, legacy Hindi font conversion, OCR fallback and Hindi PDF export acceptance.

> **Status rule.** Everything below is a plan or a test matrix. Nothing here is supported until its row says `PASS` with a CI run or a dated manual check. A font name in a list is **not** support. License column values are what the upstream project publishes and **must be re-checked against the font's own license file before bundling** (D-018).

Result codes used in all matrices: `NOT TESTED` · `PASS` · `PARTIAL` (with note) · `FAIL` (with note) · `N/A`.

---

## 1. Architecture overview

Extraction, legacy conversion, OCR and translation are **separate stages**, each writing its own text layer. No stage overwrites an earlier layer (D-016).

```
Original file (immutable, SHA-256)
  └─ Extract ──────────► L0 raw text + per-char metadata (font name, coords, page, ToUnicode present?)
       └─ Diagnose ────► quality report (score, flags, per-span font class)
            ├─ Unicode OK ─────────────► L1 = L0 (NFC normalized)
            ├─ Legacy font span ───────► Legacy converter (per-font table) ► L1 converted + confidence
            ├─ Garbled / no text layer ► OCR required (V1: status + interface; V2: engine) ► L1 OCR + confidence
            └─ Unknown / low confidence ► user warning, manual correction, OCR fallback offered
       L1 ─► manual corrections ─► L2 corrected source
       L2 ─► segment/translate ──► L3 machine translation ─► L4 edited translation ─► Export
```

Text layers (stored per block, versioned – extends V1-STO-04, V1-TRP-05):

| Layer | Content | Who writes it | Editable |
|---|---|---|---|
| L0 raw | exactly what the extractor returned | parser/extractor | never |
| L1 source-unicode | NFC Unicode after legacy conversion or OCR | converter / OCR | no (re-run creates new version) |
| L2 corrected | L1 + user's manual corrections | user | yes |
| L3 translation | provider output | engine | no |
| L4 edited | user's edited translation | user | yes |

### 1.1 Font registry (V1-FNT-01)

| Source | What | Notes |
|---|---|---|
| System | Platform default Devanagari/Latin fonts (Android: Noto Sans Devanagari / Roboto; iOS: Kohinoor Devanagari / SF Pro) | Flutter cannot list system fonts; we rely on platform fallback and test it on devices. |
| Bundled | Small, license-checked set (candidates: Noto Sans/Serif Devanagari, Noto Sans/Serif, Tiro Devanagari Sanskrit) | Keeps APK small. Each bundled font needs its license file in `assets/fonts/LICENSES/` and an entry in DEPENDENCIES.md. |
| User-imported | TTF/OTF the user picks (V1-FNT-03) | Validated (magic bytes, size limit, parsable `cmap`), stored in the app sandbox only, never uploaded. User confirms they may use it. |
| Legacy (identification only) | Kruti Dev, Chanakya, DevLys… | Never used to render. Only their **names/fingerprints** key the legacy converter. |

Each font gets a `FontProfile`: family, style, source, license, script coverage computed from `cmap` (Devanagari U+0900–097F, Devanagari Extended U+A8E0–A8FF, Vedic Extensions U+1CD0–1CFF, Latin, Greek, Hebrew), OpenType `deva`/`dev2` shaping features present, `isLegacy` flag.

Fallback chain per script, e.g. Hindi body: user choice → bundled Noto Serif Devanagari → system Devanagari. Missing glyphs (tofu) are detected by checking coverage before rendering/export → warning (V1-FNT-04).

### 1.2 Detecting fonts in PDFs (V1-PDF-04, V1-LEG-01)
**Implemented in M2b-1a (run 42158726040):** `PdfStructureScanner` reports per page: `/BaseFont`, subset tag, name without tag, `/Subtype`, embedded (FontFile/FontFile2/FontFile3; Type3 = embedded), `/ToUnicode` present, `/Encoding`, and a `UnicodeMappingRisk` (low/medium/high/unknown). Technical limitations: fonts are **page-level, not per text run** (pdfrx exposes no font per run); ToUnicode **contents are not validated**; only FlateDecode streams are decoded; encrypted files → stream data not inspected; legacy names are not yet classified (M2b-2). M2b-1b (run 42164277343) adds character diagnostics (U+FFFD, control, PUA, presentation-form ligatures, duplicate glyphs, Latin-1 legacy signal) and the extraction quality gate (D-024); per-run font via FFI investigated only (D-024).

- Read font name per text run; strip subset prefix (`ABCDEF+Mangal` → `Mangal`).
- Record: embedded? subset? ToUnicode CMap present? encoding (Identity-H, WinAnsi, custom)?
- A font classed as Unicode-Devanagari but producing only Latin letters, or a known legacy name, marks the span as **legacy**.

---

## 2. Hindi font test matrix (40 families/variants)

Type: `U` = Unicode OpenType Devanagari, `L` = legacy glyph-encoded (ASCII code points drawn as Devanagari shapes).
Strategy: `B?` bundle candidate · `S` system font (test only) · `I` user-import / input-document test only · `R` regression-only (never bundled, never rendered).
Coverage abbreviations: Deva = basic Devanagari, Ext = Devanagari Extended, Ved = Vedic Extensions, Lat = Latin.

| # | Font | Type | Source | License (verify before bundling) | Coverage (to measure) | Strategy | Extraction | Rendering | Export |
|---|---|---|---|---|---|---|---|---|---|
| H01 | Noto Sans Devanagari | U | Google Noto (also Android system) | OFL-1.1 | Deva, Ext?, Lat | B? (UI) | NOT TESTED | NOT TESTED | NOT TESTED |
| H02 | Noto Serif Devanagari | U | Google Noto | OFL-1.1 | Deva, Ext? | B? (reading/export) | NOT TESTED | NOT TESTED | NOT TESTED |
| H03 | Tiro Devanagari Hindi | U | Tiro Typeworks / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H04 | Tiro Devanagari Sanskrit | U | Tiro Typeworks / Google Fonts | OFL-1.1 | Deva, Ext, Ved | B? (Sanskrit) | NOT TESTED | NOT TESTED | NOT TESTED |
| H05 | Tiro Devanagari Marathi | U | Tiro Typeworks / Google Fonts | OFL-1.1 | Deva | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H06 | Hind | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H07 | Mukta | U | Ek Type / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H08 | Poppins | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H09 | Martel | U | Dan Reynolds / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H10 | Martel Sans | U | Dan Reynolds / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H11 | Kalam | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I (handwriting) | NOT TESTED | NOT TESTED | NOT TESTED |
| H12 | Rozha One | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I (display) | NOT TESTED | NOT TESTED | NOT TESTED |
| H13 | Yatra One | U | Catherine Leigh Schmidt / Google Fonts | OFL-1.1 | Deva, Lat | I (display) | NOT TESTED | NOT TESTED | NOT TESTED |
| H14 | Laila | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H15 | Karma | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H16 | Sarala | U | Andres Torresi / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H17 | Sumana | U | Andres Torresi / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H18 | Khand | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H19 | Rajdhani | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H20 | Baloo 2 | U | Ek Type / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H21 | Biryani | U | Dan Reynolds / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H22 | Eczar | U | Rosetta / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H23 | Halant | U | Indian Type Foundry / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H24 | Palanquin | U | Pria Ravichandran / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H25 | Gotu | U | Ek Type / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H26 | Sahitya | U | Juan Pablo del Peral / Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H27 | Anek Devanagari | U | Ek Type / Google Fonts | OFL-1.1 | Deva, Lat | I (variable) | NOT TESTED | NOT TESTED | NOT TESTED |
| H28 | Akshar | U | Google Fonts | OFL-1.1 | Deva, Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H29 | Lohit Devanagari | U | Fedora / pagure | OFL-1.1 | Deva | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H30 | Annapurna SIL | U | SIL International | OFL-1.1 | Deva, Ext, Ved (to verify) | I (Sanskrit/Nepali) | NOT TESTED | NOT TESTED | NOT TESTED |
| H31 | Shobhika | U | Shobhika project (GitHub) | OFL-1.1 (verify) | Deva, Ved (Sanskrit focus) | I | NOT TESTED | NOT TESTED | NOT TESTED |
| H32 | Mangal | U | Microsoft Windows | Proprietary – not redistributable | Deva | I (very common in DOCX/PDF input) | NOT TESTED | N/A | N/A |
| H33 | Nirmala UI | U | Microsoft Windows | Proprietary – not redistributable | Deva + other Indic | I | NOT TESTED | N/A | N/A |
| H34 | Kokila | U | Microsoft Windows | Proprietary – not redistributable | Deva | I | NOT TESTED | N/A | N/A |
| H35 | Kohinoor Devanagari | U | Apple (iOS/macOS system) | Proprietary – system use only | Deva, Lat | S (iOS default) | NOT TESTED | NOT TESTED | N/A |
| H36 | Devanagari Sangam MN | U | Apple (iOS/macOS system) | Proprietary – system use only | Deva | S | NOT TESTED | NOT TESTED | N/A |
| H37 | Kruti Dev 010 | L | widely distributed, origin unclear | Unknown – never bundle | ASCII→glyph | R | NOT TESTED | N/A | N/A |
| H38 | DevLys 010 | L | widely distributed, origin unclear | Unknown – never bundle | ASCII→glyph (Kruti-like, verify) | R | NOT TESTED | N/A | N/A |
| H39 | Chanakya | L | newspaper/publishing use, origin unclear | Unknown – never bundle | ASCII→glyph (own table) | R | NOT TESTED | N/A | N/A |
| H40 | Walkman-Chanakya905 | L | seen in owner's old reader project PDFs | Unknown – never bundle | ASCII→glyph (Chanakya family, verify) | R (RC-001) | NOT TESTED | N/A | N/A |

What each result column means:
- **Extraction** – a PDF/DOCX using this font gives correct Unicode after our pipeline (direct, or via legacy converter for `L`).
- **Rendering** – Flutter renders the standard Devanagari test strings (§4) correctly on Android **and** iOS (screenshot/golden + owner check).
- **Export** – our Hindi PDF export with this font passes the §7 checklist.

## 3. English font test matrix (20 families/variants)

| # | Font | Type | Source | License (verify before bundling) | Coverage | Strategy | Extraction | Rendering | Export |
|---|---|---|---|---|---|---|---|---|---|
| E01 | Noto Sans | Latin/Greek/Cyrillic | Google Noto | OFL-1.1 | Lat, Grk, Cyr | B? (UI fallback) | NOT TESTED | NOT TESTED | NOT TESTED |
| E02 | Noto Serif | Latin/Greek/Cyrillic | Google Noto | OFL-1.1 | Lat, Grk, Cyr | B? (export) | NOT TESTED | NOT TESTED | NOT TESTED |
| E03 | Roboto | Latin | Google (Android system) | Apache-2.0 / OFL-1.1 (verify current) | Lat, Grk, Cyr | S | NOT TESTED | NOT TESTED | NOT TESTED |
| E04 | Open Sans | Latin | Google Fonts | OFL-1.1 | Lat, Grk, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E05 | Lato | Latin | Google Fonts | OFL-1.1 | Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E06 | Inter | Latin | rsms / Google Fonts | OFL-1.1 | Lat, Grk, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E07 | Source Sans 3 | Latin | Adobe | OFL-1.1 | Lat, Grk, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E08 | Source Serif 4 | Latin | Adobe | OFL-1.1 | Lat, Grk, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E09 | Merriweather | Latin | Sorkin Type / Google Fonts | OFL-1.1 | Lat, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E10 | Literata | Latin | TypeTogether / Google | OFL-1.1 | Lat, Grk, Cyr | I (e-book reading) | NOT TESTED | NOT TESTED | NOT TESTED |
| E11 | Lora | Latin | Cyreal / Google Fonts | OFL-1.1 | Lat, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E12 | EB Garamond | Latin | Google Fonts | OFL-1.1 | Lat, Grk, Cyr | I (classic books) | NOT TESTED | NOT TESTED | NOT TESTED |
| E13 | Crimson Pro | Latin | Google Fonts | OFL-1.1 | Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E14 | Libre Baskerville | Latin | Impallari / Google Fonts | OFL-1.1 | Lat | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E15 | PT Serif | Latin | ParaType / Google Fonts | OFL-1.1 (verify) | Lat, Cyr | I | NOT TESTED | NOT TESTED | NOT TESTED |
| E16 | Atkinson Hyperlegible | Latin | Braille Institute | OFL-1.1 | Lat | I (accessibility) | NOT TESTED | NOT TESTED | NOT TESTED |
| E17 | Gentium Plus | Latin/Greek/Cyrillic | SIL International | OFL-1.1 | Lat, Grk (polytonic), Cyr | B? (Greek reference words) | NOT TESTED | NOT TESTED | NOT TESTED |
| E18 | JetBrains Mono | Monospace | JetBrains | OFL-1.1 | Lat, Grk, Cyr | I (code/IDs) | NOT TESTED | NOT TESTED | NOT TESTED |
| E19 | SF Pro | Latin | Apple (iOS system) | Proprietary – system use only | Lat, Grk, Cyr | S (iOS default) | NOT TESTED | NOT TESTED | N/A |
| E20 | Times New Roman | Latin | Microsoft/Monotype | Proprietary – not redistributable | Lat, Grk, Cyr, Heb | I (very common in input) | NOT TESTED | N/A | N/A |

Hebrew and other reference scripts (V1-TRP-02) fall back to Noto Sans/Serif Hebrew etc.; those are tracked separately once needed and are not part of the 20.

## 4. Standard Devanagari test strings

Used for rendering goldens, export checks and extraction round-trips. Stored as Unicode escapes in tests so the source is unambiguous.

| ID | Checks | Sample |
|---|---|---|
| T01 | matras (all vowel signs) | का कि की कु कू कृ के कै को कौ कं कः कँ |
| T02 | i-matra reordering | कि हिंदी स्थिति |
| T03 | conjuncts | क्ष त्र ज्ञ श्र द्ध द्व ह्म ह्य ट्ट ड्ड |
| T04 | half letters / explicit halant | क्‍ष (ZWJ), क्‌ष (ZWNJ), विद्‍यालय |
| T05 | reph and rakar | धर्म कर्म प्रकाश ट्रक क्रम |
| T06 | nukta | क़ ख़ ग़ ज़ ड़ ढ़ फ़ |
| T07 | combining marks / Vedic (Sanskrit) | ॐ ऽ ॰ and U+0951/U+0952 svaras, U+1CD0 range samples |
| T08 | digits | ०१२३४५६७८९ vs 0123456789 |
| T09 | punctuation & symbols | । ॥ “ ” ‘ ’ — – … ₹ % |
| T10 | mixed paragraph | यह Gospel of John 1:1 का अध्ययन है, जहाँ “Logos” (λόγος) शब्द आता है। |
| T11 | normalization | precomposed vs decomposed nukta (क़ U+0958 vs क + ़) must compare equal after NFC policy |

## 5. Encoding cases (V1-ENC-01..05)

Detection is a **suggestion, never truth**: when confidence is low the user sees a preview and picks the encoding. A failed conversion never destroys the original bytes (L0 + original file are kept).

| # | Case | Formats | Expected behaviour | Current status |
|---|---|---|---|---|
| EN01 | UTF-8 without BOM | TXT, EPUB, DOCX | decoded | PASS (TXT M2b-1c run 42171138308; EPUB/DOCX M2a) |
| EN02 | UTF-8 with BOM | TXT, EPUB parts | BOM stripped | PASS (TXT + XML parts via decodeXmlPart, run 42171138308) |
| EN03 | UTF-16 LE with BOM | TXT | decoded | PASS – RC-012 fixed (run 42171138308) |
| EN04 | UTF-16 BE with BOM | TXT | decoded | PASS – RC-012 fixed (run 42171138308) |
| EN05 | UTF-16 without BOM | TXT | heuristic (NUL pattern) + user confirmation | PASS: byte-pattern suggestion → needsConfirmation; import only with explicit override (run 42171138308) |
| EN06 | XML declaration encoding ≠ UTF-8 (e.g. UTF-16, ISO-8859-1) | EPUB, DOCX | honour declaration or refuse clearly | PARTIAL: UTF-16 parts with BOM decoded; non-matching declaration refused (unit, run 42171138308); no zip-level fixture yet |
| EN07 | Invalid UTF-8 byte sequences | TXT | refuse with message; offer preview with replacement chars; original kept | PASS: refused with byte offset; lossy preview flagged; original bytes kept (run 42171138308) |
| EN08 | Windows-1252 / Latin-1 English text | TXT | detect as likely, ask user | NOT IMPLEMENTED |
| EN09 | ISCII or other legacy Indian encodings | TXT | detect if possible, else "unsupported encoding" | NOT IMPLEMENTED |
| EN10 | Legacy-font ASCII text pasted as TXT (Kruti Dev-typed text) | TXT, DOCX | flag "looks like legacy font text", offer converter | NOT IMPLEMENTED |
| EN11 | Unicode normalization (NFC) | all | store L0 as-is, L1 NFC; comparisons/search on NFC | PASS: UnicodeNormalizer NFC helper, nukta composition exclusions, protected spans (run 42171138308); storage layers not built |
| EN12 | Mixed Hindi-English text | all | no script loss, no reordering | PASS (M2a + all 4 encodings byte-exact, run 42171138308) |
| EN13 | Private-Use-Area (U+E000–F8FF) characters | PDF, DOCX | flag as legacy/symbol font, never pass to translation silently | NOT IMPLEMENTED |
| EN14 | ZWJ/ZWNJ preserved | all | kept in all layers | PASS: ZWJ/ZWNJ kept through decoding and NFC (run 42171138308) |

## 6. Legacy Hindi font conversion (V1-LEG-01..08)

Problem (RC-001): text drawn with legacy fonts such as Walkman-Chanakya905 or Kruti Dev is stored as ASCII/Latin code points; extraction returns gibberish like `fgUnh` for हिंदी.

Design rules:
1. **Detect** per text span: font name (subset prefix stripped) against a registry of known legacy names; plus content heuristics (Latin letters in a font flagged Devanagari, high share of characters typical for the table, e.g. `f` before consonants = pre-base i-matra in Kruti Dev).
2. **One mapping table per font family and version.** Kruti Dev 010 and Chanakya are different tables. A table is never applied to a font it was not built for. Unknown legacy font → warning + OCR fallback, no guessing.
3. **Conversion steps:** span selection → longest-match table substitution → reorder pre-base i-matra (ि) to after its consonant cluster → move reph (र्) to before its cluster → fix nukta/halant sequences → NFC.
4. **Protect** English words and digits: only spans in a detected legacy font are converted; spans in Unicode/Latin fonts are untouched. Digits inside a legacy span follow the table (some tables map digits to Devanagari digits) and are shown in diagnostics.
5. **Confidence** per span: share of mapped characters, unmapped symbols, dictionary hit rate of resulting Hindi words, impossible sequences (e.g. matra after matra). Below threshold → "uncertain" flag.
6. **Keep both**: L0 raw (gibberish) and L1 converted are stored; the user can compare, fix manually (L2), or send the page to OCR (V2).
7. **Unsupported mapping** (character not in table) → kept as-is, highlighted, counted in diagnostics; never dropped.
8. **Sourcing tables:** built by us from documented character charts and test documents the owner creates with fonts he is licensed to use. Mapping data from GPL/AGPL converters is **not** copied (D-009). Every table records its source and version.

| Legacy family | Table status | Test material | Notes |
|---|---|---|---|
| Kruti Dev 010 | NOT STARTED (M2b-2a) | synthetic ASCII strings in tests; owner-made sample PDF/DOCX kept outside git | most common legacy font |
| DevLys 010 | NOT STARTED | owner sample needed | believed close to Kruti Dev – must be verified, not assumed |
| Chanakya | NOT STARTED (M2b-2b) | owner sample needed | own table |
| Walkman-Chanakya905 | NOT STARTED (M2b-2b) | owner's old-project PDF (private) | RC-001 regression target |

## 7. OCR fallback (V1-OCR-01..04, V2-OCR-*)

V1 delivers detection and an interface, not OCR itself:
- Page has no text layer, or text layer is garbled (score below threshold, PUA-heavy, legacy font without table) → page status `OCR required`.
- `OcrEngine` interface: `recognize(pageImage, languages, region?) → OcrResult(text, boxes, confidence per word/line, engineId, engineVersion)`.
- Original page images are kept (rendered on demand from the immutable PDF, cached by page hash).
- OCR output is a separate text layer (L1-OCR) and is **never trusted without validation**: confidence flags, dictionary checks, user review (V2 editor).

V2: Hindi / English / mixed OCR, page-wise and region OCR, correction editor, confidence indicators, caching by (page hash, engine, version), searchable-PDF workflow that keeps the original.

## 8. Hindi PDF export acceptance (V1-EXP-04/06/07) – release blocker

Engine A results (M2b-3a, Session 10, run 42203433139, D-027): **FAIL for Devanagari shaping.** A visually incorrect PDF is FAIL even when extraction works. T-cases: T01 FAIL (i-matra), T02 FAIL, T03 FAIL, T04 FAIL, T05 FAIL, T06 PARTIAL (nukta unpositioned), T07 PARTIAL, T08 PASS, T09 PASS (extraction drops spaces between punctuation), T10 FAIL (Hindi part), T11 n/a (input is NFC). Greek PASS, Hebrew FAIL.

Engine B results (M2b-3b-1, Session 11, Android 14 emulator, run 42367039900, D-028), **3 cases only** (s01 `किताब`, s02 `क्षेत्र`, s03 `राष्ट्र धर्म India 123`): visual PASS 3/3; `pdftotext` FAIL 3/3 (`कताब`, `े`, `रा धम India 123`); overall PARTIAL. T01/T02 visual PASS, T03–T05 visual PASS, T08/T10 visual PASS; copy fails for all Hindi. Not a 13-case validation.

Engine C spike (M2b-3b-2a, Session 12, run 42373414737, D-029), **1 case only** (`किताब`, host-side HarfBuzz 15.0.0, Noto Serif Devanagari): qpdf ok, visual PASS (T01/T02 i-matra), `pdftotext` exact, word found; control without `/ActualText` extracts `कताब`. Copy fidelity comes from `/ActualText`, not ToUnicode. Not a full validation.

A PDF file being produced is **not** acceptance. Every engine candidate is tested with §4 strings and a 2-chapter sample on Android and iOS:

| # | Check | How | Engine A: `pdf` package | Engine B: native (Android PdfDocument / iOS UIGraphicsPDFRenderer) | Engine C: HarfBuzz-shaped glyphs + own writer with /ActualText (spike) | Engine D: HTML → PDF via platform print |
|---|---|---|---|---|---|---|
| X01 | matras correct | rendered PNG (pdftoppm in CI) + owner visual check | FAIL – i-matra not reordered (run 42203433139) | PASS (visual, 3 cases) – i-matra correct (run 42367039900) | PASS (1 case: किताब i-matra, run 42373414737) | NOT TESTED |
| X02 | conjuncts correct | same | FAIL – no conjuncts/reph (run 42203433139) | PASS (visual, 3 cases) – क्ष, त्र, ष्ट्र, reph correct (run 42367039900) | NOT TESTED | NOT TESTED |
| X03 | half letters correct | same | FAIL – no half forms, visible halant (run 42203433139) | NOT TESTED – no ZWJ half-form case in the 3-case PoC | NOT TESTED | NOT TESTED |
| X04 | Hindi + English in one paragraph | same | FAIL – Latin OK, Hindi part broken (run 42203433139) | PASS (visual) – s03 Hindi + English + digits (run 42367039900) | NOT TESTED | NOT TESTED |
| X05 | text selectable/copyable | open in viewer | PASS (CI) – text layer present, ToUnicode yes (run 42203433139) | PARTIAL – text layer present, ToUnicode yes, but Hindi glyphs drop out (run 42367039900) | PASS (CI) – text layer via /ActualText (run 42373414737) | NOT TESTED |
| X06 | copied text = original Unicode | `pdftotext` diff vs source (NFC) | PASS 11/13 – p08 spaces, p13 Hebrew order differ (run 42203433139) | FAIL 0/3 – e.g. किताब → कताब (run 42367039900) | PASS 1/1 – exact code points (run 42373414737) | NOT TESTED |
| X07 | search finds Hindi words | `pdftotext` + viewer search | PASS – all Hindi words found by pdftotext (run 42203433139) | FAIL – 0 of 4 Hindi words found by pdftotext (run 42367039900) | PASS 1/1 – word found by pdftotext | NOT TESTED |
| X08 | fonts embedded (subset OK) | `pdffonts` | PASS – all fonts emb=yes sub=yes uni=yes (run 42203433139) | PASS – embedded subsets with ToUnicode (run 42367039900) | PASS – embedded (full font, not subset), ToUnicode partial | NOT TESTED |
| X09 | line wrapping and paragraph order | visual + text order diff | PASS – wrapping/order OK, nothing outside page (run 42203433139) | PASS – single lines, nothing outside page; long wrap not tested | NOT TESTED – one word, no wrapping | NOT TESTED |
| X10 | correct on Android and iOS | device check by owner | NOT TESTED – no device check (run 42203433139) | NOT TESTED – emulator only, no device; iOS counterpart not built | NOT TESTED – host-side only | NOT TESTED |

Known risk (to be confirmed in M2b-3, not assumed): pure-Dart PDF writers usually do not apply OpenType Devanagari shaping, so i-matra order, reph and conjuncts may break. An engine that fails X01–X04 is **not production-ready**, whatever else it passes. Copy fidelity (X06) often fails even when the look is right, because ligature glyphs need correct ToUnicode/ActualText mappings – it is checked separately.

## 9. Change log of this document
- 2026-11-07: Engine C spike (1 case) results added (Session 12, D-029).
- 2026-11-07: Engine B (Android native) 3-case PoC results added (Session 11, D-028).
- 2026-11-06: created from owner requirements (Session 3 follow-up). All results `NOT TESTED` except the M2a encoding rows noted.
