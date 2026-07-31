---
name: docs-site
description: "Scaffold or extend a Docusaurus knowledge base for a codebase that serves both developers and AI agents — architecture pages, a module/component reference, ADR/PRD mirrors, and a docs-contribution ruleset. Explores the code first to find where real complexity lives versus repeated boilerplate, so page depth follows a written criterion instead of one-page-per-file. Explicitly documents code that exists but isn't wired up yet (unused guards, dead DTOs, unreferenced classes) instead of describing intended behavior as current. Use when: docs site, documentation site, docusaurus, knowledge base, developer docs, agent-readable docs, write documentation, document this codebase, document the architecture, onboarding docs, internal docs site."
---

# Docs Site

Build a Docusaurus site that a developer can browse and an AI agent can read from disk instead of exploring `src/` cold. The two readers want the same thing: the true shape of the system, including the parts that don't work yet, with the shortest path to "is this page still accurate."

The output is not "one page per file." Most codebases have a few places where real complexity lives and a lot of places that are the same pattern copied N times. A site that gives every module a full page duplicates the copies and buries the complexity. This skill's job is to find the split and write accordingly.

## When this applies

Use for a from-scratch docs site or for extending one that already exists. Works on any stack — the phases below don't assume a language or framework, only that the target renderer is Docusaurus. If the user's renderer is something else (MkDocs, Mintlify, plain markdown), the method still applies but `references/docusaurus-technical.md` won't — ask before assuming Docusaurus.

## The four phases

Do not skip to writing pages. The exploration in Phase 2 is what makes Phase 4 accurate instead of generic — a page written before you've read the code it describes is a guess with formatting.

### Phase 1 — Plan via questions, not assumptions

Before touching any file, ask the user (`AskUserQuestion`, one round, batch the questions) about the decisions that change the shape of the site. Don't ask about things you can determine yourself by reading the repo (stack, existing structure) — ask about things only the user knows:

1. **What happens to existing docs** (READMEs, ADRs, PRDs, wikis). Three shapes, pick per source:
   - *Migrate fully* — old doc is superseded, delete it in the same commit that replaces it.
   - *Link out* — the doc stays where it is (e.g. a README that's the literal entry point before the site can even be reached), the site links to it.
   - *Mirror with a source-of-truth note* — the doc lives in an external system (Notion, Confluence, Linear) that either already is, or is becoming, authoritative. Mirror the body verbatim in its original language, add a short section in the site's language stating what it binds in code, and bannerize which system wins on conflict. Never translate-and-fork a doc whose source of truth lives elsewhere — a fork can't be synced later.
2. **Agent-optimization mechanism** — default to frontmatter (`summary`, `source`) plus a routing table added to the repo's `AGENTS.md`/`CLAUDE.md`. Only add a separate `llms.txt` if asked; it's one more file to keep in sync for a benefit the routing table already covers for agents reading from disk.
3. **Module/component depth** — see Phase 2, this is not really a question to ask blind; explore first, then present the criterion you found with a concrete before/after so the user is confirming a proposal, not designing from nothing.
4. **Should the ruleset itself be a published page**, enforced via `AGENTS.md`, or kept out of the site. Default: yes, published — a rule nobody can find isn't a rule.

Full question templates with preview options: `references/planning-questions.md`.

### Phase 2 — Explore before deciding page depth

This is the phase that makes the site accurate instead of templated. Spend real tool calls here — reading files, counting lines, diffing near-duplicates, grepping for usage — before proposing structure.

**Find the pattern and its cleanest instance.** For a set of similar components (modules, resources, handlers, whatever the codebase's repeated unit is), diff a few against each other. If they're near-identical, that's a pattern worth one page, not N. Pick the smallest/cleanest instance as the worked example — not the most-used one, not the one a README already calls "the reference." A component that's simple gets copied faithfully; a component with extra fields (audit columns, feature flags, a special-case branch) teaches the copier to carry the extras along as if they were the pattern. Verify this by reading, not assuming: the natural "reference implementation" is often the most-featured one because it's the most visible, which is exactly why it's the wrong teaching example.

**Write the deep-page criterion down before applying it.** Read every candidate component's core logic (not just its signature) and separate two kinds of complexity:
- Structural repetition — same five operations, different entity. Table row.
- Real logic — validation across more than one relation, a non-standard route, an invariant, a lifecycle rule. Dedicated page.

State the line you drew as a rule, in the words that will go in the site's own contributing guide, e.g.: *"A module earns a page when its logic does more than the standard N operations over one entity: cross-entity validation beyond a single reference, non-standard routes, domain invariants, or lifecycle rules."* This sentence is the actual deliverable of Phase 2 — it's what makes the decision durable. A new component six months from now gets evaluated against the rule, not against "how many pages did we make last time."

**Map cross-cutting mechanisms separately from components.** Request/response pipeline, auth, persistence conventions, error handling — these aren't components, they're the machinery every component runs through. Each gets its own page, and each should be *worked through a concrete example* (a real request, a real entity) rather than described abstractly. Abstract description reads fine and verifies nothing; a worked example is falsifiable by reading the actual code it claims to trace.

### Phase 3 — Find and document unwired code

While reading source for Phase 2, you will find things that exist but aren't used: a guard with no annotated routes, a DTO nothing imports, an exception hierarchy nothing throws, a config flag nothing checks. This is the highest-value thing this skill produces, because it's exactly the gap that makes an agent write code against a contract that doesn't actually hold.

For each one:

1. Grep for real usage, not just definition — `grep -rn "<Symbol>" src/ | grep -v spec` or the codebase's equivalent. Exclude the definition file and test files that only exercise the class in isolation (a `.spec.ts` testing a filter's handling of an exception class is not the same as a service throwing that exception in production).
2. If usage is zero or narrower than the mechanism suggests, write a callout box in the page that would otherwise describe it as working: state what exists, state what actually happens instead, and give the exact grep/search command so the claim is re-checkable rather than trusted on your word.
3. Do this again right before final delivery, not just once mid-session — code changes while you're writing about it, especially in a session where you're also touching source elsewhere.

Never document intended-but-unbuilt behavior as if it were current, even when a design doc or ticket says it should exist. The site describes what runs, with a clear note on what's planned. See `references/unwired-code-pattern.md` for worked phrasing and more examples.

### Phase 4 — Write, structured and verified

**Structure** (adapt directory names to the codebase's own vocabulary — "modules," "services," "resources," "packages" — don't impose "modules" on a codebase that calls them something else):

```
docs/
  intro.mdx                 landing page; short "for AI agents" section pointing at AGENTS.md
  architecture/              one page per cross-cutting mechanism, each worked through a real example
  <components>/
    overview.md              reference table, EVERY component, one row each
    <name>.md                deep page, ONLY for components meeting the written criterion
  api/ (or interface/)       conventions only (envelope, errors, versioning) — link to the generated
                              reference (OpenAPI/Swagger/GraphQL schema/etc), never duplicate it
  adr/ (or decisions/)       mirrors of external decision records, per the Phase 1 answer
  product/                   mirrors of PRD/requirements docs, same treatment, plus a section noting
                              what's spec-scope vs. actually implemented
  contributing/
    documentation-guide.md   the ruleset: language, page types, frontmatter, the deep-page criterion
                              verbatim, "document what is not what should be," prefer tables to prose
                              for repeated structure, don't duplicate generated references
    templates/                copy-paste starting points, see templates/ in this skill
```

**Frontmatter, every page:**

```yaml
---
title: ...
summary: One sentence — what a reader gets without opening the page.
source: [glob patterns of the code this page documents]   # omit for meta/decision pages
audience: [developer, agent]
---
```

`summary` is what makes a page cheap to route to. `source` is what lets anyone — including you, next session — check whether the page still matches reality before trusting it.

**AGENTS.md wiring** — add two tables to the repo's existing `AGENTS.md`/`CLAUDE.md` (don't create a competing file):
1. Routing table: question → which page answers it.
2. Sync-enforcement table: change to path X → update page Y, same commit.

