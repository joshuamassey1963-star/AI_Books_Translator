#!/usr/bin/env bash
# Downloads the OFL-1.1 Noto fonts used by the PDF export probe (M2b-3a).
# Fonts are NOT committed to git; hashes are pinned in fonts.sha256.
set -euo pipefail
OUT="${1:?usage: fetch_fonts.sh <dir>}"
BASE="https://raw.githubusercontent.com/notofonts/notofonts.github.io/main/fonts"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
declare -A PATHS=(
  [NotoSerifDevanagari-Regular.ttf]="NotoSerifDevanagari/hinted/ttf"
  [NotoSerifDevanagari-Bold.ttf]="NotoSerifDevanagari/hinted/ttf"
  [NotoSerif-Regular.ttf]="NotoSerif/hinted/ttf"
  [NotoSerifHebrew-Regular.ttf]="NotoSerifHebrew/hinted/ttf"
)
for f in "${!PATHS[@]}"; do
  curl -fsSL --retry 3 -o "$OUT/$f" "$BASE/${PATHS[$f]}/$f"
done
(cd "$OUT" && sha256sum -c "$HERE/fonts.sha256")
