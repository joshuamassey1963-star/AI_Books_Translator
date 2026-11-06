# AI_Books_translator

> Open-source AI book translator for Android and iOS. Translate full-length books into Hindi (more languages later) with consistent terminology, an editable review workspace, and safe resume after interruptions.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green.svg)
![Status](https://img.shields.io/badge/status-planning-orange.svg)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

> **Project status:** This repository currently contains the feature specification and engineering plan. Nothing listed below should be treated as implemented or verified until it has been tested on real devices. See [Feature Status](#feature-status).

## Goal

Translate a complete book from **English to Hindi** in a way that is consistent, editable, safe, and fast, then expand to other languages.

## Key Principles

- **Offline-first:** The library, editor, and export work without internet. V1 needs no account or cloud.
- **A real translation engine, not just a UI:** Parse, normalize, segment, add glossary context, translate, validate structure, save, review, export.
- **Fast does not mean more parallel requests:** Speed comes from good chunking, caching, rate-limit awareness, and context reuse.
- **No provider lock-in:** Multiple AI providers with fallback. No free API or local model is guaranteed to stay available.
- **Original files are never modified:** All translations, edits, and exports are stored as separate versions.

## Roadmap

### V1: Foundation (reliable English to Hindi book translation)

**Import and parsing**
- EPUB (primary), TXT, DOCX, and text-layer PDF
- Chapter, heading, and paragraph detection (footnotes, images, tables, inline emphasis, reading order)
- Scanned PDFs detected with a clear "OCR required" message (OCR arrives in V2)
- Immutable source file, SHA-256 fingerprint, duplicate detection on re-import

**Translation engine**
- Provider adapters: Gemini, OpenAI-compatible endpoints, OpenRouter, self-hosted Ollama
- Token-budget chunking that respects chapter boundaries and keeps paragraph IDs, quotes, footnotes, and Markdown/HTML tags safe
- Controlled concurrency (start with 1-3 workers), exponential backoff with jitter on 429, cancellation, idempotent retry
- SQLite checkpoints per chunk (input hash, model, prompt, glossary version, result, review state)
- Translation memory and cache to avoid repeat API calls

**Custom dictionary and instructions**
- Exact translations, aliases, case rules, protected terms, names, context notes, priority
- CSV/JSON import and export, conflict detection
- Terminology validator on the output (not just search and replace)
- Style instructions: literary, simple, or formal tone; honorifics; grammar; do-not-translate rules
- Book-level style guide and short, controlled context from earlier chapters

**Editor, tasks, and export**
- Two-pane source/translation editor with paragraph alignment, undo/redo, search/replace, autosave, review status, manual lock
- Task queue: pending, running, paused, failed, completed; progress; estimated tokens/cost; "retry failed only"
- Export to TXT, DOCX, EPUB, and Unicode Hindi PDF with font embedding
- Metadata, TOC, chapter order, Unicode normalization, and broken-tag validation

**V1 release gate**
- At least 3 different EPUB books tested for chapter order, paragraph count, and glossary compliance
- Library, editor, and export work in airplane mode, with no data loss if the API is interrupted
- Safe resume after force close or restart, without duplicate billing
- Devanagari ligatures, matras, search, copy, and PDF/EPUB text checked on both Android and iOS

### V2: Quality, OCR, and advanced workspace

- **OCR and PDF:** Scanned PDFs and images. ML Kit (Android) and Vision (iOS), with an accuracy comparison for Hindi and English. Optional server OCR (Tesseract/PaddleOCR) only with clear consent and cost. OCR correction editor and best-effort handling of tables, columns, and footnotes.
- **Quality assurance:** Optional two-pass translation (draft, reviewer, human approval). Automatic checks for missing or added paragraphs, numeric mismatches, verse numbers, protected tokens, and HTML integrity. Fuzzy translation memory. Glossary suggestions with approve/reject. Original vs AI vs edited comparison and audit trail.
- **Reader and productivity:** Bilingual EPUB reader with paragraph sync, bookmarks, notes, and search. Batch projects, priority queue, selective re-translate. Style presets, prompt templates, model comparison on a sample chapter, cost estimate before the full book. Better DOCX formatting, keyboard shortcuts, tablet layout, accessibility.

### V3: Professional publishing and optional offline AI

- On-device LLM (llama.cpp/MLX) only on capable phones and after real benchmarks of size, RAM, heat, battery, and quality
- Optional account with encrypted cloud sync, cross-device progress, and conflict resolution (offline-first stays)
- Team roles, comment threads, approval workflow, revision history, publishing presets
- Terminology knowledge base, multi-book consistency, advanced QA dashboard, evaluation corpus
- Optional desktop/web companion or self-hosted translation server

## Architecture

| Layer | Planned stack |
|---|---|
| UI | Flutter, Material/Cupertino, Riverpod, go_router |
| Local data | Drift (SQLite), migrations, FTS search, transactional checkpoints |
| Secrets | Android Keystore / iOS Keychain (keys never in logs or analytics) |
| Networking | Dio, timeouts, retry policy, TLS, provider adapters |
| Heavy processing | Dart isolates, native Kotlin/Swift or FFI where needed |
| File access | Android SAF, iOS document picker with security-scoped access |
| Cloud engine (optional) | FastAPI, or Go/Rust, with durable queue and object storage |
| CI/QA | GitHub Actions, unit and integration tests, release builds, SHA-256 artifacts |

The final engine and library choices will be made after benchmarking 3-5 real books for speed, memory, Hindi quality, cost, license, and crash rate.

## Platform Notes

**Android:** Distributed as APK/AAB. Uses Storage Access Framework and WorkManager, with a foreground service for long tasks where policy allows. Task state survives process death.

**iOS:** Built with Xcode on macOS and distributed via TestFlight/App Store. Uninterrupted background processing is not guaranteed because of iOS restrictions, so the app relies on checkpoint recovery and resume.

**Both platforms:**
- Long translations should not depend on the app staying open. Resume and remote processing are the main reliability strategy.
- Separate error codes for 401, 403, 429, timeout, quota, network loss, model unavailable, and export failure.
- No automatic switch to a paid provider without permission. Cost ceiling and free-only mode are planned.

## Performance Targets

These are design targets, not measured results. No benchmarks exist yet.

- 60 fps scrolling and editor interaction on mid-range Android and iPhone
- Quick preview when importing a 10 MB EPUB, with full parsing in the background
- Every successful chunk saved transactionally
- Lazy chapter loading and streaming export for large books
- Throughput (words/minute, cost per 10k words) to be measured on 3 book types

## Privacy and Security

- Explicit consent and a privacy notice before any book text is sent to an AI provider
- Bring Your Own Key (BYOK): keys stay in local secure storage, and no shared paid keys are embedded in the app
- Imported files are tested against path traversal, ZIP bombs, XXE, malformed XML, oversized images, and unsafe HTML
- Dependency license inventory (SPDX/SBOM) and scanning. No MIT/AGPL/GPL code is copied without review.
- Telemetry, if any, is opt-in. Book text, API keys, and personal data are never logged.

## Legal and Copyright

Translate only content you have the right to translate: public domain or legally permitted material. AI translations may contain errors, and your provider may bill you for API usage.

## Testing Plan

- **Test books:** general novel, religious/philosophical book, technical book with footnotes and tables, 1000+ page book, poor-quality PDF, scanned PDF
- **Hindi checks:** conjuncts, matras, digits, mixed English text, Unicode normalization, font embedding, copy and search
- **Glossary:** 100+ terms covering exact matches, aliases, ambiguous terms, protected names, conflicts, chapter-boundary consistency
- **Quality metrics:** human review score, omission rate, number preservation, glossary violations, broken tags, export reopen success
- **Reliability:** airplane mode, network flapping, 429/503, app kill, reboot, full storage, low RAM, cancel/resume

## Feature Status

Every feature moves through: `Proposed` → `Designed` → `Implemented` → `Tested` → `Verified`. `Blocked` and `Deferred` are tracked separately. A feature in this roadmap is **not** implemented automatically.

- Before each release: security review, license review, regression tests, and real-device acceptance
- Free providers are not treated as permanently free. Check quota, terms, and model availability regularly.
- New libraries are chosen on license, maintenance, benchmarks, binary size, and platform support, not on popularity alone

## Inspiration

We study these projects for design patterns only. Licenses are reviewed before any code is reused, and we prefer a specification-first or independent implementation:

- [bilingual_book_maker](https://github.com/yihong0618/bilingual_book_maker)
- [TranslateBooksWithLLMs](https://github.com/hydropix/TranslateBooksWithLLMs) (AGPL, review carefully)
- [ebook-GPT-translator](https://github.com/jesselau76/ebook-GPT-translator)
- [YN Translation Workshop](https://github.com/TohmaN233/YN-translation-workshop)
- [Tolmach](https://github.com/KazKozDev/book-translator) (AGPL)

## Contributing

1. Fork the repository.
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m "Add your feature"`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request.

Bug reports, test books, glossary samples, and device test results are especially welcome. Open an [issue](../../issues) to start.

## License

MIT License. See [LICENSE](LICENSE). Check dependency licenses (especially AGPL/GPL) before merging code.
---

## Development (code status)

> **Current milestone: M1 Platform folders + CI.** Only the Flutter navigation shell exists; every other screen shows "Not available yet". Live status: `docs/PROGRESS.md`, `docs/FEATURE_MATRIX.md`, `docs/HANDOVER.md`.

Docs: `docs/ROADMAP.md` · `docs/ARCHITECTURE.md` · `docs/DECISIONS.md` · `docs/DEPENDENCIES.md` · `docs/RESEARCH.md` · `docs/TEST_PLAN.md` · requirements PDF `docs/AI_Book_Translator_Roadmap_V1_V3.pdf`.

```bash
flutter --version            # 3.47.9 stable expected
flutter pub get && flutter analyze && flutter test
```
