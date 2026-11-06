# Test Plan

## Levels
| Level | Tool | Where | Now |
|---|---|---|---|
| Unit | flutter_test | `test/unit/` | screen registry, FeatureStatus |
| Widget | flutter_test | `test/widget/` | launch, tabs, More sub-screens, per-tab stacks, Book Details route, no dead buttons/fake progress |
| Integration | integration_test | `integration_test/` | cold start (written; needs emulator, not run) |
| Static | flutter analyze, dart format | CI | configured |

## Corpus (roadmap §13, to be assembled in M2)
Public-domain novel, religious/philosophical book, technical book with footnotes/tables, 1000+ page book, broken PDF, scanned PDF. Hindi checks: conjuncts, matras, digits, mixed English, Unicode normalization, font embedding, copy/search. Glossary: 100+ terms incl. aliases, ambiguous terms, protected names, conflicts, chapter-boundary consistency.

## Text, font, encoding and export tests (owner requirements 2026-11-06)
- Matrices and test strings: `docs/TEXT_ENCODING_FONT_COMPATIBILITY.md` (40 Hindi + 20 English fonts, encoding cases EN01–EN14, test strings T01–T11, PDF export checks X01–X10).
- Regression cases from the old reader project: `docs/REGRESSION_CASES.md` (RC-001..015).
- Test PDFs are **generated** (our own text + OFL fonts) in test setup or CI; legacy-font samples and real books stay outside git and are run manually by the owner.
- CI tools for export checks (planned M2b-3): `pdftotext`, `pdffonts`, `pdftoppm` (poppler) on the Ubuntu runner; rendered PNGs uploaded as artifacts for visual review.
- Legacy conversion: table-driven unit tests per font + negative tests (wrong font, unknown chars, English/digits untouched).
- A font row becomes PASS only with a CI run id or a dated owner check per column.

## Reliability scenarios
Airplane mode, network flapping, 429/503, app kill, device reboot, storage full, low RAM, cancel/resume.

## Rule
A feature becomes VERIFIED only when its tests pass in CI (and on real devices where the roadmap requires). Current evidence: see PROGRESS.md (latest green run 42152743112, 34/34 tests).
