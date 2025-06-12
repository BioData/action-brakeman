#!/usr/bin/env bash
set -euo pipefail

if [ -n "${GITHUB_WORKSPACE:-}" ]; then
  git config --global --add safe.directory "$GITHUB_WORKSPACE" || exit 1
  git config --global --add safe.directory "$GITHUB_WORKSPACE/$INPUT_WORKDIR" || exit 1
  cd "$GITHUB_WORKSPACE/$INPUT_WORKDIR" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="$INPUT_GITHUB_TOKEN"

TEMP_PATH="$(mktemp -d)"
export PATH="$TEMP_PATH:$PATH"

# Install Brakeman
if [[ "$INPUT_SKIP_INSTALL" == "false" ]]; then
  echo "::group:: Installing Brakeman ..."

  if [[ "$INPUT_BRAKEMAN_VERSION" == "gemfile" ]]; then
    if [ -f "Gemfile.lock" ]; then
      BRAKEMAN_GEMFILE_VERSION=$(ruby -ne 'print $& if /^\s{4}brakeman\s\(\K.*(?=\))/' Gemfile.lock)
      if [ -n "$BRAKEMAN_GEMFILE_VERSION" ]; then
        BRAKEMAN_VERSION=$BRAKEMAN_GEMFILE_VERSION
      else
        echo "⚠️ Could not detect Brakeman version from Gemfile.lock. Installing latest."
        BRAKEMAN_VERSION=""
      fi
    else
      echo "⚠️ Gemfile.lock not found. Installing latest Brakeman."
      BRAKEMAN_VERSION=""
    fi
  else
    BRAKEMAN_VERSION="$INPUT_BRAKEMAN_VERSION"
  fi

  if [ -n "$BRAKEMAN_VERSION" ]; then
    gem install -N brakeman --version "$BRAKEMAN_VERSION"
  else
    gem install -N brakeman
  fi

  echo "::endgroup::"
fi

# Setup bundler exec if needed
if [[ "$INPUT_USE_BUNDLER" == "true" ]]; then
  export BUNDLE_EXEC="bundle exec "
else
  export BUNDLE_EXEC=""
fi

# Run mode-specific logic
if [[ "$INPUT_MODE" == "diff" ]]; then
  bash "$GITHUB_ACTION_PATH/run_diff.sh" "$MERGE_BASE_REF" "$MERGE_BASE_SHA" "$CHANGED_RUBY_FILES"
else
  echo "::group::🐶 Installing reviewdog ..."
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh \
    | sh -s -- -b "$TEMP_PATH" "$REVIEWDOG_VERSION"
  echo "::endgroup::"

  bash "$GITHUB_ACTION_PATH/run_full.sh"
fi
