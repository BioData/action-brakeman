#!/usr/bin/env bash
set -euo pipefail

merge_base_ref="$1"
merge_base_sha="$2"
changed_files_colon="$3"

changed_files="$(echo "$changed_files_colon" | tr ':' '\n')"

echo "🔍 Base ref: $merge_base_ref"
echo "🔍 Base SHA: $merge_base_sha"
echo "📝 Changed Ruby files:"
echo "$changed_files"

echo "Fetching merge base (shallowly)..."
git fetch --depth 1 origin "$merge_base_sha"

# Normalize paths for comparison
changed_files_json=$(echo "$changed_files" | jq -R . | jq -s .)

echo "🚨 Running Brakeman on current PR branch..."
${BUNDLE_EXEC}brakeman -f json --no-exit-on-warn > current.json || true

echo "🔄 Checking out base commit: $merge_base_sha"
git checkout --quiet "$merge_base_sha"

echo "🚨 Running Brakeman on base commit..."
${BUNDLE_EXEC}brakeman -f json --no-exit-on-warn > base.json || true

git checkout --quiet -

# Filter warnings to only those in changed files
echo "📊 Comparing warnings for changed files only..."

current_count=$(jq --argjson files "$changed_files_json" '
  .warnings | map(select(.file as $f | $files | index($f))) | length' current.json)

base_count=$(jq --argjson files "$changed_files_json" '
  .warnings | map(select(.file as $f | $files | index($f))) | length' base.json)

echo "📊 Brakeman warning count (only in changed files): current=$current_count, base=$base_count"

if [[ "$current_count" -le "$base_count" ]]; then
  echo "✅ No new Brakeman issues introduced."
  exit 0
fi

echo "❌ You introduced $((current_count - base_count)) new Brakeman warnings in changed files."
exit 1

#### WORKING GOOD