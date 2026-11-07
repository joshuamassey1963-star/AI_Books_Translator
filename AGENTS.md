# Instructions for AI coding agents and human contributors

**Start here before changing code.** This file is a public, repository-scoped handover. It is not ChatGPT's private memory or an instruction to disclose private conversations.

## First read, in this order
1. [Project memory / current verified status](docs/PROJECT_MEMORY.md).
2. [Chronological session ledger](docs/SESSION_LEDGER.md).
3. [Roadmap](docs/ROADMAP.md), [feature matrix](docs/FEATURE_MATRIX.md), [handover](docs/HANDOVER.md).
4. [Architecture](docs/ARCHITECTURE.md), [decision log](docs/DECISIONS.md), [regressions](docs/REGRESSION_CASES.md), [test plan](docs/TEST_PLAN.md).
5. For related scope: [owner requirements](docs/OWNER_REQUESTS.md), [text/font/encoding](docs/TEXT_ENCODING_FONT_COMPATIBILITY.md), [system translation](docs/SYSTEM_TRANSLATION.md), [TTS](docs/READ_ALOUD_TTS.md).

## Source-of-truth and branch discipline
- GitHub source, checked PRs, CI evidence, and test artifacts are authoritative over conversational summaries. Fetch live refs before starting: these documents are snapshots.
- `develop` is the integration branch; **never merge to `main` without explicit owner permission**.
- Create a narrowly scoped feature branch from the latest `develop`. Each session delivers **one small sub-milestone**, not the whole roadmap.
- Review, test, commit, push, update docs, open a PR against `develop`; do not automatically merge the new PR.
- Before merging an existing PR, inspect its current diff, conflicts and latest CI; do not rely on earlier successful runs after later commits.
- Keep executable scope separate from requirements registration. `PLANNED`, `IN PROGRESS`, `IMPLEMENTED`, `VERIFIED`, `BLOCKED` are different claims.
- Use format, analyzer, unit/widget tests, Android/iOS compile CI as applicable. Device testing and real-book tests are separately required where specified.
- At each stable checkpoint record exact commit SHA, branch, CI run URL/results, PR status, failed/partial cases, blockers, and next exact step. Stop cleanly if context/usage limits are near.

## Owner's APK policy
- Routine backend, docs and minor UI changes: **no user-testing APK publication/request**.
- Publish a download-ready testing APK **only for a substantial visible new screen, tab or user-facing feature** and explain what actually changed.
- CI may still compile Android/iOS. The CI workflow has an optional `[publish-apk]` publication trigger; inspect the live workflow before using it.
- Do not bump app version merely for docs/rebuilds. When publishing, provide version, actual commit/build identity, artifact URL, expiration and an owner test checklist.

## Safety and integrity
- No secrets, API keys, private documents/books/fonts, personal user data, or private chat transcripts in this public repository, logs, tests or PRs.
- Immutable original source document; distinguish extraction and corrected/translated layers. Never silently drop characters, paragraphs or protected terms.
- Legacy-font conversion requires positively confirmed font identity, never ASCII-like appearance alone.
- PDF Hindi export must be both visually correct **and** extractable; tests based on copy/search alone are insufficient.
- AI provider/TTS keys must use secure storage; no assumed free quotas or silent paid-provider changes.
- No universal Android/iOS cross-app translation promise; honor OS/privacy and store-policy constraints.

## Reporting
Reply to the owner in Hindi with: completed vs pending, exact evidence, limitations, PR link, and **only the next narrowly scoped sub-milestone**. Do not start later milestones without their go-ahead.

If context seems missing, recover from GitHub and the linked documents rather than guessing or silently redefining scope.
