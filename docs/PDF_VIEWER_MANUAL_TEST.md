# Manual PDF viewer test – Engine C (M2b-3b-2c-1)

Purpose: check Hindi copy/search in viewers that CI cannot drive (Chrome's built-in viewer, Adobe Acrobat Reader, Android viewers). Automated results are in DECISIONS D-031; this checklist is for a person.

## Files
Download the CI artifact `pdf-export-probe-engine-c-interop` from the latest `pdf-export-probe` run of the M2b-3b-2c-1 branch (GitHub login needed). Use `pdf/`:

| file | text | what it tests |
|---|---|---|
| `c01_kitab_word.pdf` | किताब | i-matra drawn before क |
| `c02_kshetra_word.pdf` | क्षेत्र | conjunct ligatures + e-matra |
| `c03_rashtra_mixed_word.pdf` | राष्ट्र धर्म India 123 | conjuncts, reph, Hindi + Latin + digits |
| `c03_rashtra_mixed_word_clustertu.pdf` | same | experiment: Latin also has ToUnicode |

Do not normalise or edit the files. Compare with the exact source text above.

## Steps (per viewer, per file)
1. Open the PDF. Note app name, exact version, OS/device.
2. Visual: letters look exactly like the source text (i-matra left of क, क्ष / त्र / ष्ट्र conjuncts, reph above म).
3. Select all text (or long-press → Select all) and copy.
4. Paste into a plain-text note. Compare letter by letter with the source. Note: missing matra, extra space, duplicated letter, wrong order, boxes/garbage.
5. Search (Ctrl+F / Find in page) for each word: `किताब`, `क्षेत्र`, `राष्ट्र`, `धर्म`, `India`, `123`. Note found / not found.
6. Record PASS (exact copy and all words found), PARTIAL, or FAIL with what you saw. Screenshots welcome.

## Viewers wanted
- Google Chrome (desktop) built-in PDF viewer
- Adobe Acrobat Reader (desktop or Android)
- Android: Google Drive PDF viewer / Files app viewer / any installed reader (name + version)
- Firefox is automated in CI (built-in PDF.js) – a manual check is optional.
