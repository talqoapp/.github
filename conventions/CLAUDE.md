# Talqo conventions

Shared by every Talqo repo, imported from each repo's CLAUDE.md. The source
is talqoapp/.github; change the rules there, never in a copy.

## Git

- Branches: `<type>/<optional-issue-number->short-description`, e.g.
  `feat/12-sign-in`, using the commit types below.
- Work on a branch and land it through a PR; `main` only changes by merging a PR.
- PRs are squash-merged, so the PR title becomes the commit on `main` and
  follows the commit rules below.
- lefthook runs the shared git hooks (commit message, branch name, no pushes
  to `main`) plus each repo's own. When a hook rejects something, fix the
  cause it reports and retry. Never bypass a hook with `--no-verify`.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(optional scope): <description>

[optional body: why the change was made]

[optional footer(s)]
```

- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`,
  `ci`, `build`, `revert`.
- Subject: imperative mood ("add", not "added"), lowercase, no trailing
  period, ideally under 50 characters, never over 72. It says what changes
  in behaviour; details go in the body.
- Body: explain why, not what; the diff shows what. Wrap at 72 characters.
- Breaking changes: `!` after the type (`feat!: ...`) or a
  `BREAKING CHANGE:` footer.
- One logical change per commit.
- Write the message after the change is final.
- Only commit when asked.
- Commits and PR descriptions carry only the human author: no `Co-Authored-By`
  or other AI attribution trailers.

## Pull request descriptions

Write for a reviewer who hasn't seen the work: readable in under a minute.
The diff already shows *what* changed; spend words on *why*. CI checks the
summary, Commits and Testing parts exist.

Sections, in order (skip an empty optional one):

1. **Summary**: 1–2 sentences on what changes for the user or system, and
   why. `Closes #<issue>` when there is one.
2. **Diagram** (optional): when the change adds or alters a flow or structure
   (request path, component interactions, state changes), a small Mermaid
   diagram of it. Show only what this PR changes; aim for under 10 nodes.
3. **Commits**: every commit on the branch, oldest first
   (`git log --reverse --format='%h %s' main..HEAD`), each as
   ``- [`<subject>`](<repo url>/commit/<sha>)``; get the repo URL with
   `gh repo view --json url -q .url`.
   - A one-line explanation only when the subject isn't self-explanatory.
   - A `Why:` line for each decision a reviewer might question: the choice,
     the alternative passed over, and the reason, in one line. Example:
     `Why: httptest.NewRecorder over NewServer, because the handler runs in-process with no port, and the response is inspectable directly.`
     A reason that needs a paragraph belongs in a code comment or the commit body.
4. **Testing**: the commands run and manual checks done.
5. **Notes** (optional): deploy steps, config to set, known gaps, follow-ups.

Done when every commit is listed and every non-obvious decision has a `Why:`.
Commit SHAs change on rebase or squash, so regenerate the list after a force-push.
