#!/usr/bin/env bash
# Blocks pushes to main and branch names that break the naming convention.
# Called by lefthook's pre-push hook; git sends one line per pushed ref on
# stdin: <local ref> <local sha> <remote ref> <remote sha>
set -euo pipefail

source "$(dirname "$0")/../commit-types.sh"
branch_pattern="^($types)/([0-9]+-)?[a-z0-9]+(-[a-z0-9]+)*$"
zero_sha='0000000000000000000000000000000000000000'
failed=0

while read -r _ local_sha remote_ref remote_sha; do
  # Deleting a remote branch: nothing to check.
  [[ $local_sha == "$zero_sha" ]] && continue
  # Tags and other non-branch refs.
  [[ $remote_ref == refs/heads/* ]] || continue
  branch=${remote_ref#refs/heads/}

  if [[ $branch == main ]]; then
    # The very first push creates main on the remote; allow only that.
    [[ $remote_sha == "$zero_sha" ]] && continue
    cat >&2 <<MSG
Pushing to main is not allowed; main only changes by merging a PR.

Move your commits to a branch and push that instead:
  git switch -c <type>/<optional-issue-number->short-description
  git push -u origin HEAD
MSG
    failed=1
  elif [[ ! $branch =~ $branch_pattern ]]; then
    cat >&2 <<MSG
Branch name '$branch' doesn't follow the convention:

  <type>/<optional-issue-number->short-description
  types: ${types//|/, }
  description: lowercase letters, digits and hyphens
Examples: feat/login-screen, fix/12-chat-crash

Rename it with: git branch -m <new-name>
MSG
    failed=1
  fi
done

exit $failed
