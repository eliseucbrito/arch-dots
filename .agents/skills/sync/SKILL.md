---
name: sync
description: "Scout the current project, diff against existing CLAUDE.md and .claude/rules, propose updates to reflect stack and conventions. Idempotent. Does not copy user-level skills or agents (user-level always wins). Use when: sync, forge, tune, init project, bootstrap, prepare project, refresh rules."
---

# Sync

Scout the project and update its `CLAUDE.md` and `.claude/rules/` so they reflect current state. Runs safely multiple times — only proposes changes where state and docs diverge.

Does **not** copy user-level skills or agents. Per Claude Code precedence, personal (`~/.claude/skills`) wins over project (`.claude/skills`). Copying creates shadowed duplicates. Skills and agents stay user-level.

## Usage

- `/sync` — full sync (CLAUDE.md + rules)
- `/sync rules` — only update `.claude/rules/`
- `/sync claude` — only update `CLAUDE.md`

## Phase 1: Scout

Launch the `scout` agent:

> Map this project for a sync pass. Report:
> - Stack: language + version, framework + version, key deps (read manifests, not just their names)
> - Commands: test, lint, build, format (Makefile, package.json scripts, mix aliases, Cargo scripts, README)
> - Test structure: framework, file organization, naming, fixtures
> - Conventions: naming, error handling, module boundaries (sample 3–5 representative files)
> - Existing docs: presence of CLAUDE.md, .claude/rules/*, AGENTS.md

Read the scout report.

## Phase 2: Diff

Compare scout findings against what exists in the project.

### CLAUDE.md checks

Read `./CLAUDE.md` (or `./.claude/CLAUDE.md`). Check:

- **Present?** If missing, propose a new one.
- **Stack matches scout?** If it mentions wrong framework/version, flag drift.
- **Commands documented?** If scout found build/test/lint commands and CLAUDE.md doesn't mention them, propose adding.
- **Architecture summary?** If the project has clear bounded contexts that scout identified and CLAUDE.md doesn't reflect, propose a section.

### Rules checks

List `.claude/rules/*.md`. For each detected stack, check:

| Stack | Expected rule | Default globs |
|---|---|---|
| Elixir | `elixir.md` | `lib/**/*.ex`, `test/**/*.exs` |
| Ruby | `ruby.md` | `app/**/*.rb`, `lib/**/*.rb` |
| Rust | `rust.md` | `src/**/*.rs` |
| TypeScript | `typescript.md` | `src/**/*.{ts,tsx}` |
| Go | `go.md` | `**/*.go` |
| Python | `python.md` | `**/*.py` |
| Any | `testing.md` | path to test dir detected by scout |
| Any | `git.md` | no globs (always-on) |

For each missing rule relevant to the detected stack, propose creating it.

For each existing rule, check for obsolete globs (paths that no longer exist) and flag.

## Phase 3: Propose

Present a single summary to the user:

```
## Sync plan

### CLAUDE.md
- [create] Missing. Draft attached below.
- [update] Add "## Commands" section with test/lint/build from scout.
- [drift] Mentions Phoenix 1.6, scout detected 1.7. Update version.

### Rules
- [create] .claude/rules/elixir.md — Phoenix/LiveView patterns, anti-patterns.
- [create] .claude/rules/testing.md — ExUnit conventions from scout.
- [skip] .claude/rules/git.md — already up to date.
- [flag]  .claude/rules/legacy.md — glob `old_app/**` matches no files.

Proceed? (y to apply all, s to pick, n to stop)
```

If `y`, apply all. If `s`, walk through each item one by one. If `n`, stop.

## Phase 4: Apply

For each approved item, show the diff, then write the file. For new files, show the full proposed content before writing.

**Never delete** existing rules or CLAUDE.md content. Only create or update. Preserve custom sections.

## Phase 5: Report

```
## Sync done

### Created
- .claude/rules/elixir.md

### Updated
- CLAUDE.md (added Commands section, bumped Phoenix version)

### Flagged (no action taken)
- .claude/rules/legacy.md — obsolete globs, review manually
```

## Rule file template

Every rule uses this frontmatter:

```yaml
---
description: {one-line purpose}
paths:
  - "{glob}"
---
```

Rules without `paths` load always. Rules with `paths` load only when Claude reads matching files. Use `paths` when the rule is language-specific.

## Content guidelines

Rules should capture **what is true about this project**, not generic best practices. Include:

- Naming patterns actually used (from scout sampling)
- Error handling style actually used
- Anti-patterns specific to the framework
- Commands and conventions from CLAUDE.md that apply to matching files

Skip generic style advice that belongs in a language style guide.

## Idempotency

- Read before write. Normalize whitespace when comparing.
- If generated content matches existing, skip silently.
- If different, show diff and ask.
- Never overwrite custom content without diff + approval.
