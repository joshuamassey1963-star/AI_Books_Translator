# Feature Matrix

Source: *AI Book Translator Roadmap V1–V3* (03 Nov 2026) plus the project brief. Statuses: `PLANNED`, `IN PROGRESS`, `IMPLEMENTED`, `VERIFIED`, `BLOCKED`. **IMPLEMENTED ≠ VERIFIED**: VERIFIED needs passing automated tests, and real-device checks where the roadmap asks for them.

Totals: 187 features — IMPLEMENTED: 0, IN PROGRESS: 30, PLANNED: 153, VERIFIED: 4

Priority: P0 = release blocker, P1 = important, P2 = nice-to-have, P3 = optional.

| ID | Version | Module | Feature | Priority | Dependency | Status | Tests |
|---|---|---|---|---|---|---|---|
| V1-NAV-01 | V1 | App Shell | Bottom navigation (Home, Library, Translate, Tasks, More) with per-tab stacks | P0 | - | VERIFIED | CI run 42146771459: widget tests pass |
| V1-NAV-02 | V1 | App Shell | Honest Planned/Not-available placeholders for every screen; no dead buttons | P0 | V1-NAV-01 | VERIFIED | CI run 42146771459: unit + widget tests pass |
| V1-NAV-03 | V1 | App Shell | Home: new project, ongoing work, recent translations, status | P1 | V1-LIB-01 | IN PROGRESS | widget (empty state only) |
| V1-NAV-04 | V1 | App Shell | Deep links + project state restore (go_router) | P2 | V1-STO-01 | PLANNED | - |
| V1-NAV-05 | V1 | App Shell | Tablet two-pane workspace layout | P2 | V1-EDT-01 | PLANNED | - |
| V1-STO-01 | V1 | Storage | Drift/SQLite schema: books, chapters, segments, jobs, glossary | P0 | - | PLANNED | - |
| V1-STO-02 | V1 | Storage | Schema migrations with migration tests | P0 | V1-STO-01 | PLANNED | - |
| V1-STO-03 | V1 | Storage | FTS search over source/translation | P2 | V1-STO-01 | PLANNED | - |
| V1-STO-04 | V1 | Storage | Original file immutable; translations/edits/exports saved as separate versions (layers L0–L4, V1-TRP-05) | P0 | V1-STO-01 | PLANNED | - |
| V1-LIB-01 | V1 | Library | Bookshelf list of local projects | P0 | V1-STO-01 | PLANNED | - |
| V1-LIB-02 | V1 | Library | Book details: metadata, chapter navigator, search | P1 | V1-IMP-04 | PLANNED | - |
| V1-IMP-01 | V1 | Import | EPUB import (first priority format) | P0 | V1-STO-01 | IN PROGRESS | spike (M2a): parser + unit tests in CI run 42152743112; no UI/storage yet |
| V1-IMP-02 | V1 | Import | TXT and DOCX import (TXT UTF-8 + UTF-16 BOM since M2b-1c) | P0 | V1-STO-01 | IN PROGRESS | spike (M2a): parser + unit tests in CI run 42152743112; no UI/storage yet |
| V1-IMP-03 | V1 | Import | Text-layer PDF import; detect scanned PDF and show 'OCR required' (split into V1-PDF-01..07, V1-OCR-01..04) | P0 | V1-STO-01 | IN PROGRESS | engine only (M2b-1a), run 42158726040; no import UI |
| V1-IMP-04 | V1 | Import | Structure model: chapter/heading/paragraph, footnotes, images, tables, inline emphasis, reading order | P0 | V1-IMP-01 | IN PROGRESS | spike: chapter/heading/paragraph only; footnotes/tables/images pending |
| V1-IMP-05 | V1 | Import | Real file-type check (magic bytes), size/storage limits, corrupt-file recovery | P0 | V1-IMP-01 | IN PROGRESS | magic-byte sniffing + size limit tested; corrupt-file recovery pending |
| V1-IMP-06 | V1 | Import | SHA-256 fingerprint, project snapshot, import diagnostics, duplicate detection | P1 | V1-IMP-01 | IN PROGRESS | SHA-256 fingerprint tested; snapshot/duplicate detection pending |
| V1-IMP-07 | V1 | Import | Chapter detection and chapter tree | P0 | V1-IMP-04 | IN PROGRESS | TXT/DOCX heading rules + EPUB spine chapters tested |
| V1-ENG-01 | V1 | Engine | Pipeline: Parse→Normalize→Segment→Context/Glossary→Translate→Validate→Save→Review→Export | P0 | V1-IMP-04 | PLANNED | - |
| V1-ENG-02 | V1 | Engine | Token-budget chunking respecting chapter bounds, paragraph IDs, quotes, footnotes, tags | P0 | V1-ENG-01 | PLANNED | - |
| V1-ENG-03 | V1 | Engine | Controlled concurrency (start 1-3 workers), cancellation | P0 | V1-ENG-01 | PLANNED | - |
| V1-ENG-04 | V1 | Engine | 429 handling: exponential backoff + jitter; idempotent retry | P0 | V1-AIP-01 | PLANNED | - |
| V1-ENG-05 | V1 | Engine | SQLite checkpoints per chunk: input hash, model, prompt, glossary version, result, review state | P0 | V1-STO-01 | PLANNED | - |
| V1-ENG-06 | V1 | Engine | Translation cache/memory: no repeat API call for same text+settings; invalidate on glossary change | P0 | V1-ENG-05 | PLANNED | - |
| V1-ENG-07 | V1 | Engine | Structural validator: no skipped paragraph, order preserved, missing sections detected (+ alignment V1-TRP-01) | P0 | V1-ENG-01 | PLANNED | - |
| V1-ENG-08 | V1 | Engine | Book-level style guide + character/name register; bounded previous-chapter context | P1 | V1-ENG-01 | PLANNED | - |
| V1-ENG-09 | V1 | Engine | Language-pair abstraction (EN→HI first, others later) | P1 | V1-ENG-01 | PLANNED | - |
| V1-AIP-01 | V1 | AI Providers | Provider adapter interface: Gemini, OpenAI-compatible, OpenRouter, Ollama (self-hosted) | P0 | - | PLANNED | - |
| V1-AIP-02 | V1 | AI Providers | Add/remove API key (secure storage), custom base URL, model ID (no hardcoded models/prices) | P0 | V1-SEC-01 | PLANNED | - |
| V1-AIP-03 | V1 | AI Providers | Connection test and model availability check | P0 | V1-AIP-01 | PLANNED | - |
| V1-AIP-04 | V1 | AI Providers | Distinct error codes: 401, 403, 429, timeout, quota, network loss, model unavailable | P0 | V1-AIP-01 | PLANNED | - |
| V1-AIP-05 | V1 | AI Providers | Provider switching; user-approved fallback only; never auto-switch to paid | P0 | V1-AIP-01 | PLANNED | - |
| V1-AIP-06 | V1 | AI Providers | Free-only mode and cost ceiling | P1 | V1-AIP-05 | PLANNED | - |
| V1-AIP-07 | V1 | AI Providers | Usage monitoring; cost estimate where reliable data exists | P2 | V1-AIP-01 | PLANNED | - |
| V1-AIP-08 | V1 | AI Providers | Health check, circuit breaker, offline queue | P1 | V1-AIP-01 | PLANNED | - |
| V1-GLO-01 | V1 | Dictionary | Add/edit/delete terms; exact translation, aliases | P0 | V1-STO-01 | PLANNED | - |
| V1-GLO-02 | V1 | Dictionary | Case sensitivity, exact match, phrase priority, protected terms/names | P0 | V1-GLO-01 | PLANNED | - |
| V1-GLO-03 | V1 | Dictionary | Context notes / context-based rules (e.g. 'Spirit') | P1 | V1-GLO-01 | PLANNED | - |
| V1-GLO-04 | V1 | Dictionary | CSV/JSON import & export | P1 | V1-GLO-01 | PLANNED | - |
| V1-GLO-05 | V1 | Dictionary | Conflict detection | P0 | V1-GLO-01 | PLANNED | - |
| V1-GLO-06 | V1 | Dictionary | Project-specific and reusable global dictionaries | P1 | V1-GLO-01 | PLANNED | - |
| V1-GLO-07 | V1 | Dictionary | Glossary in prompt + terminology validator on output; highlight violations + correction workflow (no blind replace) | P0 | V1-ENG-01 | PLANNED | - |
| V1-INS-01 | V1 | Instructions | Custom instructions: style (literary/simple/formal), honorifics, grammar, sentence structure | P0 | V1-STO-01 | PLANNED | - |
| V1-INS-02 | V1 | Instructions | Formatting and do-not-translate rules | P1 | V1-INS-01 | PLANNED | - |
| V1-EDT-01 | V1 | Editor | Two-pane source/translation editor with paragraph alignment | P0 | V1-ENG-05 | PLANNED | - |
| V1-EDT-02 | V1 | Editor | Undo/redo, search/replace, autosave | P0 | V1-EDT-01 | PLANNED | - |
| V1-EDT-03 | V1 | Editor | Review status and manual lock per segment | P1 | V1-EDT-01 | PLANNED | - |
| V1-TSK-01 | V1 | Tasks | Task queue states: Pending/Running/Paused/Failed/Completed (also snippet jobs from V1-STR-01; background execution = V1-STR-02) | P0 | V1-ENG-05 | PLANNED | - |
| V1-TSK-02 | V1 | Tasks | Chunk progress, estimated tokens (cost when available) | P1 | V1-TSK-01 | PLANNED | - |
| V1-TSK-03 | V1 | Tasks | Pause/resume/retry; retry failed chunks only | P0 | V1-TSK-01 | PLANNED | - |
| V1-TSK-04 | V1 | Tasks | Resume from checkpoint after force-close/restart without duplicate billing | P0 | V1-ENG-05 | PLANNED | - |
| V1-TSK-05 | V1 | Tasks | Android WorkManager / foreground service where allowed; iOS BGTask version-aware, no guaranteed background | P1 | V1-TSK-01 | PLANNED | - |
| V1-EXP-01 | V1 | Export | TXT export | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-02 | V1 | Export | DOCX export (preserve formatting where possible) | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-03 | V1 | Export | EPUB export (metadata, TOC, chapter order, tag validation) | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-04 | V1 | Export | Unicode Hindi PDF with font embedding (Devanagari ligatures, matras, copy/search) (acceptance V1-EXP-06; not production-ready until shaping verified) | P0 | V1-ENG-01 | PLANNED | M2b-3a: Engine A (Dart pdf) FAILS shaping (run 42203433139). M2b-3b-1: Engine B (Android native) shapes correctly but loses Unicode on copy (run 42367039900, D-028). M2b-3b-2c-3: PDF.js candidate word-1:1 ToUnicode PASS (limited, D-033). M2b-3b-2c-2: + C04 ZWJ, C05 ZWNJ, C06 composite EXACT on Poppler/MuPDF/PDFium (word spans, D-032). M2b-3b-2b/2c-1: Engine C passes C01–C03 on Poppler+MuPDF+PDFium (word spans); PDF.js 4/6 and Firefox viewer FAIL for Hindi copy/search; Chrome/Acrobat/Android not tested (D-030, D-031, run 42385050495). No production engine yet |
| V1-EXP-05 | V1 | Export | Hindi-only and bilingual output; Unicode normalization; pre-export validation | P1 | V1-EXP-01 | PLANNED | - |
| V1-SEC-01 | V1 | Security | API keys in Android Keystore / iOS Keychain; never in code, logs, git | P0 | - | PLANNED | - |
| V1-SEC-02 | V1 | Security | Import hardening: path traversal, ZIP bomb, XXE, malformed XML, oversized images, unsafe HTML (+ image safety V1-IMG-05) | P0 | V1-IMP-01 | IN PROGRESS | path traversal, zip bomb ratio/size/count, XXE/entities, malformed XML tested; oversized images + unsafe HTML pending |
| V1-SEC-03 | V1 | Security | Explicit consent + privacy notice before sending text to a cloud provider | P0 | V1-AIP-01 | PLANNED | - |
| V1-SEC-04 | V1 | Security | No book text, keys or PII in logs; telemetry opt-in only | P0 | - | PLANNED | - |
| V1-SEC-05 | V1 | Security | Minimal platform permissions (SAF / document picker, sandbox copies) | P0 | - | PLANNED | - |
| V1-SEC-06 | V1 | Security | License inventory (SPDX/SBOM) and dependency scanning in CI | P1 | V1-CI-01 | PLANNED | - |
| V1-SET-01 | V1 | Settings | Settings: privacy, consent, storage, theme | P1 | V1-STO-01 | PLANNED | - |
| V1-SET-02 | V1 | Settings | Appearance: Day / Night / Sepia modes for app, reader and editor (+ follow system) – owner request 2026-11-06 | P1 | V1-SET-01 | PLANNED | - |
| V1-SET-03 | V1 | Settings | Screen rotation: Auto / Portrait lock / Landscape lock; two-pane editor in landscape – owner request 2026-11-06 | P2 | V1-SET-01 | PLANNED | - |
| V1-HIS-01 | V1 | History | Local work history timeline: imports, translation jobs, edits, exports (works offline, no account) – owner request 2026-11-06 | P1 | V1-STO-01 | PLANNED | - |
| V1-ERR-01 | V1 | Reliability | Error handling + help/diagnostics screen with error codes | P0 | V1-AIP-04 | PLANNED | - |
| V1-ERR-02 | V1 | Reliability | Airplane mode / network flapping / storage full / low RAM without data loss | P0 | V1-ENG-05 | PLANNED | - |
| V1-OFF-01 | V1 | Offline | Local library and editor work without internet; no mandatory account | P0 | V1-STO-01 | PLANNED | - |
| V1-PRF-01 | V1 | Performance | Performance baseline: startup, import latency (10MB EPUB), memory, 60fps scroll | P1 | V1-IMP-01 | PLANNED | - |
| V1-PRF-02 | V1 | Performance | Isolates for heavy parsing; lazy loading/virtualized chapters; streaming export | P1 | V1-IMP-01 | PLANNED | - |
| V1-CI-01 | V1 | QA/CI | GitHub Actions: analyze + unit/widget tests | P0 | - | VERIFIED | CI run 42146771459 green (analyze: no issues, 14/14 tests) |
| V1-CI-02 | V1 | QA/CI | Android debug APK build in CI | P0 | V1-CI-01 | VERIFIED | CI run 42146771459: debug APK built + uploaded |
| V1-DEV-01 | V1 | QA/Dev | Developer Tests screen (debug builds only): text encoding inspection, Kruti Dev 010 conversion, TXT parser diagnostics on synthetic input; file picker + PDF diagnostics not included | P2 | V1-ENC-01, V1-LEG-03 | IN PROGRESS | merged PR #5 (bb5a8cb); run 42176973417 |
| V1-DEV-02 | V1 | QA/Dev | Developer Tests: real TXT file via system picker (no storage permission), size limit before read, encoding choice for BOM-less UTF-16, metadata + bounded preview + copy; About this build in More (version, build, type, CI-injected commit SHA) | P2 | V1-DEV-01, V1-IMP-01 | IN PROGRESS | merged PR #6 (f39b5d8); run 42184277563; owner reported the earlier APK works; not re-checked on a phone for 0.1.1+2 |
| V1-DEV-03 | V1 | QA/Dev | Bounded/streaming file reading for the file picker (peak memory not limited by the 200 MB size check) – PR #6 review | P1 | V1-DEV-02 | PLANNED | GitHub issue #7 |
| V1-CI-03 | V1 | QA/CI | iOS build on macOS runner; release builds with SHA-256 artifacts | P1 | V1-CI-01 | IN PROGRESS | iOS debug no-codesign build green (run 42149165709); release builds + SHA-256 pending |
| V1-CI-04 | V1 | QA/CI | Integration tests on emulator | P1 | V1-CI-01 | PLANNED | integration_test/app_launch_test (written, not run) |
| V1-REL-01 | V1 | Release | Acceptance: 3 EPUBs keep chapter order + paragraph count; force-close resume; Devanagari checks on Android+iOS | P0 | all V1 | PLANNED | - |
| V1-REL-02 | V1 | Release | Accessibility, store compliance, copyright notice (only rights-cleared content) | P1 | all V1 | PLANNED | - |
| V1-IMG-01 | V1 | Images | App logo and branding (adaptive icon Android, iOS icon set, splash) – owner req 2026-11-06 | P1 | - | PLANNED | - |
| V1-IMG-02 | V1 | Images | App background/wallpaper image (optional) – owner req 2026-11-06 | P2 | V1-IMG-05, V1-SET-02 | PLANNED | - |
| V1-IMG-03 | V1 | Images | Book cover: extract from EPUB/DOCX/PDF, upload, replace, remove (original file untouched) – owner req 2026-11-06 | P1 | V1-IMG-05, V1-IMP-01 | PLANNED | - |
| V1-IMG-04 | V1 | Images | Reader/editor custom background image with text-contrast guard – owner req 2026-11-06 | P2 | V1-IMG-05, V1-SET-02 | PLANNED | - |
| V1-IMG-05 | V1 | Images | Image pipeline: fit (cover/contain/fill), opacity, dim, reset, thumbnail cache, Day/Night/Sepia compatibility, safe decoding (pixel/size limits, re-encode, EXIF/GPS strip, no SVG execution) – owner req 2026-11-06 | P1 | V1-SEC-02 | PLANNED | - |
| V1-FNT-01 | V1 | Fonts | Font registry: system / bundled / user-imported sources, FontProfile (coverage from cmap, shaping features, legacy flag), per-script fallback chain – owner req 2026-11-06 | P0 | - | PLANNED | - |
| V1-FNT-02 | V1 | Fonts | Small license-checked bundled set (candidates Noto Sans/Serif Devanagari, Noto Sans/Serif, Tiro Devanagari Sanskrit); license files shipped – owner req 2026-11-06 | P0 | V1-FNT-01, V1-SEC-06 | PLANNED | - |
| V1-FNT-03 | V1 | Fonts | User font import (TTF/OTF validation, size limit, sandbox only, user licence confirmation) – owner req 2026-11-06 | P2 | V1-FNT-01 | PLANNED | - |
| V1-FNT-04 | V1 | Fonts | Missing-glyph/missing-font detection with clear warning and fallback – owner req 2026-11-06 | P1 | V1-FNT-01 | PLANNED | - |
| V1-FNT-05 | V1 | Fonts | Font test matrix: 40 Hindi + 20 English families/variants (extraction, rendering, export results) – owner req 2026-11-06 | P1 | V1-FNT-01, V1-PDF-01, V1-EXP-06 | PLANNED | - |
| V1-FNT-06 | V1 | Fonts | Mixed Hindi-English and Sanskrit/Vedic Devanagari coverage; correct matras, conjuncts, half letters, combining marks, digits, punctuation – owner req 2026-11-06 | P1 | V1-FNT-01 | PLANNED | - |
| V1-LEG-01 | V1 | Legacy Fonts | Legacy Hindi font detection per span (font name w/o subset prefix + content heuristics) – owner req 2026-11-06 | P0 | V1-PDF-01 | PLANNED | - |
| V1-LEG-02 | V1 | Legacy Fonts | Font-specific mapping tables (Kruti Dev 010 first, Chanakya family separate); never applied to another font – owner req 2026-11-06 | P0 | V1-LEG-01 | IN PROGRESS | Kruti Dev 010 only (SIL map port), confirmed-font registry – run 42174654507; Chanakya = M2b-2b |
| V1-LEG-03 | V1 | Legacy Fonts | Unicode conversion engine: substitution, i-matra and reph reordering, nukta/halant fixes, NFC – owner req 2026-11-06 | P0 | V1-LEG-02 | IN PROGRESS | substitution + ikar/reph/nasal reordering + NFC, synthetic strings – run 42174654507; no real-book check |
| V1-LEG-04 | V1 | Legacy Fonts | Conversion confidence score and diagnostics per span – owner req 2026-11-06 | P1 | V1-LEG-03 | IN PROGRESS | warnings only (unmapped, outside code page, stray ikar); no confidence score yet – run 42174654507 |
| V1-LEG-05 | V1 | Legacy Fonts | Mixed-font paragraphs: convert only legacy spans; English words and digits protected – owner req 2026-11-06 | P0 | V1-LEG-03 | PLANNED | - |
| V1-LEG-06 | V1 | Legacy Fonts | Raw (L0) and converted (L1) text stored separately – owner req 2026-11-06 | P0 | V1-TRP-05 | PLANNED | - |
| V1-LEG-07 | V1 | Legacy Fonts | Manual correction of wrong conversions (L2 layer) – owner req 2026-11-06 | P1 | V1-LEG-06, V1-EDT-01 | PLANNED | - |
| V1-LEG-08 | V1 | Legacy Fonts | Unsupported-mapping warning + OCR fallback route for uncertain text – owner req 2026-11-06 | P1 | V1-LEG-04, V1-OCR-03 | PLANNED | - |
| V1-PDF-01 | V1 | PDF Extraction | PdfTextSource interface + engine adapter (candidate pdfrx/PDFium): text runs with page, coordinates, font metadata; original PDF untouched – owner req 2026-11-06 | P0 | V1-IMP-05 | IN PROGRESS | pdfrx_text_source_test (7) – run 42158726040 |
| V1-PDF-02 | V1 | PDF Extraction | Reading order: multi-column layouts and tables detection – owner req 2026-11-06 | P1 | V1-PDF-01 | IN PROGRESS | two-column order only (no tables) – layout tests, run 42164277343 |
| V1-PDF-03 | V1 | PDF Extraction | Header/footer/page-number detection and separation – owner req 2026-11-06 | P1 | V1-PDF-01 | IN PROGRESS | candidates detected, not separated in UI – run 42164277343 |
| V1-PDF-04 | V1 | PDF Extraction | Font/Unicode diagnostics: ToUnicode CMap availability, embedded/subset fonts, missing/repeated chars, ligature decomposition, PUA detection – owner req 2026-11-06 | P0 | V1-PDF-01 | IN PROGRESS | pdf_structure_scanner_test font group (7) – run 42158726040 |
| V1-PDF-05 | V1 | PDF Extraction | Word and paragraph boundary reconstruction from glyph positions – owner req 2026-11-06 | P0 | V1-PDF-01 | IN PROGRESS | pdf_layout_analyzer_test – run 42164277343 |
| V1-PDF-06 | V1 | PDF Extraction | Footnotes and references detection – owner req 2026-11-06 | P2 | V1-PDF-02 | PLANNED | - |
| V1-PDF-07 | V1 | PDF Extraction | Extraction quality gate before translation: score, per-page flags, clear warning when unreliable – owner req 2026-11-06 | P0 | V1-PDF-04, V1-PDF-05 | IN PROGRESS | pdf_quality_test (score + gate, thresholds untuned) – run 42164277343 |
| V1-ENC-01 | V1 | Encoding | TXT: UTF-8, UTF-8 BOM, UTF-16 LE/BE (BOM + heuristic) – owner req 2026-11-06 | P0 | V1-IMP-02 | IN PROGRESS | EncodingDetector + TxtParser, text_encoding_test – run 42171138308; no UI |
| V1-ENC-02 | V1 | Encoding | Unicode normalization policy (L0 as-is, L1+ NFC; search/compare on NFC) – owner req 2026-11-06 | P0 | V1-TRP-05 | IN PROGRESS | UnicodeNormalizer (NFC, protected spans) – run 42171138308; not yet applied by a storage layer |
| V1-ENC-03 | V1 | Encoding | Invalid bytes: no data loss, encoding preview and user choice when detection is uncertain – owner req 2026-11-06 | P1 | V1-ENC-01 | IN PROGRESS | refuse with offset + lossy preview + override API – run 42171138308; no UI |
| V1-ENC-04 | V1 | Encoding | Legacy/8-bit encoding detection (Windows-1252, ISCII, legacy-font ASCII text) with clear unsupported-encoding errors – owner req 2026-11-06 | P2 | V1-ENC-01, V1-LEG-01 | PLANNED | - |
| V1-ENC-05 | V1 | Encoding | Per-format encoding tests: TXT, EPUB (XML declarations), DOCX, PDF – owner req 2026-11-06 | P1 | V1-ENC-01 | IN PROGRESS | TXT + EPUB/DOCX XML-declaration check (EN06) – run 42171138308; PDF via M2b-1a/b |
| V1-OCR-01 | V1 | OCR (detection) | Scanned PDF / missing text layer detection per page – owner req 2026-11-06 | P0 | V1-PDF-01 | IN PROGRESS | scanner + pdfrx RC-013 tests – run 42158726040 |
| V1-OCR-02 | V1 | OCR (detection) | Garbled-text detection (low score, PUA-heavy, unknown legacy font) – owner req 2026-11-06 | P0 | V1-PDF-04 | IN PROGRESS | PUA/FFFD/control/Latin-1 signals – run 42164277343; legacy detection M2b-2 |
| V1-OCR-03 | V1 | OCR (detection) | 'OCR required' page status + OcrEngine interface (no engine in V1) – owner req 2026-11-06 | P1 | V1-OCR-01 | IN PROGRESS | ocr_engine_test (2) + classifyPage tests – run 42158726040 |
| V1-OCR-04 | V1 | OCR (detection) | Original page image preservation (render on demand, cache by page hash) – owner req 2026-11-06 | P1 | V1-PDF-01 | PLANNED | - |
| V1-EXP-06 | V1 | Export | Hindi PDF acceptance checklist X01–X10 (matras, conjuncts, half letters, mixed text, select/copy, Unicode copy, search, embedding, wrapping, Android+iOS) – owner req 2026-11-06 | P0 | V1-EXP-04, V1-FNT-02 | IN PROGRESS | Engine A (run 42203433139): X01–X04 fail, X05–X09 pass. Engine B 3-case PoC (run 42367039900): X01–X04 pass visually, X06–X07 fail; X10 not tested |
| V1-EXP-07 | V1 | Export | Alternative PDF engine prototypes and comparison (pdf pkg, native platform, HarfBuzz-shaped, HTML print) – owner req 2026-11-06 | P0 | V1-EXP-06 | IN PROGRESS | Engine A probe (run 42203433139); Engine B Android native 3-case PoC (run 42367039900, D-028); Engine C spike (HarfBuzz + /ActualText, host-side, 3 cases, run 42381200825); D not built; iOS not evaluated |
| V1-TRP-01 | V1 | Text Protection | Paragraph alignment source↔translation by block id – owner req 2026-11-06 | P0 | V1-ENG-07 | PLANNED | - |
| V1-TRP-02 | V1 | Text Protection | Protect reference words in other scripts (English, Greek, Hebrew, …) via placeholders + validation – owner req 2026-11-06 | P0 | V1-ENG-02, V1-GLO-02 | PLANNED | - |
| V1-TRP-03 | V1 | Text Protection | Digit policy: user-selected English (ASCII) or Devanagari digits, validated on output – owner req 2026-11-06 | P0 | V1-INS-01 | PLANNED | - |
| V1-TRP-04 | V1 | Text Protection | Explained terms keep original script next to the Hindi (e.g. “Logos (λόγος)”) – owner req 2026-11-06 | P1 | V1-TRP-02 | PLANNED | - |
| V1-TRP-05 | V1 | Text Protection | Versioned text layers: raw L0 → converted/OCR L1 → corrected L2 → translation L3 → edited L4 – owner req 2026-11-06 | P0 | V1-STO-04 | PLANNED | - |
| V2-OCR-01 | V2 | OCR | OCR for scanned PDF/images: ML Kit (Android), Vision (iOS); Hindi/English accuracy comparison (+ mixed V2-OCR-05, validation V2-OCR-09) | P0 | V1-IMP-03 | PLANNED | - |
| V2-OCR-02 | V2 | OCR | Optional server OCR (Tesseract/PaddleOCR) with consent and cost shown | P2 | V2-OCR-01 | PLANNED | - |
| V2-OCR-03 | V2 | OCR | OCR correction editor: page image + text, confidence flags, page-wise fixes, searchable output (+ region V2-OCR-06, cache V2-OCR-07, searchable V2-OCR-08) | P1 | V2-OCR-01 | PLANNED | - |
| V2-OCR-04 | V2 | OCR | Best-effort reconstruction of tables, columns, footnotes, equations, captions; flag low confidence | P2 | V2-OCR-01 | PLANNED | - |
| V2-QA-01 | V2 | Quality | Two-pass translation: draft → reviewer/verifier → human approval (optional) | P1 | V1-ENG-01 | PLANNED | - |
| V2-QA-02 | V2 | Quality | Auto checks: missing/added paragraphs, numbers, citations/verse numbers, names, protected tokens, tag integrity | P0 | V1-ENG-07 | PLANNED | - |
| V2-QA-03 | V2 | Quality | Translation memory: fuzzy match, approved segments, book-specific + global | P1 | V1-ENG-06 | PLANNED | - |
| V2-QA-04 | V2 | Quality | Glossary suggestions with approve/reject and conflict review | P2 | V1-GLO-05 | PLANNED | - |
| V2-QA-05 | V2 | Quality | Comparison Original/AI draft/Edited final; audit trail with model provenance | P1 | V1-EDT-01 | PLANNED | - |
| V2-QA-06 | V2 | Quality | Quality reports (omission rate, glossary violations, broken tags) | P1 | V2-QA-02 | PLANNED | - |
| V2-RDR-01 | V2 | Reader | Bilingual EPUB reader: toggle, paragraph sync, bookmarks, notes, search | P1 | V1-EXP-03 | PLANNED | - |
| V2-BAT-01 | V2 | Batch | Batch projects: multi-file import, priority queue, pause all, selective re-translate, chapter export | P1 | V1-TSK-01 | PLANNED | - |
| V2-PRD-01 | V2 | Productivity | Style presets, prompt templates, model comparison on sample chapter, cost before full book | P2 | V1-AIP-01 | PLANNED | - |
| V2-PRD-02 | V2 | Productivity | DOCX formatting improvements, rich-text editor, keyboard shortcuts, tablet, dynamic font sizes | P2 | V1-EDT-01 | PLANNED | - |
| V2-FMT-01 | V2 | Formatting | Formatting preservation improvements across EPUB/DOCX | P1 | V1-EXP-02 | PLANNED | - |
| V2-IMG-01 | V2 | Images | Local profile picture without login – owner req 2026-11-06 | P2 | V1-IMG-05 | PLANNED | - |
| V2-OCR-05 | V2 | OCR | Mixed Hindi-English OCR with per-line script detection – owner req 2026-11-06 | P1 | V2-OCR-01 | PLANNED | - |
| V2-OCR-06 | V2 | OCR | Selective region OCR – owner req 2026-11-06 | P2 | V2-OCR-01 | PLANNED | - |
| V2-OCR-07 | V2 | OCR | OCR result caching by page hash + engine version – owner req 2026-11-06 | P1 | V2-OCR-01 | PLANNED | - |
| V2-OCR-08 | V2 | OCR | Searchable PDF workflow (text layer over page image, original kept) – owner req 2026-11-06 | P2 | V2-OCR-01, V1-EXP-06 | PLANNED | - |
| V2-OCR-09 | V2 | OCR | OCR validation: confidence + dictionary checks, never auto-trusted – owner req 2026-11-06 | P1 | V2-OCR-01 | PLANNED | - |
| V3-LLM-01 | V3 | Offline AI | Optional on-device LLM (llama.cpp / MLX) only on capable devices after benchmark | P1 | V1-AIP-01 | PLANNED | - |
| V3-LLM-02 | V3 | Offline AI | Model manager: size, RAM, heat, battery, quality gating; thermal throttling | P1 | V3-LLM-01 | PLANNED | - |
| V3-SYN-01 | V3 | Sync | Optional account + encrypted cloud sync, offline-first | P2 | V1-STO-01 | PLANNED | - |
| V3-SYN-02 | V3 | Sync | Cross-device progress, project export/import, conflict resolution | P2 | V3-SYN-01 | PLANNED | - |
| V3-SYN-03 | V3 | Sync | Optional login that syncs work history and projects across devices – owner request 2026-11-06 | P2 | V3-SYN-01, V1-HIS-01 | PLANNED | - |
| V3-SRV-01 | V3 | Cloud Engine | Optional remote durable jobs (FastAPI/Go/Rust workers, queue, object storage) | P2 | V1-ENG-01 | PLANNED | - |
| V3-TEAM-01 | V3 | Team | Editor roles, comment threads, approval workflow, revision history | P2 | V3-SYN-01 | PLANNED | - |
| V3-PUB-01 | V3 | Publishing | Professional publishing presets | P2 | V1-EXP-03 | PLANNED | - |
| V3-QA-01 | V3 | Advanced QA | Terminology knowledge base, multi-book consistency, chapter context retrieval | P2 | V2-QA-03 | PLANNED | - |
| V3-QA-02 | V3 | Advanced QA | QA dashboard and translation evaluation corpus | P2 | V2-QA-06 | PLANNED | - |
| V3-WSP-01 | V3 | Workspace | Advanced workspace; optional desktop/web companion or self-hosted server (never mandatory) | P3 | V3-SRV-01 | PLANNED | - |
| V3-PRF-01 | V3 | Performance | Performance optimization from recorded baselines | P2 | V1-PRF-01 | PLANNED | - |
| V3-IMG-01 | V3 | Images | Optional account profile picture sync – owner req 2026-11-06 | P2 | V3-SYN-01, V2-IMG-01 | PLANNED | - |
| V3-IMG-02 | V3 | Images | Alternate app icons where the platform supports it (Android activity-alias, iOS setAlternateIconName; bundled icons only) – owner req 2026-11-06 | P3 | V1-IMG-01 | PLANNED | - |
| V1-STR-01 | V1 | System Translation | Paste-text translation (paragraphs 1:1, protected words, copy/share/history) – SYSTEM_TRANSLATION.md – owner req 2026-11-06 S5 | P1 | V1-ENG-02, V1-ENG-07, V1-AIP-01, V1-SEC-03, V1-TRP-01 | PLANNED | - |
| V1-STR-02 | V1 | System Translation | Background execution + recovery of translation jobs (Android WorkManager/foreground service; iOS pauses honestly); queue states stay V1-TSK-01 – owner req 2026-11-06 S5 | P1 | V1-TSK-01, V1-ENG-05 | PLANNED | - |
| V2-STR-01 | V2 | System Translation | Android Share-to-Translate (ACTION_SEND text/files) – owner req 2026-11-06 S5 | P1 | V1-STR-01 | PLANNED | - |
| V2-STR-02 | V2 | System Translation | iOS Share Extension → app (App Group handoff) – owner req 2026-11-06 S5 | P2 | V2-STR-01 | PLANNED | - |
| V2-STR-03 | V2 | System Translation | Android selected-text translation via ACTION_PROCESS_TEXT (only in supporting apps) – owner req 2026-11-06 S5 | P1 | V1-STR-01 | PLANNED | - |
| V2-STR-04 | V2 | System Translation | iOS selected text via Action Extension – evaluation only – owner req 2026-11-06 S5 | P3 | V2-STR-02 | PLANNED | - |
| V2-STR-05 | V2 | System Translation | User-triggered clipboard translation (no background clipboard reading) – owner req 2026-11-06 S5 | P2 | V1-STR-01 | PLANNED | - |
| V2-STR-06 | V2 | System Translation | URL/article import + translation (readability extraction, sanitising, no paywall bypass) – owner req 2026-11-06 S5 | P2 | V1-STR-01, V1-ENC-01, V1-SEC-02 | PLANNED | - |
| V2-STR-07 | V2 | System Translation | Optional floating translation bubble (Android, overlay permission, off by default; not on iOS) – owner req 2026-11-06 S5 | P3 | V2-STR-05 | PLANNED | - |
| V3-STR-01 | V3 | System Translation | Optional accessibility-based translation (Android; Play declaration + separate consent; never required) – owner req 2026-11-06 S5 | P3 | V2-STR-03 | PLANNED | - |
| V3-STR-02 | V3 | System Translation | Advanced webpage translation with structure preservation – owner req 2026-11-06 S5 | P2 | V2-STR-06 | PLANNED | - |
| V1-TTS-01 | V1 | Read Aloud | TtsEngine interface + Android system TTS adapter (Hindi/English, voice detection) – READ_ALOUD_TTS.md – owner req 2026-11-06 S5 | P1 | V1-ENC-03 | PLANNED | - |
| V1-TTS-02 | V1 | Read Aloud | iOS native speech adapter (AVSpeechSynthesizer), evaluated independently – owner req 2026-11-06 S5 | P1 | V1-TTS-01 | PLANNED | - |
| V1-TTS-03 | V1 | Read Aloud | Read original (L2→L1) or translation (L4→L3) only; refuse L0/unvalidated OCR/legacy text – owner req 2026-11-06 S5 | P0 | V1-LEG-03, V1-EDT-01 | PLANNED | - |
| V1-TTS-04 | V1 | Read Aloud | Reading scopes: selection, paragraph, chapter, continuous; Hindi/English sentence chunking – owner req 2026-11-06 S5 | P1 | V1-TTS-01, V1-IMP-07 | PLANNED | - |
| V1-TTS-05 | V1 | Read Aloud | Playback controls, voice, speed, pitch (per-language settings) – owner req 2026-11-06 S5 | P1 | V1-TTS-04 | PLANNED | - |
| V1-TTS-06 | V1 | Read Aloud | Save/restore reading position (paragraph-id anchored) – owner req 2026-11-06 S5 | P1 | V1-STO-01, V1-TTS-04 | PLANNED | - |
| V1-TTS-07 | V1 | Read Aloud | Background playback, media notification, audio focus/interruptions, lifecycle – owner req 2026-11-06 S5 | P1 | V1-TTS-05 | PLANNED | - |
| V1-TTS-08 | V1 | Read Aloud | Secure BYOK AI TTS configuration architecture (no network in V1, no auto-paid) – owner req 2026-11-06 S5 | P2 | V1-AIP-02, V1-SEC-01, V1-SEC-03 | PLANNED | - |
| V1-TTS-09 | V1 | Read Aloud | Mixed-script segments (Hindi + English words), digit policy – owner req 2026-11-06 S5 | P2 | V1-TTS-04, V1-TRP-02 | PLANNED | - |
| V2-TTS-01 | V2 | Read Aloud | Real AI TTS provider integration (consent, cost shown, fallback only after asking) – owner req 2026-11-06 S5 | P1 | V1-TTS-08 | PLANNED | - |
| V2-TTS-02 | V2 | Read Aloud | Provider-specific AI TTS adapters with declared capabilities – owner req 2026-11-06 S5 | P1 | V1-AIP-01 | PLANNED | - |
| V2-TTS-03 | V2 | Read Aloud | Audio chunking, caching (hash+provider+voice+settings), resume – owner req 2026-11-06 S5 | P1 | V2-TTS-01, V1-TTS-06 | PLANNED | - |
| V2-TTS-04 | V2 | Read Aloud | Sentence/word highlighting where reliable (grapheme-safe fallback) – owner req 2026-11-06 S5 | P2 | V1-TTS-04 | PLANNED | - |
| V2-TTS-05 | V2 | Read Aloud | Audio export + My Recordings – owner req 2026-11-06 S5 | P2 | V2-TTS-03 | PLANNED | - |
| V2-TTS-06 | V2 | Read Aloud | Explicit free/paid model and quota information, never auto-switch – owner req 2026-11-06 S5 | P1 | V1-AIP-01 | PLANNED | - |
| V3-TTS-01 | V3 | Read Aloud | Bilingual listening – owner req 2026-11-06 S5 | P2 | V1-TTS-03, V2-TTS-03 | PLANNED | - |
| V3-TTS-02 | V3 | Read Aloud | Multiple speakers/voices (character register) – owner req 2026-11-06 S5 | P3 | V2-TTS-02, V1-ENG-08 | PLANNED | - |
| V3-TTS-03 | V3 | Read Aloud | Advanced voice customisation (pronunciation, SSML) – owner req 2026-11-06 S5 | P3 | V2-TTS-02 | PLANNED | - |

> VERIFIED here means automated tests passed in GitHub Actions (run 42146771459, commit 529643f). No real-device testing yet.
