#!/usr/bin/env bash
# Rejects commit messages that don't follow Conventional Commits.
# Run by lefthook's commit-msg hook with the message file as $1.
# With --pr-title, checks a PR title instead (CI): squash merging makes the
# title the commit on main, so it follows the same rules.
set -euo pipefail

pr_title=false
if [[ ${1:-} == --pr-title ]]; then
  pr_title=true
  shift
fi

subject=$(head -n 1 "$1")

# Messages git generates: merges, reverts, and fixup/squash/amend commits.
# A PR title is always written by hand, so it gets no exemption.
if ! $pr_title && [[ $subject =~ ^(Merge|Revert\ \"|fixup!|squash!|amend!) ]]; then
  exit 0
fi

source "$(dirname "$0")/../commit-types.sh"
pattern="^($types)(\([a-z0-9-]+\))?!?: [^A-Z ](.*[^.])?$"

if $pr_title; then
  kind='PR title'
  retry='Edit the PR title; this check reruns automatically.'
else
  kind='Commit message'
  retry='Nothing was committed. Edit your saved message and commit again:
  git commit -e -F .git/COMMIT_EDITMSG'
fi

if [[ ! $subject =~ $pattern ]]; then
  cat >&2 <<MSG
$kind doesn't follow Conventional Commits:

  $subject

Expected: <type>(optional scope)!: <description>
  types: ${types//|/, }
  scope: lowercase letters, digits and hyphens
  !: optional, marks a breaking change
  description: starts lowercase, no trailing period
Example: feat(chat): add message list

$retry
MSG
  exit 1
fi

if (( ${#subject} > 72 )); then
  cat >&2 <<MSG
$kind is ${#subject} characters; the limit is 72:

  $subject

Shorten it and move details to the body or description.
$retry
MSG
  exit 1
fi
