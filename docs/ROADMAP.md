# Roadmap & Milestones

Requirements source: `docs/AI_Book_Translator_Roadmap_V1_V3.pdf` (03 Nov 2026). Feature IDs: `docs/FEATURE_MATRIX.md`. One milestone per session; each ends with tests, docs, commit, push, handover.

| # | Milestone | Scope (feature IDs) | Exit criteria | Status |
|---|---|---|---|---|
| M0 | Foundation (Session 1) | V1-NAV-01/02, V1-CI-01/02, docs | Shell + tests written; CI green on GitHub | DONE (CI run 42146771459) |
| M1 | Platform folders + CI green | commit android/ & ios/, first CI run, format pass | `flutter analyze` + `flutter test` green in CI; debug APK artifact | DONE (CI run 42149165709) |
| M2a | P0 spike: parsers | TXT/EPUB/DOCX → BookDocument, zip/XML hardening | parser unit tests green in CI | DONE (CI run 42152743112) |
| M2b | P0 spike: PDF + provider | text-layer PDF probe, Hindi PDF export probe (Devanagari shaping), provider adapter + BYOK ping | 2 chapters of a sample book import/export correctly | PLANNED |
| M3 | V1-A Storage | V1-STO-01/02/04, V1-SEC-01, V1-SET-01 | Schema + migration tests; secure-storage test | PLANNED |
| M4 | V1-B Import | V1-IMP-01..07, V1-SEC-02, V1-LIB-01/02 | Content order + corrupt/malicious file tests | PLANNED |
| M5 | V1-C Glossary & Instructions | V1-GLO-01..07, V1-INS-01/02 | Glossary unit tests incl. conflicts, protected terms | PLANNED |
| M6 | V1-C Provider adapters | V1-AIP-01..08, V1-SEC-03 | Adapter tests with mocked HTTP for every error code | PLANNED |
| M7 | V1-C Chunking & pipeline | V1-ENG-01/02/07/08/09 | EN→HI on 3 sample chapters, structural validator tests | PLANNED |
| M8 | V1-D Queue & recovery | V1-ENG-03..06, V1-TSK-01..05, V1-ERR-01/02 | Force-stop, 429, offline recovery tests | PLANNED |
| M9 | V1-E Editor | V1-EDT-01..03 | Alignment + autosave tests | PLANNED |
| M10 | V1-E Export | V1-EXP-01..05 | Hindi fonts, paragraph alignment, re-open tests | PLANNED |
| M11 | V1 Release | V1-REL-01/02, V1-PRF-01/02, V1-CI-03/04 | Acceptance checklist signed off on real devices | PLANNED |
| M12+ | V2 | V2-* | OCR benchmark + quality metrics | PLANNED |
| M20+ | V3 | V3-* | Device / cost / privacy validation | PLANNED |