Template for both: `templates/agents-md-section.md`.

**Write incrementally, verify continuously.** Work in a git worktree on its own branch by default (ask first if the user seems to want it in-place) so the docs work is isolated and reviewable independent of whatever else is happening on the main branch. Small Conventional Commits per logical section — scaffold, contributing guide, architecture, components, api conventions, decisions mirror, AGENTS.md wiring — not one giant commit at the end; a reviewer working through 400 lines in one diff misses more than one working through 8 commits of 50.

After each batch of pages, build the site and fix broken links/anchors before moving on, not at the very end where a single typo'd slug can hide behind twenty correct ones. Docusaurus specifics (config flag, numbered-filename slug gotcha, anchor-slugging rules) are in `references/docusaurus-technical.md` — read it before the first build, not after the first failure.

This isn't TDD — a docs page isn't testable production code, so there's no red/green cycle. But every factual claim about code behavior (this method throws X, this guard runs before Y, this field is nullable) must trace to a line you actually read, and the unwired-code claims specifically get re-verified right before delivery per Phase 3.

## Reference files

- `references/planning-questions.md` — the Phase 1 question templates with option previews, ready to pass to `AskUserQuestion`.
- `references/unwired-code-pattern.md` — worked examples of the "available, not yet in use" callout, in a few different flavors (unused guard, dead DTO, unreferenced exception class, stubbed field).
- `references/docusaurus-technical.md` — `_category_.json`, `onBrokenLinks: 'throw'`, the numbered-filename slug stripping issue and its `slug:` frontmatter fix, anchor-slug rules for admonition-heavy pages.
- `templates/module-page.md`, `templates/adr.md`, `templates/guide.md` — starting points for the three recurring page types; copy these into the target site's `contributing/templates/` as-is, they're meant to ship with the site, not just guide you while writing it.
- `templates/agents-md-section.md` — the two-table block to paste into the repo's `AGENTS.md`.
