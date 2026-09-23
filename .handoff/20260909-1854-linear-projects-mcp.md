# Handoff: Linear Projects MCP server (`@projeto` mention in Claude Code)

**Created:** 2026-09-09 18:54
**Branch:** omarchy-4-migration (work is unrelated to this branch — see note)
**Status:** paused — design agreed, no code written yet

## Goal

Build a standalone MCP server so that inside Claude Code the user can type
`@<team> / <project>` (Linear project) in the `@` mention picker, which injects
that project's context (id, name, description, milestones) into the
conversation. The user then gives a natural-language instruction like
*"crie uma task para preparar o app para produção e faça disso um novo
milestone também"* and the agent translates it into Linear API calls. The
point is to never have to open Linear to look up project names / ids.

This must NOT depend on parsing the Linear CLI stdout. Source of truth is the
Linear GraphQL API directly.

## Why an MCP server with `resources` (not tools, not the official Linear MCP)

- Claude Code's `@` picker lists two things: local files, and **MCP
  `resources`** (any server implementing `resources/list` + `resources/read`).
  Verified this session: `ListMcpResourcesTool` returns only the `figma`
  server's resources; the Linear MCP configured here exposes **tools only**, so
  it does NOT appear in the `@` picker.
- Therefore, to get `@projeto1` in the autocomplete, we need our own server
  that exposes Linear projects as `resources`. The official
  `mcp.linear.app` server can't do this UX.

## Design decisions (all confirmed with the user this session)

| Question | Decision |
|---|---|
| Repo location | **Separate repo** (publishable to npm later). NOT in dotfiles. |
| Auth | **OAuth 2.0** (PKCE), not a personal API key. For sharing with others. |
| Token storage | `~/.config/linear-mcp/tokens.json`, auto-refresh |
| `@` listing shape | **Hierarchy `Team / Project`** — resource title `TeamA / projeto1`, URI `linear:///project/<id>`. Chosen because project names can repeat across teams. |
| `resources/read` payload | `id`, `name`, `description` of project + `milestones: [{id, name}]` (via `project.projectMilestones`). Teams/members/labels/workflow-states deliberately left OUT for now — add later if needed. |
| "milestone" meaning | Native **Project Milestone** (`projectMilestoneCreate`), a subdivision of one project. Not an Initiative. |
| Cache | **Disk cache with short TTL (5 min)** at `~/.config/linear-mcp/cache.json`. Applies to both `resources/list` and each `resources/read` body. |

## Spec (agreed)

**Stack:** TypeScript, `@modelcontextprotocol/sdk`, stdio transport.

**OAuth:** PKCE flow, browser callback on `http://localhost:8989/callback`.
Tool `authenticate` triggers the flow when no valid token exists.
User must create an OAuth application in Linear (Settings → API → OAuth
applications) with redirect URI `http://localhost:8989/callback`, and provide
`client_id` / `client_secret`. Server reads `LINEAR_OAUTH_CLIENT_ID` (and
secret) from env.

**`resources/list`:** GraphQL `teams { nodes { name projects { nodes { id name } } } }`.
One resource per project, title `Team / Project`, URI `linear:///project/<id>`.

**`resources/read` (`linear:///project/<id>`):** JSON with project `id`,
`name`, `description`, and `milestones` (`[{id, name}]` from
`project.projectMilestones`).

**Tools:**

| tool | args | mutation |
|---|---|---|
| `create_issue` | `projectId`, `title`, `description?`, `milestoneId?`, `assigneeId?` | `issueCreate` |
| `create_project_milestone` | `projectId`, `name`, `targetDate?` | `projectMilestoneCreate` |
| `list_issues` | `projectId`, `state?` | `issues(filter:{project:{id:{eq}}})` |
| `update_issue` | `issueId`, optional fields | `issueUpdate` |
| `authenticate` | — | OAuth flow |

**Registration:** `~/.claude.json` (global) pointing at the built binary, with
`LINEAR_OAUTH_CLIENT_ID` in `env`.

**Estimated size:** ~120–150 lines of TS core + OAuth helper.

## Current state

- **No files created.** Nothing written to disk. No repo exists yet.
- Git working tree on `omarchy-4-migration` has unrelated in-progress dotfiles
  migration changes (powerline statusline, hypr configs, omarchy plugins). None
  of that is related to this handoff — do not touch it.

## What's next

1. Get from the user: the **repo name / path**, and whether to scaffold
   everything now (credentials filled in later via `.env`) or build the
   skeleton and iterate. Both questions were asked at end of session, unanswered.
2. User creates the Linear OAuth application and provides `client_id` /
   `client_secret` + confirms redirect URI `http://localhost:8989/callback`.
3. `npm init`, add `@modelcontextprotocol/sdk`, `graphql-request` (or plain
   fetch), a small PKCE OAuth helper, `zod`.
4. Implement `resources/list` + `resources/read` first, wire the disk cache
   (5-min TTL).
5. Implement `authenticate` (OAuth PKCE + local callback server on :8989 +
   token persistence + refresh).
6. Implement the 4 tools.
7. Build, register in `~/.claude.json`, test the `@Team / Project` flow end to
   end.

## Blockers / Open questions

- **Repo name and location** — not decided.
- **Scaffold-all vs skeleton-first** — not decided.
- **Linear OAuth app credentials** — user must create the OAuth application;
  server can't be tested past `resources` mocking without it.

## How to continue

1. Read this handoff file.
2. Ask the user the two open questions (repo name/path; scaffold-all vs
   skeleton-first) if not already answered.
3. Ask the user to create the Linear OAuth application and hand over
   `client_id` / `client_secret`.
4. Create the new repo per the Spec above and start with `resources/list` +
   `resources/read` + disk cache.

## Key files

None yet. Relevant reference material:

- Claude Code `@` picker sources MCP `resources` — confirmed via
  `ListMcpResourcesTool` this session (only `figma` currently exposes any).
- Linear GraphQL API: https://developers.linear.app/docs/graphql/working-with-the-graphql-api
- Linear OAuth: https://developers.linear.app/docs/oauth/authentication
- MCP TypeScript SDK: `@modelcontextprotocol/sdk` (`Server`, `resources/list`,
  `resources/read` handlers, `StdioServerTransport`).
