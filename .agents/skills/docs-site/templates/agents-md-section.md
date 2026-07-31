<!--
Paste into the repo's AGENTS.md / CLAUDE.md. Fill in the bracketed parts from the actual
site you built. Keep both tables — the routing table saves an agent from exploring src/
cold, the sync table is what keeps the site from rotting once this skill's work is done.
-->

## Docs site

`docs-site/` is a Docusaurus site (source under `docs-site/docs/`)[, deployed at <URL/deploy
mechanism, if any>]. It doubles as a knowledge base for AI agents — reading the relevant page
below is usually cheaper than exploring `src/` from scratch, and pages call out where the code
doesn't yet match documented intent (unused guards, dead DTOs, unwired config — see any
`:::caution` callouts).

### Where to look before exploring `src/`

| Question | Read |
|---|---|
| How do I add a new [component]? | `docs-site/docs/architecture/<pattern-page>.md` |
| How does [cross-cutting mechanism] work? | `docs-site/docs/architecture/<mechanism-page>.md` |
| What does [component] X do, and does it deviate from the standard pattern? | `docs-site/docs/<components>/overview.md` (deep pages: `<components>/<name>.md`) |
| What's the response/error shape? | `docs-site/docs/api/conventions.md` |
| Why was a design decision made? | `docs-site/docs/adr/` (mirrors the external source of truth) |
| Product requirements / what's spec-scoped vs. implemented? | `docs-site/docs/product/<name>.md` |
| Rules for writing or updating a doc page? | `docs-site/docs/contributing/documentation-guide.md` |

### Keep docs in sync with code

Update the matching doc page in the **same commit** as the code change, not a follow-up:

| Changed | Update |
|---|---|
| [cross-cutting mechanism source path] | matching page under `docs-site/docs/architecture/` |
| a new [component] under `[components path]/<name>/` | a row in `docs-site/docs/<components>/overview.md`; add a dedicated page only if it meets the deep-page criterion in `docs-site/docs/contributing/documentation-guide.md` |
| [entity/schema/model source path] | `docs-site/docs/architecture/<persistence-or-equivalent-page>.md` |
| [any mechanism this session found unwired] | the "not yet enforced/used" note is written to be removed once it's actually wired — update it when that changes |
