# Owner requests log

Ideas and wishes from the owner, with where they landed in the Feature Matrix. Newest first.

| Date | Request (owner's words, translated) | Feature IDs | Version | Notes |
|---|---|---|---|---|
| 2026-11-06 (S5) | System-wide translation: paste text, background queue (V1); share, selected text, clipboard on tap, URL/article, floating bubble (V2); optional accessibility, advanced webpage (V3) | V1-STR-01/02, V2-STR-01..07, V3-STR-01/02 | V1–V3 | docs/SYSTEM_TRANSLATION.md; no universal cross-app access; accessibility never required; D-022 |
| 2026-11-06 (S5) | Read Aloud / TTS: system TTS Hindi+English, scopes, controls, position, background, BYOK AI TTS architecture (V1); AI providers, caching, highlighting, export, quota (V2); bilingual, multi-voice, customisation (V3) | V1-TTS-01..09, V2-TTS-01..06, V3-TTS-01..03 | V1–V3 | docs/READ_ALOUD_TTS.md; reads L2/L4 validated text only; D-023 |
| 2026-11-06 | Image customisation: logo/branding, app background, book covers, reader/editor background, with fit/opacity/dim/reset/cache/theme compatibility and safe processing | V1-IMG-01..05 | V1 | Answers the earlier open "images" question |
| 2026-11-06 | Local profile picture without login | V2-IMG-01 | V2 | |
| 2026-11-06 | Account profile picture sync; alternate app icons where supported | V3-IMG-01, V3-IMG-02 | V3 | iOS shows a system alert on icon change; only bundled icons possible |
| 2026-11-06 | 40 Hindi + 20 English fonts tested and supported; correct Devanagari, mixed text, Sanskrit, PDF font detection, missing-font warnings | V1-FNT-01..06 | V1 | Test matrix in TEXT_ENCODING_FONT_COMPATIBILITY.md; support = test results, not names |
| 2026-11-06 | Legacy Hindi font conversion (Walkman-Chanakya905, Kruti Dev, Chanakya) | V1-LEG-01..08 | V1 | Regression RC-001..004 |
| 2026-11-06 | PDF extraction and word mapping checks (reading order, CMap, ligatures, headers, columns, footnotes) + quality gate | V1-PDF-01..07 | V1 | |
| 2026-11-06 | Character encoding handling (UTF-8/BOM/UTF-16, NFC, invalid bytes, legacy detection, preview) | V1-ENC-01..05 | V1 | UTF-16 currently fails (RC-012) |
| 2026-11-06 | OCR quality: detection + interface in V1; Hindi/English/mixed, region, editor, confidence, cache, searchable PDF in V2 | V1-OCR-01..04, V2-OCR-05..09 (+ existing V2-OCR-01/03) | V1 / V2 | |
| 2026-11-06 | Hindi PDF export must pass 10 checks; compare alternative engines | V1-EXP-06, V1-EXP-07 (+ V1-EXP-04) | V1 | Release blocker (D-019) |
| 2026-11-06 | Translation text protection (alignment, foreign-script reference words, digits, versions) | V1-TRP-01..05 | V1 | |
| 2026-11-06 | Split M2b into M2b-1..5 | ROADMAP | – | D-020 |
| 2026-11-06 | Colours/themes: Day, Night, Sepia – three modes | V1-SET-02 | V1 | Also applies to reader/editor text area |
| 2026-11-06 | Rotate mode | V1-SET-03 | V1 | Auto / portrait / landscape lock |
| 2026-11-06 | Login mode with work history | V1-HIS-01 (local history), V3-SYN-03 (login + sync) | V1 / V3 | Roadmap rule: V1 needs no account. History is local in V1; optional login/sync later. Owner can move login earlier. |
| 2026-11-06 | Images / app visuals customisation | V1-IMG-01..05 | V1 | Clarified by owner the same day (rows above) |

## Manual checks by owner
- 2026-11-06: Owner installed CI debug APK (run 42149165709) on an Android phone. Bottom tabs and More list open; screens show "Not available yet" as designed (screenshots shared in chat).
