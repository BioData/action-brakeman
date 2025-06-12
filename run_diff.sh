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

echo "🚨 Running Brakeman on current PR branch..."
${BUNDLE_EXEC}brakeman -f json --no-exit-on-warn > current.json || true

echo "🔄 Checking out base commit: $merge_base_sha"
git checkout --quiet "$merge_base_sha"

echo "🚨 Running Brakeman on base commit..."
${BUNDLE_EXEC}brakeman -f json --no-exit-on-warn > base.json || true

# Return to PR head
git checkout --quiet -

# Count warning differences
current_count=$(jq '.warnings | length' current.json)
base_count=$(jq '.warnings | length' base.json)

echo "📊 Brakeman warning count: current=$current_count, base=$base_count"

if [[ "$current_count" -le "$base_count" ]]; then
  echo "✅ No new Brakeman issues introduced."
  exit 0
fi

echo "❌ You introduced $((current_count - base_count)) new Brakeman warnings. Please fix them."
exit 1
