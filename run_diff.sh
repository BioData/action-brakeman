#!/usr/bin/env bash
set -euo pipefail

merge_base_ref="$1"
merge_base_sha="$2"
changed_files_csv="$3"

IFS=',' read -r -a changed_files_array <<< "$changed_files_csv"

echo "🔍 Base ref: $merge_base_ref"
echo "🔍 Base SHA: $merge_base_sha"
echo "📝 Changed Ruby files:"
printf '%s\n' "${changed_files_array[@]}"

echo "📥 Fetching base commit..."
git fetch --depth 1 origin "$merge_base_sha"

# Filter existing files on current branch
existing_current=()
for file in "${changed_files_array[@]}"; do
  if [[ -f "$file" ]]; then
    existing_current+=("$file")
  fi
done

if [[ "${#existing_current[@]}" -eq 0 ]]; then
  echo "⚠️ No changed Ruby files exist on current branch. Skipping Brakeman."
  exit 0
fi

current_csv="$(IFS=','; echo "${existing_current[*]}")"

# Run Brakeman on current branch
echo "🚨 Running Brakeman on current PR branch (only changed files)..."
${BUNDLE_EXEC}brakeman --no-exit-on-warn -f json --only-files "$current_csv" > current.json || true

# Checkout base commit
echo "🔄 Checking out base commit: $merge_base_sha"
git checkout --quiet "$merge_base_sha"

# Filter existing files on base branch
existing_base=()
for file in "${changed_files_array[@]}"; do
  if [[ -f "$file" ]]; then
    existing_base+=("$file")
  fi
done

if [[ "${#existing_base[@]}" -eq 0 ]]; then
  echo "⚠️ No changed Ruby files exist on base branch. Skipping Brakeman."
  exit 0
fi

base_csv="$(IFS=','; echo "${existing_base[*]}")"

# Run Brakeman on base commit
echo "🚨 Running Brakeman on base commit (only changed files)..."
${BUNDLE_EXEC}brakeman --no-exit-on-warn -f json --only-files "$base_csv" > base.json || true

# Go back to PR HEAD
git checkout --quiet -

# Compare JSONs
current_count=$(jq '.warnings | length' current.json)
base_count=$(jq '.warnings | length' base.json)

echo "📊 Brakeman warning count (only in changed files): current=$current_count, base=$base_count"

if [[ "$current_count" -le "$base_count" ]]; then
  echo "✅ No new Brakeman issues introduced."
  exit 0
fi

echo "❌ You introduced $((current_count - base_count)) new Brakeman warnings in changed files."
exit 1
