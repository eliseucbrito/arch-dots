---
name: taskle-memory
description: "Use the Taskle CLI as persistent cross-session memory for a project: one hidden Taskle project per app/repo, tags for the kind of work (#bug, #debt, #feature, #followup). Consult this whenever you (the agent) identify a TODO, known bug, piece of tech debt, or follow-up you're not handling right now and want it to survive past this conversation — and whenever the user says things like 'lembra disso', 'anota pra depois', 'registra esse bug', 'não esquece', 'deixa isso pendente', 'track this', 'remember this for later', or asks what's still pending on a project. Also use it to check existing memory at the start of a session ('o que ficou pendente', 'what's left on X'). Requires the `taskle` binary on PATH — check with `taskle --help` before relying on it, and if missing, tell the user instead of silently skipping the memory step."
---

# Taskle as agent memory

[Taskle](https://github.com) is a keyboard-first task CLI (`taskle add`, `taskle list`, ...). Beyond personal task management, use it as **persistent memory across coding sessions**: a place to park TODOs, known bugs, and tech debt that you notice but aren't fixing right now, so a future agent (possibly you, possibly not) picks them up instead of them getting lost when the conversation ends.

This only works if every agent writes to the same structure. The convention below is what makes it queryable later — skipping it (e.g. dumping everything into one flat list with no project/tags) turns Taskle back into a junk drawer.

## Core convention: one hidden project per app

Each app or repo you work on gets **exactly one Taskle project**, named after the repo, and that project is **hidden**.

```sh
taskle project add taskle
taskle project hide taskle
```

Hidden means: tasks under `@taskle` stay out of `taskle list` / `taskle agenda` / `taskle matrix` by default, so this cross-project memory never clutters the user's actual day-to-day task view. It only shows up when explicitly asked for:

```sh
taskle list --project taskle             # this app's memory only
taskle list --include-hidden             # everything, hidden projects included
taskle projects                          # shows "(hidden)" next to hidden projects
```

Hiding is idempotent and reversible (`taskle project unhide <name>`) — if the project already exists and is already hidden, `project hide` is a no-op, not an error. Before creating, check whether it already exists so you don't error on `ErrDuplicate`:

```sh
taskle projects --json   # or: taskle projects, and look for "@<repo-name>"
```

If the project is missing, create it and hide it in the same breath — don't leave a memory project visible.

## Tags: what kind of item this is, not which app

Since the project already identifies the app, use **tags** for the category of work, not for the app name. Suggested vocabulary — reuse these consistently instead of inventing synonyms per session, so `taskle list --tag bug` actually returns everything:

| Tag | Use for |
|---|---|
| `#bug` | a known bug you found but didn't fix now |
| `#debt` | tech debt / cleanup that's out of scope for the current task |
| `#followup` | a reasonable next step after what you just did |
| `#idea` | a possible improvement, not yet validated as worth doing |
| `#blocked` | needs human input/decision before it can proceed |

```sh
taskle add "Sync race condition when Close() runs during background replica connect #bug @taskle"
taskle add "Extract printAggregates duplication between projects.go and tags.go #debt @taskle"
taskle add "Add --sort=priority to agenda, mirrors list's --sort #followup @taskle"
```

Combine with the rest of the quick-add grammar when it's genuinely useful — `!u`/`!i` for urgency/importance, `^+7d` for a due date if the item has a real deadline, `~30m` for a rough estimate — but don't force these onto items that don't need them. Most memory items are just text + `#tag` + `@project`.

## Writing useful memory items

A memory item should let a future agent — with zero conversation context — decide whether to act on it. Compare:

**Too vague:** `taskle add "fix the sync thing #bug @taskle"`

**Actionable:** `taskle add "sync() can push stale local writes if Close() fires mid-connect, see internal/store/store.go Open() #bug @taskle"`

Include the file/function when you have it. You're writing for someone who wasn't in this conversation.

For anything that needs more than one line — root cause analysis, why an approach was rejected, reproduction steps — add the task first, then attach notes to it (opens `$EDITOR`, or pass one line inline with `--notes` at creation time):

```sh
taskle add "Investigate flaky TestEmbeddedReplicaSync #bug @taskle"
taskle note <index>   # multi-line detail: repro steps, stack trace, what you already ruled out
```

## Retrieving memory (start of a session, or when asked "what's pending")

```sh
taskle list --project <repo-name> --include-hidden      # everything for this app
taskle list --project <repo-name> --tag bug             # just the bugs
taskle show <index>                                      # full detail incl. notes
```

If `taskle projects --json` doesn't list the current repo's project at all, there's no memory yet for this app — that's normal for a first session, not an error.

## Closing the loop

When you pick up and resolve a memory item, close it like any other task so the memory stays a reliable signal instead of accumulating stale entries:

```sh
taskle done <index>
```

Leave it open (don't force `done`) if you only partially addressed it — better to under-claim completion than to hide unfinished work from the next agent.
