# Herdr Plugin Reference

Source: https://herdr.dev/docs/plugins/, https://herdr.dev/docs/cli-reference/ (fetched 2026-08-01). Verify against current docs if something doesn't match observed behavior — this is a snapshot.

## Manifest (`herdr-plugin.toml`)

### Required top-level fields
- `id` — package identifier: ASCII letters, digits, `.`, `:`, `_`, `-`
- `name` — display name
- `version` — semver
- `min_herdr_version` — minimum compatible herdr version

### Optional top-level fields
- `description`
- `platforms` — array subset of `["linux", "macos", "windows"]`

### `[[build]]` — install-time build steps
```toml
[[build]]
command = ["npm", "ci"]

[[build]]
command = ["npm", "run", "build"]
platforms = ["linux", "macos"]   # optional, restricts this step
```
Runs during `plugin install`, in order. A failure aborts installation. **Skipped by `plugin link`** — build locally yourself when developing.

### `[[startup]]` — session-restore hooks
```toml
[[startup]]
command = ["node", "dist/restore.js"]
```
Runs once per enabled plugin after herdr restores the session and the plugin socket is ready. Receives `HERDR_PLUGIN_EVENT=startup`. Must restore state and exit — not a supervised daemon.

### `[[actions]]` — invokable entrypoints
```toml
[[actions]]
id = "apply"                     # local id: letters/digits/:/_/-
title = "Apply layout"
contexts = ["workspace"]         # documented value: "workspace"
command = ["node", "dist/apply.js"]
```
Global qualified name: `plugin.id.action` (e.g. `example.layout.apply`). Invoke via `herdr plugin action invoke <plugin.id.action>` or a keybinding.

### `[[events]]` — event-triggered hooks
```toml
[[events]]
on = "worktree.created"          # only event name documented as of this snapshot
command = ["herdr", "workspace", "list"]
```
Receives `HERDR_PLUGIN_EVENT_JSON` with the event payload. If the user needs an event not listed here, check current docs/CLI help — this list is not guaranteed complete.

### `[[panes]]` — managed UI surfaces
```toml
[[panes]]
id = "board"
title = "Project board"
placement = "overlay"            # overlay (default) | popup | split | tab | zoomed
command = ["herdr-board"]
# popup only:
# width = ...
# height = ...
```

### `[[link_handlers]]` — Ctrl+click URL routing
```toml
[[link_handlers]]
id = "github-issue"
title = "Open GitHub issue"
pattern = "^https://github\\.com/[^/]+/[^/]+/(issues|pull)/[0-9]+$"
action = "apply"                 # local action id to invoke
```
Control modifier on **all** platforms (not Command on macOS). The invoked action receives `invocation_source = "link_click"`, `HERDR_PLUGIN_CLICKED_URL`, `HERDR_PLUGIN_LINK_HANDLER_ID` in its context.

### `[[keys.command]]` — keybindings (in the *user's* herdr config, not the plugin manifest)
```toml
[[keys.command]]
key = "prefix+l"
type = "plugin_action"
command = "example.layout.apply"
description = "apply layout"
```

## Runtime environment injected into every plugin command

| Variable | When present | Purpose |
|---|---|---|
| `HERDR_ENV` | always | `1`, marks running inside herdr |
| `HERDR_SOCKET_PATH` | always | socket for raw API requests |
| `HERDR_BIN_PATH` | always | path to the `herdr` binary |
| `HERDR_PLUGIN_ID` | always | this plugin's id |
| `HERDR_PLUGIN_ROOT` | always | installed/linked plugin directory — **do not store credentials or durable state here** (GitHub installs are managed checkouts) |
| `HERDR_PLUGIN_CONFIG_DIR` | always | user-editable config — use for config |
| `HERDR_PLUGIN_STATE_DIR` | always | runtime state — use for state |
| `HERDR_PLUGIN_CONTEXT_JSON` | always (contents vary) | workspace/tab/focused-pane/worktree/agent/selected-text/clicked-url fields, whichever apply to this invocation |
| `HERDR_WORKSPACE_ID` / `HERDR_TAB_ID` / `HERDR_PANE_ID` | if available | current topology ids |
| `HERDR_PLUGIN_ACTION_ID` | action commands | which action fired |
| `HERDR_PLUGIN_EVENT` | startup/event hooks | `startup` or the event name |
| `HERDR_PLUGIN_EVENT_JSON` | event hooks | event payload |
| `HERDR_PLUGIN_ENTRYPOINT_ID` | pane commands | which pane entrypoint |
| `HERDR_PLUGIN_CLICKED_URL` / `HERDR_PLUGIN_LINK_HANDLER_ID` | link handlers | clicked URL + handler id |

