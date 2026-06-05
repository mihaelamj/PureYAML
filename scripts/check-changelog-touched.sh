#!/usr/bin/env bash

set -u

BASE_REF="${BASE_REF:-origin/main}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "changelog: not in a git repository" >&2
  exit 1
fi

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    BASE_REF="HEAD^"
  else
    echo "changelog: no base ref yet, skipping initial commit gate"
    exit 0
  fi
fi

changed=$(git diff --name-only "$BASE_REF"...HEAD --)
if [ -z "$changed" ]; then
  changed=$(git diff --cached --name-only --)
fi

source_touched=0
while IFS= read -r path; do
  case "$path" in
    Sources/*|Package.swift)
      source_touched=1
      ;;
  esac
done <<EOF
$changed
EOF

if [ "$source_touched" -eq 0 ]; then
  echo "changelog: no source changes"
  exit 0
fi

if printf '%s\n' "$changed" | grep -qx 'CHANGELOG.md'; then
  echo "changelog: CHANGELOG.md updated"
  exit 0
fi

echo "changelog: source changed but CHANGELOG.md was not updated" >&2
echo "changelog: update CHANGELOG.md under Unreleased" >&2
exit 1
