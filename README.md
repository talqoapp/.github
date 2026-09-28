# talqoapp/.github

The single source of the conventions every Talqo repo follows: commit
messages, branch names, PR titles and PR descriptions. Change a rule here
once, and every repo picks it up.

This repo is public: GitHub only applies an org-wide PR template from a public
`.github` repo. It holds conventions only, never product code or secrets.

## What's here

| Path | What it does | How repos get it |
|---|---|---|
| `pull_request_template.md` | Pre-fills every new PR's description | Automatically, for any repo without its own template |
| `hooks/` | Git hooks: commit messages, branch names, no pushes to `main` | lefthook `remotes`, refetched daily |
| `.github/workflows/pr-conventions.yml` | CI check of the PR title and description | A 10-line `pr.yml` in each repo |
| `conventions/CLAUDE.md` | The rules, written for Claude Code | An `@` import in each repo's CLAUDE.md |

## Setup (once per machine)

Clone this repo next to the other Talqo repos; the CLAUDE.md imports expect it
there:

```
talqo-project/
├── .github/          ← this repo
├── talqo/
├── talqo-backend/
└── talqo-infra/
```

Install [lefthook](https://lefthook.dev) (`brew install lefthook` or
`sudo snap install --classic lefthook`), then run `lefthook install` in each
repo.

## Using it in a repo

1. **Hooks**: in the repo's `lefthook.yml`, next to its own jobs:

   ```yaml
   remotes:
     - git_url: https://github.com/talqoapp/.github
       ref: main
       configs: [hooks/lefthook.yml]
       refetch_frequency: 24h
   ```

2. **CI**: `.github/workflows/pr.yml`:

   ```yaml
   name: PR

   on:
     pull_request:
       types: [opened, edited, reopened]

   permissions:
     contents: read

   jobs:
     conventions:
       uses: talqoapp/.github/.github/workflows/pr-conventions.yml@main
   ```

3. **Claude**: first line of the repo's `CLAUDE.md`:

   ```markdown
   @../.github/conventions/CLAUDE.md
   ```

4. **PR template**: delete the repo's own `.github/pull_request_template.md`,
   so the org-wide one applies.

## Changing a rule

Open a PR here. `./test.sh` runs the hooks and PR checks against a table of
cases, including a repo that consumes this one as a lefthook remote; CI runs it
too. Add a case for the rule you change. After merging, repos get the new hooks
within a day (`lefthook install` fetches them now), and CI and the template
straight away.

On GitHub Free, nothing here can block a merge: the hooks can be skipped with
`--no-verify`, and a failing PR check shows a red ❌ but doesn't stop merging.
