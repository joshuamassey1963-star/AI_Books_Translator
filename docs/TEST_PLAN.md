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

## Reliability scenarios
Airplane mode, network flapping, 429/503, app kill, device reboot, storage full, low RAM, cancel/resume.

## Rule
A feature becomes VERIFIED only when its tests pass in CI (and on real devices where the roadmap requires). Session 1 tests have **not run yet** – see HANDOVER.md.
