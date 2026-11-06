# Architecture Decision Log

Format: ID · date · decision · why · alternatives · status. Versions checked on pub.dev / Flutter release feed on 2026-11-06.

## D-001 · 2026-11-06 · Flutter + Dart, one UI for Android and iOS
- **Why:** roadmap §7; one codebase, AOT-compiled, Impeller renderer. Native Kotlin/Swift only where needed (OCR, background work, on-device AI).
- **Alternatives:** React Native, Kotlin Multiplatform. Rejected for this team size and roadmap fit.
- **Status:** Accepted.

## D-002 · 2026-11-06 · Pin Flutter stable 3.47.9 (Dart 3.13.7) in CI
- **Why:** reproducible builds; roadmap asks for build-time pinning. It was the current stable on the official release feed on 2026-11-06.
- **Status:** Accepted. Bump only in a dedicated `chore/` commit with CI green.

## D-003 · 2026-11-06 · State management: Riverpod 3 (`flutter_riverpod` 3.4.3, MIT)
- **Why:** compile-safe DI, testable overrides, active (published 2026-09-03). Code generation (`riverpod_generator` 4.0.9) deferred until a feature needs it, to keep Session 1 dependency-light.
- **Alternatives:** Bloc, Provider. Rejected: more boilerplate / less DI power.
- **Status:** Accepted.

## D-004 · 2026-11-06 · Routing: go_router 18.1.3 (BSD-3), StatefulShellRoute.indexedStack
- **Why:** official Flutter package, deep links, per-tab navigation stacks (roadmap §2). Requires Flutter ≥3.44 – satisfied by D-002.
- **Status:** Accepted.

## D-005 · 2026-11-06 · Local data: Drift 2.35.x + SQLite (MIT) — to be added in milestone V1-A
- **Why:** typed queries, migrations with tests, FTS5, transactional checkpoints (roadmap §7).
- **Note:** `sqlite3_flutter_libs` is now `0.6.0+eol`; use `drift_flutter` 0.3.1 / `sqlite3` 3.x native assets instead. Verify on Android + iOS build in V1-A before final.
- **Status:** Proposed (verify in V1-A).

## D-006 · 2026-11-06 · Feature-based clean architecture
- `lib/app` (shell, router, theme) · `lib/core` (shared types, errors, utils) · `lib/features/<feature>/{data,domain,presentation}`.
- Repository pattern between domain and data. Engine components (parser, chunker, glossary, provider adapters, queue, validator, TM, export) live in pure-Dart packages under `lib/features/engine/...` so they are unit-testable without Flutter.
- **Status:** Accepted.

## D-007 · 2026-11-06 · Provider-independent AI layer, BYOK only
- One `TranslationProvider` interface; adapters for Gemini, OpenAI-compatible, OpenRouter, Ollama. Model ids, prices and free-tier claims are never hardcoded; the user enters them and the app tests the connection.
- No shared paid key in the app. Never auto-switch to a paid model.
- **Status:** Accepted (implementation in V1-C).

## D-008 · 2026-11-06 · Honest placeholders
- Unbuilt screens render `PlannedScreen`: status + target version, no buttons, no progress bars, no success messages. Enforced by widget tests.
- **Status:** Accepted.

## D-009 · 2026-11-06 · Open-source reuse policy
- Ideas may be taken from any project; **code** only from permissive licenses (MIT/Apache/BSD) with attribution in `docs/DEPENDENCIES.md`. AGPL/GPL repos (TranslateBooksWithLLMs, Tolmach/book-translator, Ebook-Subtitle-Translator, PapyrusReader) are study-only. No code copied in Session 1.
- **Status:** Accepted.

## D-010 · 2026-11-06 · Branch strategy
- `main` stable (merge only with owner's approval) · `develop` integration · `feature/<id>-<slug>` · `fix/<slug>`. PRs into `develop` with CI required.
- **Status:** Accepted.

## D-011 · 2026-11-06 · Libraries to avoid / re-check
- `epubx` (last release 2023-06) – stale; write our own EPUB parser on `archive` 4.6.0 + `xml` 7.1.0 (both MIT, active) with hardening tests.
- `docx_template` (2023-09) – template-only; DOCX writer to be built on `archive` + OOXML.
- `syncfusion_flutter_pdf` – commercial licence; avoid unless owner approves.
- PDF write: `pdf` 3.13.1 (Apache-2.0); PDF text extraction: evaluate `pdfrx` 2.12.0 (MIT, PDFium) in P0 spike.
- **Status:** Proposed (benchmarks in P0 spike).
