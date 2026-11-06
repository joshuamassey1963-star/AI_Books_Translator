# Feature Matrix

Source: *AI Book Translator Roadmap V1–V3* (03 Nov 2026) plus the project brief. Statuses: `PLANNED`, `IN PROGRESS`, `IMPLEMENTED`, `VERIFIED`, `BLOCKED`. **IMPLEMENTED ≠ VERIFIED**: VERIFIED needs passing automated tests, and real-device checks where the roadmap asks for them.

Totals: 101 features — IMPLEMENTED: 0, IN PROGRESS: 1, PLANNED: 96, VERIFIED: 4

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
| V1-STO-04 | V1 | Storage | Original file immutable; translations/edits/exports saved as separate versions | P0 | V1-STO-01 | PLANNED | - |
| V1-LIB-01 | V1 | Library | Bookshelf list of local projects | P0 | V1-STO-01 | PLANNED | - |
| V1-LIB-02 | V1 | Library | Book details: metadata, chapter navigator, search | P1 | V1-IMP-04 | PLANNED | - |
| V1-IMP-01 | V1 | Import | EPUB import (first priority format) | P0 | V1-STO-01 | PLANNED | - |
| V1-IMP-02 | V1 | Import | TXT and DOCX import | P0 | V1-STO-01 | PLANNED | - |
| V1-IMP-03 | V1 | Import | Text-layer PDF import; detect scanned PDF and show 'OCR required' | P0 | V1-STO-01 | PLANNED | - |
| V1-IMP-04 | V1 | Import | Structure model: chapter/heading/paragraph, footnotes, images, tables, inline emphasis, reading order | P0 | V1-IMP-01 | PLANNED | - |
| V1-IMP-05 | V1 | Import | Real file-type check (magic bytes), size/storage limits, corrupt-file recovery | P0 | V1-IMP-01 | PLANNED | - |
| V1-IMP-06 | V1 | Import | SHA-256 fingerprint, project snapshot, import diagnostics, duplicate detection | P1 | V1-IMP-01 | PLANNED | - |
| V1-IMP-07 | V1 | Import | Chapter detection and chapter tree | P0 | V1-IMP-04 | PLANNED | - |
| V1-ENG-01 | V1 | Engine | Pipeline: Parse→Normalize→Segment→Context/Glossary→Translate→Validate→Save→Review→Export | P0 | V1-IMP-04 | PLANNED | - |
| V1-ENG-02 | V1 | Engine | Token-budget chunking respecting chapter bounds, paragraph IDs, quotes, footnotes, tags | P0 | V1-ENG-01 | PLANNED | - |
| V1-ENG-03 | V1 | Engine | Controlled concurrency (start 1-3 workers), cancellation | P0 | V1-ENG-01 | PLANNED | - |
| V1-ENG-04 | V1 | Engine | 429 handling: exponential backoff + jitter; idempotent retry | P0 | V1-AIP-01 | PLANNED | - |
| V1-ENG-05 | V1 | Engine | SQLite checkpoints per chunk: input hash, model, prompt, glossary version, result, review state | P0 | V1-STO-01 | PLANNED | - |
| V1-ENG-06 | V1 | Engine | Translation cache/memory: no repeat API call for same text+settings; invalidate on glossary change | P0 | V1-ENG-05 | PLANNED | - |
| V1-ENG-07 | V1 | Engine | Structural validator: no skipped paragraph, order preserved, missing sections detected | P0 | V1-ENG-01 | PLANNED | - |
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
| V1-TSK-01 | V1 | Tasks | Task queue states: Pending/Running/Paused/Failed/Completed | P0 | V1-ENG-05 | PLANNED | - |
| V1-TSK-02 | V1 | Tasks | Chunk progress, estimated tokens (cost when available) | P1 | V1-TSK-01 | PLANNED | - |
| V1-TSK-03 | V1 | Tasks | Pause/resume/retry; retry failed chunks only | P0 | V1-TSK-01 | PLANNED | - |
| V1-TSK-04 | V1 | Tasks | Resume from checkpoint after force-close/restart without duplicate billing | P0 | V1-ENG-05 | PLANNED | - |
| V1-TSK-05 | V1 | Tasks | Android WorkManager / foreground service where allowed; iOS BGTask version-aware, no guaranteed background | P1 | V1-TSK-01 | PLANNED | - |
| V1-EXP-01 | V1 | Export | TXT export | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-02 | V1 | Export | DOCX export (preserve formatting where possible) | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-03 | V1 | Export | EPUB export (metadata, TOC, chapter order, tag validation) | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-04 | V1 | Export | Unicode Hindi PDF with font embedding (Devanagari ligatures, matras, copy/search) | P0 | V1-ENG-01 | PLANNED | - |
| V1-EXP-05 | V1 | Export | Hindi-only and bilingual output; Unicode normalization; pre-export validation | P1 | V1-EXP-01 | PLANNED | - |
| V1-SEC-01 | V1 | Security | API keys in Android Keystore / iOS Keychain; never in code, logs, git | P0 | - | PLANNED | - |
| V1-SEC-02 | V1 | Security | Import hardening: path traversal, ZIP bomb, XXE, malformed XML, oversized images, unsafe HTML | P0 | V1-IMP-01 | PLANNED | - |
| V1-SEC-03 | V1 | Security | Explicit consent + privacy notice before sending text to a cloud provider | P0 | V1-AIP-01 | PLANNED | - |
| V1-SEC-04 | V1 | Security | No book text, keys or PII in logs; telemetry opt-in only | P0 | - | PLANNED | - |
| V1-SEC-05 | V1 | Security | Minimal platform permissions (SAF / document picker, sandbox copies) | P0 | - | PLANNED | - |
| V1-SEC-06 | V1 | Security | License inventory (SPDX/SBOM) and dependency scanning in CI | P1 | V1-CI-01 | PLANNED | - |
| V1-SET-01 | V1 | Settings | Settings: privacy, consent, storage, theme | P1 | V1-STO-01 | PLANNED | - |
| V1-ERR-01 | V1 | Reliability | Error handling + help/diagnostics screen with error codes | P0 | V1-AIP-04 | PLANNED | - |
| V1-ERR-02 | V1 | Reliability | Airplane mode / network flapping / storage full / low RAM without data loss | P0 | V1-ENG-05 | PLANNED | - |
| V1-OFF-01 | V1 | Offline | Local library and editor work without internet; no mandatory account | P0 | V1-STO-01 | PLANNED | - |
| V1-PRF-01 | V1 | Performance | Performance baseline: startup, import latency (10MB EPUB), memory, 60fps scroll | P1 | V1-IMP-01 | PLANNED | - |
| V1-PRF-02 | V1 | Performance | Isolates for heavy parsing; lazy loading/virtualized chapters; streaming export | P1 | V1-IMP-01 | PLANNED | - |
| V1-CI-01 | V1 | QA/CI | GitHub Actions: analyze + unit/widget tests | P0 | - | VERIFIED | CI run 42146771459 green (analyze: no issues, 14/14 tests) |
| V1-CI-02 | V1 | QA/CI | Android debug APK build in CI | P0 | V1-CI-01 | VERIFIED | CI run 42146771459: debug APK built + uploaded |
| V1-CI-03 | V1 | QA/CI | iOS build on macOS runner; release builds with SHA-256 artifacts | P1 | V1-CI-01 | PLANNED | - |
| V1-CI-04 | V1 | QA/CI | Integration tests on emulator | P1 | V1-CI-01 | PLANNED | integration_test/app_launch_test (written, not run) |
| V1-REL-01 | V1 | Release | Acceptance: 3 EPUBs keep chapter order + paragraph count; force-close resume; Devanagari checks on Android+iOS | P0 | all V1 | PLANNED | - |
| V1-REL-02 | V1 | Release | Accessibility, store compliance, copyright notice (only rights-cleared content) | P1 | all V1 | PLANNED | - |
| V2-OCR-01 | V2 | OCR | OCR for scanned PDF/images: ML Kit (Android), Vision (iOS); Hindi/English accuracy comparison | P0 | V1-IMP-03 | PLANNED | - |
| V2-OCR-02 | V2 | OCR | Optional server OCR (Tesseract/PaddleOCR) with consent and cost shown | P2 | V2-OCR-01 | PLANNED | - |
| V2-OCR-03 | V2 | OCR | OCR correction editor: page image + text, confidence flags, page-wise fixes, searchable output | P1 | V2-OCR-01 | PLANNED | - |
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
| V3-LLM-01 | V3 | Offline AI | Optional on-device LLM (llama.cpp / MLX) only on capable devices after benchmark | P1 | V1-AIP-01 | PLANNED | - |
| V3-LLM-02 | V3 | Offline AI | Model manager: size, RAM, heat, battery, quality gating; thermal throttling | P1 | V3-LLM-01 | PLANNED | - |
| V3-SYN-01 | V3 | Sync | Optional account + encrypted cloud sync, offline-first | P2 | V1-STO-01 | PLANNED | - |
| V3-SYN-02 | V3 | Sync | Cross-device progress, project export/import, conflict resolution | P2 | V3-SYN-01 | PLANNED | - |
| V3-SRV-01 | V3 | Cloud Engine | Optional remote durable jobs (FastAPI/Go/Rust workers, queue, object storage) | P2 | V1-ENG-01 | PLANNED | - |
| V3-TEAM-01 | V3 | Team | Editor roles, comment threads, approval workflow, revision history | P2 | V3-SYN-01 | PLANNED | - |
| V3-PUB-01 | V3 | Publishing | Professional publishing presets | P2 | V1-EXP-03 | PLANNED | - |
| V3-QA-01 | V3 | Advanced QA | Terminology knowledge base, multi-book consistency, chapter context retrieval | P2 | V2-QA-03 | PLANNED | - |
| V3-QA-02 | V3 | Advanced QA | QA dashboard and translation evaluation corpus | P2 | V2-QA-06 | PLANNED | - |
| V3-WSP-01 | V3 | Workspace | Advanced workspace; optional desktop/web companion or self-hosted server (never mandatory) | P3 | V3-SRV-01 | PLANNED | - |
| V3-PRF-01 | V3 | Performance | Performance optimization from recorded baselines | P2 | V1-PRF-01 | PLANNED | - |

> VERIFIED here means automated tests passed in GitHub Actions (run 42146771459, commit 529643f). No real-device testing yet.
