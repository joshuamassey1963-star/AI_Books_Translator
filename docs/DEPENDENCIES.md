# Dependencies

Checked 2026-11-06 against pub.dev (latest version, SDK constraint, license, likes, pub points). Only rows marked **In use** are in `pubspec.yaml`.

## In use (Session 1)
| Package | Version | License | Why | Notes |
|---|---|---|---|---|
| flutter (SDK) | 3.47.9 stable / Dart 3.13.7 | BSD-3 | UI | pinned in CI |
| flutter_riverpod | ^3.4.3 | MIT | state/DI | 2918 likes, 140/160 pts |
| go_router | ^18.1.3 | BSD-3 | routing | needs Flutter ≥3.44 |
| flutter_lints (dev) | ^6.0.0 | BSD-3 | lints | |
| flutter_test, integration_test (dev) | SDK | BSD-3 | tests | |

## Candidates (add in the milestone that needs them, re-check then)
| Package | Latest | License | Milestone | Status |
|---|---|---|---|---|
| drift / drift_dev / drift_flutter | 2.35.3 / 2.35.2 / 0.3.1 | MIT | V1-A | candidate |
| sqlite3 | 3.9.0 | MIT | V1-A | candidate (`sqlite3_flutter_libs` is EOL) |
| flutter_secure_storage | 11.2.0 | BSD-3 | V1-A | candidate (Keystore/Keychain) |
| dio | 5.11.1 | MIT | V1-C | candidate |
| file_picker | 13.3.2 | MIT | V1-B | candidate (SAF / document picker) |
| archive | ^4.6.0 | MIT | V1-B | **in use since M2** (EPUB/DOCX zip, in-memory only) |
| xml | ^7.1.0 | MIT | V1-B | **in use since M2** (needs Dart >=3.13, pubspec sdk ^3.13.0) |
| crypto | ^3.0.8 | BSD-3 | V1-B | **in use since M2** (SHA-256 fingerprint) |
| uuid | 4.6.0 | MIT | V1-A | candidate |
| path_provider | 2.1.6 | BSD-3 | V1-A | candidate |
| pdf | 3.13.1 | Apache-2.0 | V1-E | candidate (Hindi PDF + font embedding) |
| printing | 5.15.1 | Apache-2.0 | V1-E | optional |
| pdfrx | 2.12.0 | MIT | P0 spike | evaluate for PDF text extraction |
| workmanager | 0.10.10 | MIT | V1-D | candidate (Android background) |
| flutter_local_notifications | 22.3.3 | BSD-3 | V1-D | consent-gated |
| freezed / json_serializable | 4.0.3 / 6.15.2 | MIT / BSD-3 | V1-A | optional codegen |
| riverpod_generator / riverpod_annotation | 4.0.9 / 4.0.7 | MIT | later | optional |
| mocktail (dev) | 1.0.5 | MIT | V1-A | candidate |
| google_mlkit_text_recognition | 1.0.0 | MIT | V2-A | candidate (Android+iOS) |
| sentry_flutter | 10.3.0 | MIT | later | opt-in only, privacy review first |

## Rejected / avoid
| Package | Reason |
|---|---|
| epubx 4.0.0 | last published 2023-06-30 |
| docx_template 0.4.0 | last published 2023-09-21; template-only |
| syncfusion_flutter_pdf | commercial licence |
| sqlite3_flutter_libs 0.6.0+eol | end of life |

## Third-party code copied
None.
