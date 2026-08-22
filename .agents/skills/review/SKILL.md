---
name: review
description: "Code review in 2 modes. Autonomous (default): spawns parallel security/performance/quality reviewers + red-team auditor, presents verdict. Pair: walks changed files one-by-one with you, collects comments, posts only on approval. Accepts prompt, GitHub/GitLab/Linear URL, PRD path, or no args. Use when: review, code review, review PR, review MR, walk me through the PR, pair review, review together, security review, quality check."
---

# Review

Two-mode code review.

- **Default (autonomous):** parallel specialized reviewers + red-team audit + verdict.
- **Pair mode:** file-by-file walkthrough with comment bag and post-on-approval.

## Forge tooling (GitHub vs GitLab)

This skill talks to a code forge in several places (reading issues/PRs, fetching
diffs, posting review comments). Pick the CLI by the host in the URL or the git
remote — don't assume GitHub. GitLab calls a pull request a **merge request (MR)**,
and names some JSON fields differently.

| Action | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Read issue | `gh issue view <n> --json title,body --jq '.title + "\n\n" + .body'` | `glab issue view <n> -F json \| jq -r '.title + "\n\n" + .description'` |
| Read PR/MR | `gh pr view <n> --json title,body --jq '.title + "\n\n" + .body'` | `glab mr view <n> -F json \| jq -r '.title + "\n\n" + .description'` |
| PR/MR metadata | `gh pr view <n> --json title,body,headRefName,baseRefName,files` | `glab mr view <n> -F json` (fields: `title`, `description`, `source_branch`, `target_branch`; file list via `glab mr diff <n>`) |
| PR/MR diff | `gh pr diff <n>` | `glab mr diff <n>` |
| Post a comment | `gh api ...` (review comment on file+line) | `glab mr note <n> -m "<text>"` (general) or `glab api` on the discussions endpoint (see Pair Phase 6) |

Notes:
- Both `gh` and `glab` infer the repo from the current directory's git remote. Outside
  the repo, pass `-R <owner>/<repo>` (gh) or `-R <group>/<project>` (glab, full host
  path for self-hosted).
- GitLab uses `description` where GitHub uses `body` — that's why the `jq` filters differ.
- **Linear** (`linear.app/...` or a `<TEAM>-<n>` identifier): `lineark issues read <identifier>` if available; otherwise ask the user to paste the text.
- Self-hosted GitLab (`git.<company>`, `gitlab.<company>`) still uses `glab`. If the host
  is ambiguous, ask which forge it is rather than guessing.

## Usage

- `/review` — ask what to review, default autonomous
- `/review <prompt|url|path>` — review current changes against the given context, autonomous
- `/review pair <PR/MR-ref>` — enter pair mode on a PR (GitHub) or MR (GitLab)
- `/review pair` — ask for the PR/MR reference, enter pair mode

## Parse input

- **Prompt:** use as `{review_context}` directly.
- **URL:** fetch per the Forge tooling table above (issue or PR/MR, by host).
- **File path:** read the file.
- **No args:** ask "What should I review? Describe it, paste an issue/PR/MR URL, or point me to a spec."

---

## Autonomous mode (default)

### Phase 1: Diff

```bash
git diff main...HEAD
git diff main...HEAD --stat
```

If empty, try `git diff HEAD~1`. If still empty, say nothing to review and stop. Store as `{diff}` and `{diff_stat}`.

### Phase 2: Scout

Launch the `scout` agent:

> Map the codebase areas touched by these changed files. Report: architecture, patterns, conventions, test structure, error handling, project rules from CLAUDE.md/AGENTS.md/.claude/rules.
>
> Changed files:
> {diff_stat}

Store as `{scout_context}`.

### Phase 3: Parallel review

Launch **3 agents in parallel** (single message, 3 Agent tool calls):

- `security-reviewer`: "Review this PR for security issues.\n\n## Review Context\n{review_context}\n\n## Codebase Context\n{scout_context}\n\n## Diff\n{diff}"
- `performance-reviewer`: "Review this PR for performance issues.\n\n## Review Context\n{review_context}\n\n## Codebase Context\n{scout_context}\n\n## Diff\n{diff}"
- `quality-reviewer`: "Review this PR for quality (design, testing, DDD, SOLID, clean code).\n\n## Review Context\n{review_context}\n\n## Codebase Context\n{scout_context}\n\n## Diff\n{diff}"

All 3 in the same message so they run concurrently.

### Phase 4: Red-team audit

Launch `review-auditor`:

> Audit these three code review reports. Verify findings against actual code. Check for false positives, blind spots, contradictions, severity miscalibration.
>
> ## Review Context
> {review_context}
>
> ## Security Review
> {security_report}
>
> ## Performance Review
> {performance_report}
>
> ## Quality Review
> {quality_report}

