#!/usr/bin/env bash
set -euo pipefail

echo "::group:: Running brakeman with reviewdog 🐶 ..."
BRAKEMAN_REPORT_FILE="$(mktemp)"

# shellcheck disable=SC2086
${BUNDLE_EXEC}brakeman --quiet --format tabs --no-exit-on-warn --no-exit-on-error ${INPUT_BRAKEMAN_FLAGS} --output "$BRAKEMAN_REPORT_FILE"
reviewdog < "$BRAKEMAN_REPORT_FILE" \
  -f=brakeman \
  -name="${INPUT_TOOL_NAME}" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -fail-level="${INPUT_FAIL_LEVEL}" \
  -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
  -level="${INPUT_LEVEL}" \
  "${INPUT_REVIEWDOG_FLAGS}"

exit_code=$?
echo '::endgroup::'

exit $exit_code
