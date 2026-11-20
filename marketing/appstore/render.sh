#!/usr/bin/env bash
# Renders each panel of index.html to out/iphone-6.9/NN-name.png (1320 × 2868).
# Requires Google Chrome and ImageMagick.
set -euo pipefail
cd "$(dirname "$0")"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="out/iphone-6.9"
NAMES=(hero pointer thumb timer arrange watch offline)

mkdir -p "$OUT" out/iphone-6.5 out/iphone-6.3
for i in "${!NAMES[@]}"; do
  n=$((i + 1))
  file="$OUT/$(printf '%02d' "$n")-${NAMES[$i]}.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=1320,2868 --virtual-time-budget=3000 \
    --screenshot="$PWD/$file" "file://$PWD/index.html?p=$n" >/dev/null 2>&1
  # App Store Connect rejects PNGs with an alpha channel
  magick "$file" -background black -alpha remove -alpha off "$file"
  # 6.5" set (1284 × 2778): same art, trimmed 4 px top and bottom after scaling
  magick "$file" -resize 1284x -gravity center -crop 1284x2778+0+0 +repage "out/iphone-6.5/$(basename "$file")"
  # 6.3" set (1206 × 2622): the size App Store Connect's "Dynamic Island iPhone (medium)" slot takes
  magick "$file" -resize x2622 -gravity center -crop 1206x2622+0+0 +repage "out/iphone-6.3/$(basename "$file")"
  echo "  $file"
done

magick montage "$OUT"/*.png -tile 7x1 -geometry 440x956+16+16 -background '#1c1c1e' out/overview.png
echo "✅ $(ls "$OUT" | wc -l | tr -d ' ') panels → $OUT (overview: out/overview.png)"