### Phase 5: Judge and present

Synthesize (you, not a subagent):

1. Drop false positives flagged by the auditor.
2. Apply severity adjustments.
3. Verify high-confidence findings.
4. Add blind spots as new findings.
5. Deduplicate (same file:line).
6. Tag each finding: `[security]`, `[performance]`, `[quality]`, `[audit]`.

**File references — make them jumpable in neovim.** The written report is opened in
neovim (see **Open the review in herdr**), so every file a finding names must be a
plain, repo-root-relative path that neovim's `gf`/`gF` can resolve. nvim launches
with its cwd at the repo root, so a path like `src/app/globals.css` opens directly.

- Always relative to the repo root. Never absolute, never `./`-prefixed.
- Use the `path:line` form (`src/components/ui/input.tsx:11`) so `gF` jumps straight
  to the line. Bare `path` is fine when there's no single line.
- One path per backtick span — never comma-join lines (`file.ts:8,13-20` breaks `gF`).
  Repeat the path per line instead: `` `button.tsx:8` ``, `` `button.tsx:13` ``.
- Put the path in backticks so it's visually distinct and the whole span sits under
  the cursor for `gf`.

Present:

```markdown
## Code Review: {branch name}

**Diff:** {files changed}, {insertions}+, {deletions}-
**Reviewers:** security, performance, quality + red-team audit

### Critical
- [{source}] **{title}** at `{file}:{line}`
  {description}
  **Test (RED first):** {failing test that proves the issue}
  **Fix:** {minimal fix}

### High / Medium / Low
- ...

### Good patterns
- ...

### Audit notes
- ...

**Verdict:** {Critical/High -> "Needs fixes" | Medium/Low only -> "Clean with suggestions" | Nothing -> "Ship it"}
```

### Phase 6: Next step

If verdict is not "Ship it":

> **What next?**
>
> **a)** Write full report to `docs/reviews/{branch-name}.md`
> **b)** Address findings (TDD, RED first, baby steps)
> **c)** Switch to pair mode for interactive walkthrough

Wait for the user to choose. Option b triggers `/dev` on the prioritized fix list.

When you write the report to a file (option a, or any time the user asks for the
report on disk), follow up with **Open the review in herdr** below.

---

## Open the review in herdr

After a review report is written to a file, if the session is running inside
**herdr** (the user's terminal multiplexer), open it in a **two-pane** layout: the
current (agent) pane stays on the left, and a new pane to its right holds **one
neovim** split into two windows — the report on the left window, and code files that
you jump to with `gf`/`gF` opening in the right window. The report window is never
replaced, so you read the review on one side and browse the code on the other.

**Only do this inside herdr.** Detect it by the `HERDR_ENV` environment variable.
If `HERDR_ENV` is unset, skip this section entirely — the report is already on disk,
just tell the user its path. Do not spawn the subagent below outside herdr.

The two-window nvim behavior comes from `review-layout.lua`, which sits next to this
`SKILL.md`. Resolve its absolute path (the directory containing this skill file +
`/review-layout.lua`) and pass it as `{layout_lua}` below.

Delegate the pane work to a **Haiku 4.5 subagent** (Agent tool, `model: "haiku"`) —
the model can't change mid-session, but a subagent takes its own model, and this
mechanical pane-wrangling doesn't need the main model. Pass it `{report}` (the report
path), `{repo}` (the repo root), and `{layout_lua}` filled in, and this exact brief:

> You are inside herdr (`HERDR_ENV=1`). Open a review report in a two-pane layout.
> Report path: `{report}`. Repo root: `{repo}`. Layout script: `{layout_lua}`.
> Use only `herdr pane` commands.
>
> **1. Don't duplicate the panel.** List the panes in the current tab and check each
> one's foreground process — if `nvim` is already running in this tab the review
> panel already exists, so do nothing and report that it was already up.
>
> ```bash
> for P in $(herdr pane list --workspace "$HERDR_WORKSPACE_ID" \
>   | python3 -c "import sys,json,os; t=os.environ['HERDR_TAB_ID']; print('\n'.join(p['pane_id'] for p in json.load(sys.stdin)['result']['panes'] if p['tab_id']==t))"); do
>   herdr pane process-info --pane "$P" \
>     | python3 -c "import sys,json; ps=json.load(sys.stdin)['result']['process_info']['foreground_processes']; names={p['name'] for p in ps}; print('$P', 'nvim' in names)"
> done
> ```
>
> **2. neovim to the right.** Split the current pane rightward (current pane stays on
> the left) and open the report with the layout script:
>
> ```bash
> NVIM_PANE=$(herdr pane split --current --direction right --ratio 0.5 --cwd "{repo}" --no-focus \
>   | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])")
> herdr pane run "$NVIM_PANE" "nvim -c 'luafile {layout_lua}' '{report}'"
> ```
>
> Leave focus on the current (agent) pane. If any `herdr pane` call errors, close any
> pane you created (`herdr pane close <id>`) so you don't leave a half-built layout,
> and report the error. Report back: whether you opened the panel or skipped it as
> already-open, and any errors.

