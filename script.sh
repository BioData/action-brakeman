#!/usr/bin/env bash

if [[ "$INPUT_MODE" == "diff" ]]; then
  bash "$GITHUB_ACTION_PATH/ci/run_diff.sh" "$MERGE_BASE_REF" "$MERGE_BASE_SHA" "$CHANGED_RUBY_FILES"
else
  bash "$GITHUB_ACTION_PATH/ci/run_full.sh"
fi
