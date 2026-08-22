<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

<!-- nodeterm:get-linked-context:start -->
# Reading linked nodeterm nodes (get-linked-context)

When you run inside a nodeterm canvas session, this node may be linked to other agent
nodes (Claude, Codex or Gemini) or sticky notes by a context-link edge. You can READ a
linked node's context on demand — nothing is pushed automatically:

```sh
sh "/home/ecb/.config/node-terminal/context-links/context.sh" list                        # nodes you are linked to (start here)
sh "/home/ecb/.config/node-terminal/context-links/context.sh" summary --node <id|title>   # last lines of its conversation
sh "/home/ecb/.config/node-terminal/context-links/context.sh" transcript --node <id|title>
sh "/home/ecb/.config/node-terminal/context-links/context.sh" terminal --node <id|title>  # its recent terminal output
```

Only meaningful inside nodeterm (NODETERM_NODE_ID set) with a linked edge. If the CLI
says "Not a nodeterm session" or "No linked nodes", there is nothing to read — do not retry.
<!-- nodeterm:get-linked-context:end -->

<!-- nodeterm:manage-canvas:start -->
# Managing the nodeterm canvas (manage-nodeterm-canvas)

When you run inside a node on the nodeterm canvas, you can create and control other
nodes (the CLI refuses outside a nodeterm session — do not retry there). Every node
you open is connected to your node by an edge. Use this when the user asks you to open
sessions/nodes/terminals, split or parallelize work across subagents/agents/worktrees,
delegate parts of a task, organize the canvas into groups, or show them an
image/video/web page you produced.

```sh
sh "/home/ecb/.config/node-terminal/canvas-control/nodeterm.sh" <verb> [args]
```

Verbs:
- `list` — current nodes (id, kind, title). Start here when you need a node id.
- `open-terminal [--count N] [--cwd P] [--cmd C] [--group <id>] [--after <id,id>]` — open N plain terminals.
- `open-claude [--count N] [--cwd P] [--prompt T] [--group <id>] [--after <id,id>]` — open N Claude sessions.
- `open-agent --agent claude|codex|gemini|opencode|<custom-id> [--count N] [--cwd P] [--prompt T] [--group <id>] [--after <id,id>]` — open
  any agent CLI. `--group` parents the node(s) into a group frame; a worktree-bound group also
  hands its worktree path down as the cwd. `--after <id,id>` opens the node ARMED: it does not
  start until every listed station has gone idle, and is context-linked to them so it can read
  their work when it wakes — use it for "B needs what A produced" instead of polling. Only
  status-reporting agent nodes (claude/codex/gemini) may be waited on; a plain terminal never
  reports finishing, so waiting on one is refused.
- `show-image <path>` / `show-video <path>` — open a media file as a node.
- `show-web (--url U | --file P.html | --html "<...>")` — open a web viewer.
- `open-browser --url U` — open a navigable browser node.
- `group --nodes <id,id> [--label L]` — wrap TOP-LEVEL nodes in a new labeled frame (nodes already
  inside another frame are skipped — use `move` for those). `ungroup --group <id>` dissolves a frame,
  freeing its nodes to the top level. `move --nodes <id,id> [--group <id>]` reparents nodes INTO an
  existing frame (omit `--group`, or pass `top`/`none`, to pull them out to the top level) — this is
  how you move a node from one frame to another.
- `arrange --nodes <id,id> [--layout grid|row|column] [--cols N]` /
  `align --nodes <id,id> --edge left|right|top|bottom|hcenter|vcenter` — tidy a layout. Works on
  top-level nodes OR on the children of ONE frame (all ids must share a container — you cannot
  arrange across frames in one call); arranging a frame's children also shrinks the frame to fit.
- `link --to <id,id> [--from <id>]` — context-link nodes so each can READ the other's transcript
  on demand (nodeterm linked-context CLI). `--from` defaults to you; nothing is pushed into the
  linked sessions. Agent sessions you open are linked to you automatically — use `link` for nodes
  you did not open, or to link two OTHER nodes together.
- `verify --node <id> [--lenses correctness,security,tests] [--focus "..."] [--synthesis off]` — open a
  review panel over that node's work: one reviewer per lens, each armed behind the target and linked
  to it, plus a judge armed behind the panel that merges the findings into one verdict. Reviewers are
  told not to change files. Prefer this over asking one agent to double-check itself.
- `spawn-team --label L --team '[{"title":"UI","prompt":"...","agent":"claude"}]'` — one agent per
  role (max 8), arranged in a grid, wrapped in a labeled group, each connected + context-linked to you.
- `open-worktree --branch <name> [--base <ref>] [--path P] [--group <id>]` — create a git worktree
  wrapped in a bound group frame (terminals inside it run in the worktree). Local projects only.
- `close-worktree --group <id> [--mode unbind|remove]` — unbind keeps the directory; remove asks
  the user to confirm deletion.
- `branch --node <id>` — branch a Claude node's conversation (Claude nodes only).
- `rename --node <id> --title "New Name"` — rename any node (terminals, groups, stickies…).
- `write --node <id> --text "..."` / `close --node <id>` — type into / close a node.
  Both ask the user to confirm a dialog and may be denied.
- `board` — the project's kanban board: every column (id + title) and the session cards in each,
  plus the virtual Ungrouped column. Start here when you need a column id or want the board state.
- `assign --node <id> [--column <id|title>] [--before <nodeId>]` — move a session card to a column
  (match by column id or title). Omit `--column` (or pass `ungrouped`) to send it back to Ungrouped.
  `--before <nodeId>` drops it above that card within the column. This is board metadata only — it
  never moves the node on the canvas or changes its group. Use it to reflect progress: move a card
  to your "In Progress"/"Done" column as work advances.

Orchestration ("Build with Nodeterm orchestration"): first decide what is genuinely
independent — for every "and then", ask whether the next step READS the previous step's
output. If not, they are separate stations, open them all at once; if it does, open the
downstream one with `--after <upstream-id>` and it starts itself when the upstream goes
idle (do not poll for that yourself). Then break the task into 2-5 workstreams;
per stream `open-worktree --branch <slug>` then `open-agent --agent claude --group <groupId>
--prompt "<concrete task>"` (each stream on its own branch, no tree conflicts). Members land
in grid slots inside the frame automatically; align the frames themselves with
`arrange --nodes <groupId,…> --layout row` (pass GROUP ids — arrange/align are top-level
only) and `rename` each by subject. When a station goes idle, READ what it did through the
context link (the linked-context CLI — see the get-linked-context section in your global
agent instructions) and reconcile the streams into ONE synthesis yourself; a station you
never read is one you cannot vouch for. The user merges when a stream is done;
`close-worktree --group <id>` releases a finished station.
<!-- nodeterm:manage-canvas:end -->
