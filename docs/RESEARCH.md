# Open-source study (Session 1, preliminary)

Checked via GitHub API on 2026-11-06. Ideas only; no code copied (D-009).

| Project | License | Lang | Last push | Take-away | Reuse |
|---|---|---|---|---|---|
| yihong0618/bilingual_book_maker | MIT | Python | 2026-10-30 | EPUB plan, context window, glossary, bilingual output | ideas; code allowed with attribution |
| jesselau76/ebook-GPT-translator | MIT | Python | 2026-03-15 | terminology + long-book memory patterns | ideas |
| hydropix/TranslateBooksWithLLMs | AGPL-3.0 | Python | 2026-11-03 | multi-provider, resumable jobs, style presets | **study only** |
| TohmaN233/YN-translation-workshop | MIT | TypeScript | 2026-10-30 | aligned editor, AI proofreading, repair workflow | ideas |
| KazKozDev/book-translator (Tolmach) | AGPL-3.0 | Python | 2026-10-11 | shared glossaries, review desk | **study only** |
| quantmind-br/ebook-translator | – | – | – | repo not found via API (404) on 2026-11-06 | n/a |
| jjyr/meow-translate | none declared | Dart | 2026-08-23 | Dart ebook translation (0 stars) | **no license = no code reuse** |
| Mubumbutu/Ebook-Subtitle-Translator | GPL-3.0 | Python | 2026-11-04 | many formats (EPUB/SRT/PDF/DOCX/FB2) | **study only** |
| deusyu/translate-book | MIT | Python | 2026-10-29 | chunked whole-book pipeline for agents | ideas |
| PapyrusReader/reader | AGPL-3.0 | JavaScript | 2026-11-03 | e-book reading library | **study only** |

## Patterns adopted into the design
- Chunk checkpoints with input hash → resume and cache (bilingual_book_maker, TranslateBooksWithLLMs idea).
- Glossary in prompt **and** post-validation (ebook-GPT-translator, Tolmach idea).
- Aligned two-pane editor + proofreading pass (YN workshop idea).

## pdfrx / PDFium evaluation (M2b-1a, 2026-11-06)
| Question | Finding | Evidence |
|---|---|---|
| License | pdfrx, pdfrx_engine, pdfium_dart, pdfium_flutter: MIT. PDFium: BSD-3 (Google) with third-party notices. Binaries from bblanchon/pdfium-binaries. | package LICENSE files (pub.dev tarballs) |
| Android | Works in debug build (native asset hook downloads PDFium per ABI, compiles a small C gate lib with the NDK). | CI run 42158726040 Android job ✅ |
| iOS | Works in unsigned debug build (PDFium XCFramework via pdfium_flutter). Not run on simulator/device. | CI run 42158726040 iOS job ✅ |
| CI host tests | Native asset not loaded by `flutter test`; fixed by downloading PDFium and `PDFIUM_PATH`. | run 42158496970 ❌ → run 42158726040 ✅ |
| Text + coordinates | `PdfPage.loadStructuredText()` → fragments with `PdfRect` in PDF points (origin bottom-left). | pdfrx_text_source_test |
| Font per run / ToUnicode | Not in pdfrx API → own structure scanner (D-021). | code review of pdfrx_engine 0.9.1 |
| App size | Debug APK artifact +12.6 MB (all ABIs). Release/ABI-split size not measured. | artifact sizes |

## Still to research (M2)
Dart EPUB/DOCX parsers, PDF text extraction (pdfrx vs native), llama.cpp mobile bindings, OCR accuracy for Hindi.
