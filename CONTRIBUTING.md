# Contributing

1. Branch from `develop`: `feature/<feature-id>-<slug>` or `fix/<slug>`.
2. Keep each feature in its own commit or clear commit group. Message: `feat(V1-GLO-01): add glossary term CRUD`.
3. Before pushing: `flutter analyze`, `flutter test`, `dart format .`.
4. Update `docs/FEATURE_MATRIX.md`, `docs/PROGRESS.md`, `docs/HANDOVER.md`.
5. Open a PR into `develop`; CI must pass. `main` changes only with the owner's approval.
6. Never commit secrets, API keys, keystores or `.env` files.
7. No AGPL/GPL code without a written license-compatibility review (see `docs/DECISIONS.md` D-009).
