---
name: herdr-plugin
description: Scaffold, implement, and iterate on herdr plugins (the herdr.dev terminal multiplexer's plugin system) — manifest (herdr-plugin.toml), actions, events, panes, link handlers, keybindings, in any language (Bash, JS, Lua, Rust, any argv command). Use when: herdr plugin, herdr-plugin.toml, create a herdr plugin, herdr action, herdr pane plugin, herdr link handler, herdr startup hook, herdr plugin install/link.
---

# Herdr Plugin

Build plugins for [herdr](https://herdr.dev), a terminal multiplexer. Herdr owns installation, manifest validation, keybindings, panes, events, and invocation context; the plugin owns implementation and state. A plugin is a directory with a `herdr-plugin.toml` manifest plus one or more executable scripts/binaries — any language that can be invoked as argv works.

Full field-by-field manifest spec, env vars, and CLI commands: `references/reference.md`. Read it before writing the manifest — don't guess field names.

## Workflow

1. **Clarify the entrypoint kind(s) needed.** Ask only if genuinely ambiguous — usually the user's request implies it:
   - **Action** — user explicitly triggers it (keybinding or `herdr plugin action invoke`). One-shot command, runs, exits.
   - **Event hook** — fires automatically on a herdr event (currently documented: `worktree.created`). Runs, exits.
   - **Pane** — a long-lived or interactive UI surface (overlay/popup/split/tab/zoomed) backed by a running command (e.g. a TUI).
   - **Startup hook** — runs once per session when the plugin's socket becomes ready, to restore persisted state. Not a daemon — restore state then exit.
   - **Link handler** — regex-matches terminal URLs on Ctrl+click and routes to an action.

   A plugin can mix several of these.

2. **Scaffold the directory.**
   ```
   my-plugin/
     herdr-plugin.toml
     <entrypoint scripts>
   ```
   Pick `id` as `ASCII letters/digits/./:/_/-`, no spaces. Set `min_herdr_version` to whatever the user's installed herdr reports (`herdr --version`) unless told otherwise.

3. **Write the manifest** using `references/reference.md` as the field source of truth. Only declare the sections the plugin actually uses — don't add empty `[[build]]`/`[[startup]]` sections speculatively.

4. **Implement entrypoints.** Every entrypoint command:
   - Runs with the plugin directory as CWD.
   - Gets `HERDR_BIN_PATH` to call back into the full herdr CLI (`herdr workspace|tab|pane|worktree|agent ...` — see reference), and `HERDR_SOCKET_PATH` for raw socket access if CLI shelling isn't enough.
   - Gets `HERDR_PLUGIN_CONTEXT_JSON` for the invocation context (workspace/tab/pane/worktree/agent/selection/clicked-url, whichever apply).
   - Must use `HERDR_PLUGIN_CONFIG_DIR` for user config and `HERDR_PLUGIN_STATE_DIR` for runtime state — never write durable state into `HERDR_PLUGIN_ROOT` (GitHub installs are managed checkouts that can be overwritten/removed).

5. **Test locally without installing.**
   ```bash
   herdr plugin link /path/to/my-plugin
   herdr plugin action list --plugin <id>
   herdr plugin action invoke <id>.<action>
   herdr plugin pane open --plugin <id> --entrypoint <pane_id>
   herdr plugin log list --plugin <id>
   ```
   `plugin link` skips `[[build]]` commands — run the build manually first if the entrypoint needs a build step (e.g. `npm run build`).

6. **Wire a keybinding** if the user wants one, in *their* herdr config (not the plugin manifest) using `type = "plugin_action"` and the fully-qualified `plugin.id.action` (see reference).

7. **Iterate**: re-run the action/pane, check `herdr plugin log list`, adjust. Keep the manifest and script in sync — a stale `contexts`/`command` mismatch is the most common failure mode.

## Publishing (only if asked)

No `herdr plugin update` — users reinstall from GitHub to refresh. Tag the repo with the GitHub topic `herdr-plugin` to appear in the marketplace index (refreshes every 30 min, no manual submission). Mention in the manifest/README that build+runtime commands execute unsandboxed as the installing user — keep the plugin's own footprint auditable (readable scripts, no obfuscation, no undocumented network calls) since that's the only review a user gets before installing.

## Gotchas worth surfacing to the user

- Installing over a locally linked plugin is refused — `unlink`/`uninstall` the local one first.
- Startup hooks are not supervised daemons; a long-running startup command will just look hung.
- Link handlers use the Control modifier on **all** platforms, including macOS (not Command).
- v1 has no runtime action registration, no native non-terminal UI, and no plugin-managed storage API beyond the config/state dirs.
