#!/usr/bin/env bash
# Rejects PR descriptions missing the parts every Talqo PR needs: a summary,
# a "## Commits" list and a "## Testing" section (see conventions/CLAUDE.md).
# Usage: check-pr-body.sh <file with the PR description>
set -euo pipefail

# Template hints are HTML comments; GitHub hides them, so they don't count.
body=$(perl -0pe 's/<!--.*?-->//gs; s/\r//g' "$1")

# Prints the lines under a "## <name>" heading, up to the next "## " heading.
section() {
  awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on' <<< "$body"
}

problems=()
summary=$(awk '/^## / { exit } { print }' <<< "$body")
[[ $summary =~ [^[:space:]] ]] || problems+=("a summary above the first heading: 1–2 sentences on what changes and why")
grep -qx '## Commits' <<< "$body" || problems+=("a \"## Commits\" heading")
section Commits | grep -q '^- ' || problems+=("at least one commit under \"## Commits\", as \"- [\`<subject>\`](<commit url>)\"")
grep -qx '## Testing' <<< "$body" || problems+=("a \"## Testing\" heading")
[[ $(section Testing) =~ [^[:space:]] ]] || problems+=("the commands run or checks done, under \"## Testing\"")

if (( ${#problems[@]} )); then
  echo "PR description is missing:" >&2
  printf '  - %s\n' "${problems[@]}" >&2
  echo "Edit the PR description; this check reruns automatically. Format: conventions/CLAUDE.md in talqoapp/.github." >&2
  exit 1
fi