Working directory for every plugin command is the plugin directory.

## Calling back into herdr from a plugin

The entire herdr CLI is the plugin API — anything runnable as `herdr ...` is available via `HERDR_BIN_PATH`.

```javascript
const { spawnSync } = require("node:child_process");
const herdr = process.env.HERDR_BIN_PATH ?? "herdr";
const result = spawnSync(herdr, ["workspace", "list"], {
  encoding: "utf8",
  stdio: ["ignore", "pipe", "pipe"],
});
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
process.exit(result.status ?? 1);
```

For lower-level access, talk to `HERDR_SOCKET_PATH` directly with JSON requests (see `/docs/socket-api/`).

### CLI surface useful from plugin scripts

**Plugin management (usually run by the *developer*, not from inside a plugin):**
```
herdr plugin install <owner>/<repo>[/subdir...] [--ref REF] [--yes]
herdr plugin list [--plugin ID] [--json]
herdr plugin uninstall <plugin_id|owner/repo[/subdir...]>
herdr plugin enable <plugin_id>
herdr plugin disable <plugin_id>
herdr plugin link <path> [--disabled]
herdr plugin unlink <plugin_id>
herdr plugin config-dir <plugin_id>
herdr plugin action list [--plugin ID]
herdr plugin action invoke <action_id> [--plugin ID]
herdr plugin log list [--plugin ID] [--limit N]
herdr plugin pane open --plugin ID --entrypoint ID [--placement overlay|popup|split|tab|zoomed] [--width SIZE] [--height SIZE] [--workspace ID] [--target-pane PANE] [--direction right|down] [--cwd PATH] [--env KEY=VALUE] [--focus|--no-focus]
herdr plugin pane focus <pane_id>
herdr plugin pane close <pane_id>
```

**Topology commands (callable from inside a plugin entrypoint via `HERDR_BIN_PATH`):**
```
herdr workspace create [--cwd PATH] [--label TEXT] [--env KEY=VALUE] [--focus|--no-focus]
herdr workspace list

herdr tab create [--workspace <id>] [--cwd PATH] [--label TEXT] [--env KEY=VALUE] [--focus|--no-focus]
herdr tab list [--workspace <id>]

herdr pane split [<pane_id>|--pane ID|--current] --direction right|down [--ratio FLOAT] [--cwd PATH] [--env KEY=VALUE] [--focus|--no-focus]
herdr pane move <pane_id> --tab <tab_id> --split right|down [--target-pane ID]
herdr pane run <pane_id> <command>          # executes with Enter submission
herdr pane send-text <pane_id> <text>       # raw text, no Enter
herdr pane send-keys <pane_id> <key> [key...]
herdr pane read <pane_id> [--source visible|recent|recent-unwrapped|detection]

herdr agent start <name> --kind KIND --pane ID [--timeout MS] [-- <agent-args...>]
herdr agent prompt <target> <text> [--wait] [--until STATUS]
```

## Installation flow (for reference, not something a plugin author scripts)

`plugin install` accepts GitHub shorthand only (`owner/repo[/subdir]`). It clones with git, shows a trust preview, runs `[[build]]` commands, then registers. `plugin link` registers a local directory without building or cloning — the standard dev-loop command.

There is no `plugin update`; reinstalling from GitHub refreshes a plugin. Installing over a locally linked plugin is refused (unlink/uninstall the local registration first).

## Trust model

No sandboxing: build and runtime commands run as the installing user with the user's environment and full herdr CLI access. The only review surface before install is the manifest and scripts themselves (`--yes` skips the interactive preview for trusted sources; `--ref` pins a revision).

## Marketplace

Community plugins are indexed automatically from public GitHub repos tagged with the topic `herdr-plugin`; index refreshes every 30 minutes. No manual submission.

## v1 limitations

- No runtime action registration (actions are fixed at manifest time)
- No native non-terminal UI
- No plugin-managed storage API beyond `HERDR_PLUGIN_CONFIG_DIR` / `HERDR_PLUGIN_STATE_DIR`
- Link handlers always use Control (not Command on macOS)

## Example plugins repo

`ogulcancelik/herdr-plugin-examples` on GitHub — subdirectories include `agent-telegram-notify`, `github-link-preview`, `dev-layout-bootstrap`. Install one with e.g.:
```bash
herdr plugin install ogulcancelik/herdr-plugin-examples/agent-telegram-notify
```

## Pages not yet mirrored here

If a task needs socket API details, full config file syntax, or the complete CLI beyond the above, fetch:
- https://herdr.dev/docs/socket-api/
- https://herdr.dev/docs/config-reference/
- https://herdr.dev/docs/cli-reference/ (full page — this file only extracts the plugin-relevant subset)
