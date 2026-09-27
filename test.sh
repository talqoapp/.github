#!/usr/bin/env bash
# Table-driven test for the shared rules. Hooks run through `lefthook run`, so
# hooks/lefthook.yml and the scripts are tested together; the real-push cases
# consume this repo as a lefthook remote, the way the other repos do.
# Usage: ./test.sh (from the repo root; needs lefthook v2)
set -uo pipefail

repo_root=$(cd "$(dirname "$0")" && pwd)
zero=0000000000000000000000000000000000000000
sha=1111111111111111111111111111111111111111
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
passed=0
failed=0

# check <expected: pass|fail> <description> <command...>
check() {
  local expected=$1 description=$2
  shift 2
  local output actual
  if output=$("$@" 2>&1); then actual=pass; else actual=fail; fi
  if [[ $actual == "$expected" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $description (expected $expected, got $actual)"
    echo "$output" | sed 's/^/    /'
  fi
}

commit_msg() {
  printf '%s\n' "$1" > "$tmp/msg"
  lefthook run commit-msg "$tmp/msg" --no-auto-install --no-tty --colors off
}

pr_title() {
  printf '%s\n' "$1" > "$tmp/title"
  "$repo_root/hooks/commit-msg/check-commit-msg.sh" --pr-title "$tmp/title"
}

pr_body() {
  printf '%s\n' "$1" > "$tmp/body"
  "$repo_root/ci/check-pr-body.sh" "$tmp/body"
}

# Takes one or more "<local ref> <local sha> <remote ref> <remote sha>" lines.
pre_push() {
  printf '%s\n' "$@" | lefthook run pre-push --job "branch rules" \
    --no-auto-install --no-tty --colors off
}

cd "$repo_root" || exit 1
long_72="feat: $(printf 'a%.0s' {1..66})"
long_73="feat: $(printf 'a%.0s' {1..67})"

# commit-msg
check pass "type and description" commit_msg "feat: add login screen"
check pass "scope" commit_msg "fix(auth-api): handle expired tokens"
check pass "breaking change" commit_msg "feat!: drop android 7 support"
check pass "scope and breaking change" commit_msg "refactor(chat)!: rename message model"
check pass "revert type" commit_msg "revert: undo login screen"
check pass "subject of exactly 72 characters" commit_msg "$long_72"
check pass "git merge" commit_msg "Merge branch 'main' into feat/login-screen"
check pass "git revert" commit_msg 'Revert "feat: add login screen"'
check pass "fixup commit" commit_msg "fixup! feat: add login screen"
check pass "squash commit" commit_msg "squash! feat: add login screen"
check pass "amend commit" commit_msg "amend! feat: add login screen"
check fail "not a conventional commit" commit_msg "Added the login screen"
check fail "uppercase description" commit_msg "feat: Add login screen"
check fail "trailing period" commit_msg "feat: add login screen."
check fail "unknown type" commit_msg "feature: add login screen"
check fail "uppercase scope" commit_msg "feat(Auth): add login screen"
check fail "no space after colon" commit_msg "feat:add login screen"
check fail "empty description" commit_msg "feat: "
check fail "subject over 72 characters" commit_msg "$long_73"

# PR titles: the same rules, without the exemptions for git-generated messages
check pass "PR title" pr_title "feat(chat): add message list"
check fail "PR title not conventional" pr_title "Add message list"
check fail "PR title over 72 characters" pr_title "$long_73"
check fail "PR title from GitHub's revert button" pr_title 'Revert "feat: add login screen"'
check fail "PR title like a merge" pr_title "Merge branch 'main' into feat/login-screen"

# PR descriptions
check pass "complete description" pr_body "Adds sign-in.

## Commits

- [\`feat: add sign-in\`](https://github.com/talqoapp/x/commit/abc1234)

## Testing

- make test"
check pass "Windows line endings" pr_body $'Adds sign-in.\r\n\r\n## Commits\r\n\r\n- [`feat: add sign-in`](u)\r\n\r\n## Testing\r\n\r\n- make test\r'
check fail "untouched template" pr_body "$(cat "$repo_root/pull_request_template.md")"
check fail "empty description" pr_body ""
check fail "summary only in a comment" pr_body "<!-- Adds sign-in. -->

## Commits

- [\`feat: add sign-in\`](u)

## Testing

- make test"
check fail "no commit listed" pr_body "Adds sign-in.

## Commits

## Testing

- make test"
check fail "no testing section" pr_body "Adds sign-in.

## Commits

- [\`feat: add sign-in\`](u)"
check fail "testing section empty" pr_body "Adds sign-in.

## Commits

- [\`feat: add sign-in\`](u)

## Testing

<!-- Commands run and manual checks done. -->

## Notes

- none"

# pre-push branch rules
check pass "first push creating main" pre_push "refs/heads/main $sha refs/heads/main $zero"
check fail "push updating main" pre_push "refs/heads/main $sha refs/heads/main $sha"
check pass "branch without issue number" pre_push "refs/heads/x $sha refs/heads/feat/login-screen $zero"
check pass "branch with issue number" pre_push "refs/heads/x $sha refs/heads/fix/12-chat-crash $zero"
check fail "branch without type" pre_push "refs/heads/x $sha refs/heads/login-screen $zero"
check fail "branch with unknown type" pre_push "refs/heads/x $sha refs/heads/feature/login-screen $zero"
check fail "branch with uppercase" pre_push "refs/heads/x $sha refs/heads/feat/Login-Screen $zero"
check pass "deleting a remote branch" pre_push "(delete) $zero refs/heads/Old_Branch $sha"
check pass "pushing a tag" pre_push "refs/tags/v1.0.0 $sha refs/tags/v1.0.0 $zero"
check fail "one bad ref among good ones" pre_push \
  "refs/heads/x $sha refs/heads/feat/login-screen $zero" \
  "refs/heads/y $sha refs/heads/Bad_Branch $zero"

# A repo that uses this one as a lefthook remote, as the other Talqo repos do.
# Real pushes also cover what the cases above can't reach: lefthook skips
# pre-push `run` jobs when the current branch has no changes against its
# upstream, e.g. `git push origin feat/x:main` right after pushing feat/x.
consumer_setup() {
  # A snapshot of the working tree, so uncommitted changes are what's tested.
  mkdir -p "$tmp/shared"
  cp -r "$repo_root/hooks" "$repo_root/ci" "$tmp/shared/"
  git -C "$tmp/shared" init -q -b main
  git -C "$tmp/shared" add -A
  git -C "$tmp/shared" -c user.name=test -c user.email=test@example.com \
    commit -qm "chore: snapshot"

  mkdir -p "$tmp/remote.git" "$tmp/work"
  git init -q --bare "$tmp/remote.git"
  cd "$tmp/work" || exit 1
  git init -q -b main
  git config user.name test
  git config user.email test@example.com
  cat > lefthook.yml <<YML
remotes:
  - git_url: $tmp/shared
    ref: main
    configs: [hooks/lefthook.yml]
YML
  git remote add origin "$tmp/remote.git"
  lefthook install > /dev/null
  git add -A
  git commit -qm "chore: initial commit"
  git push -q origin main
  git switch -q -c feat/change
  echo change > change.txt
  git add change.txt
  git commit -qm "feat: add change"
  git push -q -u origin feat/change
}

consumer_commit() {
  git commit -q --allow-empty -m "$1"
}

real_push() {
  git push -q origin "$1"
}

(
  consumer_setup > /dev/null 2>&1 || { echo "FAIL: consumer repo setup"; exit 1; }
  check fail "remote hooks reject a bad commit message" consumer_commit "Added stuff"
  check pass "remote hooks accept a good commit message" consumer_commit "chore: add stuff"
  check fail "pushing an already-pushed commit to main" real_push feat/change:main
  check fail "pushing an already-pushed commit to a badly named branch" real_push feat/change:Bad_Name
  check pass "pushing an already-pushed commit to a valid branch" real_push feat/change:fix/other-name
  echo "$passed $failed" > "$tmp/counts"
)
read -r passed failed < "$tmp/counts" 2> /dev/null || failed=$((failed + 1))

echo "$passed passed, $failed failed"
(( failed == 0 ))
