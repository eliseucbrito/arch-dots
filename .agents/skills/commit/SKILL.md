---
name: commit
description: "Git commit with conventional commits, optional draft PR/MR. Detects GitHub (gh) vs GitLab (glab) and opens the right kind of request. Small, incremental, human-written messages. Never mentions AI, agents, or Claude. Use when: commit, commit this, save changes, git commit, stage and commit, create PR, open PR, draft PR, create MR, open MR, merge request, draft MR."
---

# Commit

Small, incremental git commits following conventional commits. Optionally open a draft pull request (GitHub) or merge request (GitLab).

## Usage

- `/commit` - commit staged changes
- `/commit detailed` - multi-paragraph commit
- `/commit --pr` - commit + open/update a draft PR (GitHub) or draft MR (GitLab)

`--mr` is an accepted alias for `--pr`. The skill picks the right tool from the remote either way.

## Commit Format

```
<type>(<scope>): <short description>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `chore`, `docs`
**Scope:** optional, module or area name (e.g. `feat(auth): add token refresh`)

## Modes

### Quick (default)

Single-line commit message.

```bash
git commit -m "feat(auth): add token refresh"
```

### Detailed (`detailed` or when the change is significant)

Multi-paragraph for milestone features, non-obvious fixes, architectural changes.

Output the proposed message as plain text for review. **Do NOT run `git commit` until the user approves.**

```bash
git commit -m "feat(auth): add token refresh on expiry

Tokens are now refreshed automatically when they expire.
Refresh failures fall back to re-authentication instead of
silently failing the request."
```

## Commit Rules

1. **Stage explicitly** — `git add <files>`, never `git add -A` or `git add .`
2. **Concise** — present tense imperative ("add" not "added")
3. **Lowercase** after prefix
4. **No AI mentions** — never reference Claude, AI, agents, copilot, or assistants
5. **No Co-Authored-By** — never add Co-Authored-By trailers
6. **No emojis** in commit messages
7. **Human voice** — write like a developer wrote it by hand
8. **Small commits** — one logical change per commit. During TDD: commit after each RED-GREEN-REFACTOR cycle

## Pre-commit

Before committing, run the project's test suite. Check what's available:

```bash
# Try common test commands
make test 2>/dev/null || mix test 2>/dev/null || cargo test 2>/dev/null || bundle exec rspec 2>/dev/null || npm test 2>/dev/null
```

Check the diff before staging:

```bash
git diff
git diff --staged
```

## Commit Examples

```
test(auth): add token expiration edge cases
feat(api): add webhook endpoint for events
fix(worker): handle nil payload on retry
refactor(store): extract state operations into module
docs(readme): add setup instructions for local dev
chore(ci): add type checking to CI pipeline
```

---

## Draft PR / MR (`--pr`)

When called with `--pr` (or `--mr`), commit any pending changes first, then open or update a draft request on whichever forge the remote points at.

### Pick the forge first

The commit rules are identical everywhere; only the request-creation commands differ. Detect the host once, up front, so the rest of the workflow uses the right CLI:

```bash
git remote get-url origin
```

- Host contains `github.com` (or `gh auth status` succeeds against it) → **GitHub**, use `gh`, terminology is **pull request (PR)**.
- Host contains `gitlab.` (public GitLab or a self-hosted instance) → **GitLab**, use `glab`, terminology is **merge request (MR)**.

If the host is ambiguous (a self-hosted domain that names neither), check which CLI is authenticated for it: `gh auth status` vs `glab auth status`. If still unclear, ask the user which forge this remote is.

Everything below is written twice where the commands diverge. Follow the column that matches the detected forge.

### PR/MR Workflow

#### 1. Ensure feature branch

```bash
git branch --show-current
```

**Never commit to `main`/`master` unless explicitly requested.** If on main, create a feature branch:

```bash
git checkout -b <type>/<short-name>
```

Branch naming follows the commit type: `feat/`, `fix/`, `refactor/`, `test/`, `chore/`, `docs/`.

Commit any uncommitted changes before proceeding.

#### 2. Gather context

```bash
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main...HEAD --stat 2>/dev/null || git diff master...HEAD --stat
```

#### 3. Identify source issue

Check conversation context, branch name, or commit messages for issue references (GitHub `#N`, GitLab `#N`, or Linear `TEAM-N`). If found, link it in the body.

GitLab tip: cross-project references look like `group/project#N`; a bare `#N` targets the current project. Keep whatever form the user gave you.

#### 4. Check if a request already exists

**GitHub:**

```bash
gh pr view --json number,title,body 2>/dev/null
```

**GitLab:**

```bash
glab mr view --json number,title,description 2>/dev/null || glab mr view 2>/dev/null
```

If one exists, you'll update it in step 6 instead of creating a new one.

#### 5. Write the description

Show the proposed title and body to the user. **Wait for approval before creating.**

### Title Format

```
<type>: <short description>
```

Same rules as commits: lowercase, imperative, under 70 chars.
If a Linear ID is available: `TEAM-123 - <type>: <short description>`

### Body

Two sections only. No checklists, no file lists, no templates.

```markdown
<issue_url>

### Background

1-2 paragraphs explaining the problem and the high-level approach.
Write naturally, like explaining to a colleague.

### Key Decisions

1. **Decision title**: brief explanation of the choice.
2. **Another decision**: what was done, stated as a fact.
```

Link the issue URL on its own line (no closing keyword like "Closes" / "Fixes"). Omit if no source issue. Omit Key Decisions if there are none worth mentioning (small fixes).

#### 6. Create or update

Push the branch first if needed:

```bash
git push -u origin $(git branch --show-current)
```

**GitHub — new PR:**

```bash
gh pr create --draft --title "<title>" --body "<body>"
```

**GitHub — existing PR:**

```bash
gh pr edit --title "<title>" --body "<body>"
```

**GitLab — new MR:**

```bash
glab mr create --draft --title "<title>" --description "<body>" \
  --source-branch "$(git branch --show-current)" \
  --target-branch main   # or master, match the repo's default
```

`glab mr create` can also read the title/description from an editor if you drop the flags, but pass them explicitly here so the message stays under our control. Add `--remove-source-branch` only if the user wants the branch deleted on merge.

**GitLab — existing MR:**

```bash
glab mr update --title "<title>" --description "<body>"
```

Report the request URL to the user (`gh`/`glab` print it on create; otherwise `gh pr view --web` / `glab mr view --web` give it).

### PR/MR Style

- **Fluid prose** in Background. Natural writing, not robotic
- **Key Decisions stated as facts.** Say what you did, one sentence each. No justifying what you avoided or why alternatives were worse
- **No implementation details in decisions.** Don't explain how the code works, just the architectural choice
- **No file lists or changelogs.** GitHub/GitLab show that in the diff view
- **No AI mentions.** Never reference agents, Claude, copilot, or AI assistance
- **No em dashes, en dashes, or double dashes.** Use colons, commas, or periods
- **No closing keywords.** Just link the issue URL on its own line. (GitLab auto-closes issues from `Closes #N` too, so leaving it out keeps the link informational on both forges.)
- **Human voice.** Write like a developer wrote it
