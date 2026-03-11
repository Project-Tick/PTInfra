#!/usr/bin/env bash

set -euo pipefail

repo_url="${1:-https://gitlab.com/project-tick/core/projt-launcher.git}"
default_branch="${2:-main}"

latest_tag="$(
  git ls-remote --refs --tags "$repo_url" \
    | awk '{print $2}' \
    | sed 's#refs/tags/##' \
    | sort -V \
    | tail -n 1
)"

latest_commit="$(
  git ls-remote "$repo_url" "refs/heads/$default_branch" \
    | awk 'NR==1 { print $1 }'
)"

if [[ -z "$latest_commit" ]]; then
  echo "Unable to resolve HEAD for branch '$default_branch' from $repo_url" >&2
  exit 1
fi

{
  echo "latest_tag=$latest_tag"
  echo "latest_commit=$latest_commit"
} | {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    cat >> "$GITHUB_OUTPUT"
  else
    cat
  fi
}