Relay the subagent's result to the user, and remind them: in the report window, `gf`
opens the file under the cursor and `gF` opens it at the `:line`, both in the right-
hand window.

---

## Pair mode

Interactive file-by-file walkthrough. You bring context, the user reviews, comments go in a bag, posted only on approval.

### Phase 1: Resolve PR/MR reference

Parse the argument. Determine the forge first (host of the URL, or the git remote), then:

- Number `123`:
  - GitHub → `gh pr diff 123`, `gh pr view 123`
  - GitLab → `glab mr diff 123`, `glab mr view 123`
- URL → extract the number and forge from the host
- No arg → ask "Which PR/MR? Number or URL."

### Phase 2: Gather context

1. Metadata + diff, per forge:
   - GitHub: `gh pr view <n> --json title,body,headRefName,baseRefName,files` then `gh pr diff <n>`
   - GitLab: `glab mr view <n> -F json` (read `title`, `description`, `source_branch`, `target_branch`) then `glab mr diff <n>`
2. Launch `scout`:

   > Read the changed files in full and map surrounding code. Report:
   > - What each change does and why
   > - Related models, services, helpers touched
   > - Project patterns the PR should follow
   > - Concerns (thread safety, error handling, naming, tests)

3. **Rank files by review priority** (you, not scout):
   - Security-sensitive files first (auth, crypto, input handling, SQL)
   - Business logic before tests
   - Files with more changes first within each tier
   - New files before modifications

### Phase 3: Overview

Present:

```
## PR/MR #{number}: {title}

{body/description summary in 2–3 lines}

### Files (ranked by review priority)
1. {file} — {new|modified|deleted} — {chars}/{lines} changed — {why this rank}
2. ...

### Scout highlights
{top 3 insights from scout}

Ready. Say 'next' to start with #1, or pick a number.
```

### Phase 4: File-by-file walkthrough

For each file (in ranked order or user-picked):

- **File path** and status (new/modified/deleted)
- **Key chunks:** show 2–4 most important code snippets from the diff, not the full file
- **Insights:** what changed and why
- **Concerns:** flag bugs, pattern deviations, style issues, missing tests

Then wait. The user may:

- `next` — move to the next file
- `prev` — go back
- `#N` — jump to file N
- Ask questions about the current file
- Dictate a comment: `comment <prefix>: <text> at line <N>`
- `skip` — move on without comments
- `done` — jump to phase 5

### Phase 5: Comment bag

Maintain a running table:

```
| # | File:Line | Comment |
|---|-----------|---------|
| 1 | auth/login.rb:42 | **question:** why skip the CSRF check here? |
```

Conventional prefixes (user picks):
- `question:` — asking clarification
- `suggestion:` — proposing an alternative
- `issue:` — needs to change
- `nit:` — minor, take it or leave it
- `thought:` — context, no action needed
- `praise:` — highlighting something well done

Never add comments the user didn't dictate. Never paraphrase.

### Phase 6: Preview and post

After `done`, show the final bag:

```
Ready to post {N} comments on PR/MR #{number}. Want me to post, edit any, or discard?
```

**Never post without explicit approval** ("post", "go ahead", "ship it").

On approval, post to the correct forge:

- **GitHub:** use `gh api` to create PR review comments on the correct file and line using the head commit SHA.
- **GitLab:** for inline comments, use `glab api` on the MR discussions endpoint —
  `POST /projects/:id/merge_requests/:mr_iid/discussions` with a `position` object
  (`base_sha`/`start_sha`/`head_sha` from `glab mr view <n> -F json` diff_refs,
  `new_path`, `new_line`). For a plain MR-level comment, `glab mr note <n> -m "<text>"`
  is simpler. When line-anchored posting is fiddly, fall back to `glab mr note` and
  reference `file:line` in the text — confirm the fallback with the user first.

Report back with the comment/note URLs.

---

## Principles

- TDD when fixing findings. RED first.
- Baby steps. One fix at a time.
- Stack-agnostic and forge-agnostic (GitHub/GitLab). Project-aware (scout reads CLAUDE.md/.claude/rules).
- Adversarial audit (autonomous). Red team kills bad findings, not adds noise.
- In pair mode, the user controls the bag. You never write a comment the user didn't dictate.
