#!/usr/bin/env bash
set -euo pipefail

# Prefer container paths when present, fall back to host-relative
if [ -d /config/www/files ]; then
  BOOKSTACK_FILES="/config/www/files"
  BOOKSTACK_IMAGES="/config/www/images"
  LOGSEQ_ASSETS="${LOGSEQ_ASSETS:-/logseq-graph/assets}"
  LOGSEQ_PAGES="${LOGSEQ_PAGES:-/logseq-graph/pages}"
else
  BOOKSTACK_FILES="${BOOKSTACK_FILES:-./data/bookstack/config/www/files}"
  BOOKSTACK_IMAGES="${BOOKSTACK_IMAGES:-./data/bookstack/config/www/images}"
  LOGSEQ_ASSETS="${LOGSEQ_ASSETS:-./data/logseq/graph/assets}"
  LOGSEQ_PAGES="${LOGSEQ_PAGES:-./data/logseq/graph/pages}"
fi

INDEX_PAGE="${LOGSEQ_PAGES}/BookStack Mirror.md"
mkdir -p "$LOGSEQ_ASSETS" "$LOGSEQ_PAGES"

echo "[sync] Copying attachments..."
if [ -d "$BOOKSTACK_FILES" ]; then
  find "$BOOKSTACK_FILES" -type f \( -name '*.pdf' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.webp' -o -name '*.bcfzip' -o -name '*.json' \) \
    -exec cp -u {} "$LOGSEQ_ASSETS/" \;
fi

echo "[sync] Copying images..."
if [ -d "$BOOKSTACK_IMAGES" ]; then
  find "$BOOKSTACK_IMAGES" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.webp' -o -name '*.svg' \) \
    -exec cp -u {} "$LOGSEQ_ASSETS/" \;
fi

echo "[sync] Updating index page..."
{
  echo "- # BookStack Mirror"
  echo "- Auto-generated $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- ## Attachments & Images"
  find "$LOGSEQ_ASSETS" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort | while read -r f; do
    echo "  - [[assets/$f]]"
  done
} > "$INDEX_PAGE"

echo "[sync] Done."
