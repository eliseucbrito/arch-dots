# Phase 1 planning questions

Pass these to `AskUserQuestion` as a single batch (one round, all four together) after a quick read of the repo — enough to know the stack and whether existing docs exist, not enough to have opinions about structure yet. If the repo has no existing docs, drop question 1.

The option previews below are starting points — adapt the concrete filenames/paths to the actual repo before asking.

```json
{
  "questions": [
    {
      "question": "What happens to the existing docs ([list what you found: README.md, ARCHITECTURE.md, wiki, etc.])?",
      "header": "Migration",
      "options": [
        {
          "label": "Docs-site is the single source",
          "description": "Move the content into the new site (translated/reformatted as needed). The old file becomes a short pointer or is deleted. One place to update, no drift, but loses whatever made the old doc the thing people already knew to open.",
          "preview": "OLD-DOC.md   → deleted, content moves into\n             docs-site/docs/<section>/*.md"
        },
        {
          "label": "Docs-site links out, old doc stays authoritative",
          "description": "The old doc keeps its role (often because it's the literal entry point before the site is even reachable, e.g. a setup README). The site references it instead of duplicating it. Zero migration cost, but the new site is incomplete on its own.",
          "preview": "OLD-DOC.md   (unchanged, stays authoritative)\ndocs-site    links to it, doesn't duplicate"
        },
        {
          "label": "Mirror with a source-of-truth note",
          "description": "The doc's real home is an external system (Notion, Confluence, a ticket). Mirror the body verbatim (original language) into the site, add a short section on what it binds in code, and mark which system wins on conflict. Right choice whenever an external sync exists or is planned — translating first would break that sync.",
          "preview": "docs-site/docs/decisions/foo.md\n  ---\n  notion: <link>\n  sync: body-managed\n  ---\n  :::info Source of truth\n  Mirrors Notion. Notion wins on conflict.\n  :::\n  ## What this binds in code\n  ...\n  ## Body (verbatim, original language)\n  ..."
        }
      ],
      "multiSelect": false
    },
    {
      "question": "How should the site be optimized for AI agents reading it from disk?",
      "header": "Agent access",
      "options": [
        {
          "label": "Frontmatter + AGENTS.md routing table (Recommended)",
          "description": "Every page gets summary/source frontmatter; AGENTS.md gains a table mapping question → page. Agents read the relevant page directly off disk. No build-step dependency, nothing extra to keep in sync beyond the pages themselves.",
          "preview": "---\ntitle: Module Anatomy\nsummary: The pattern every module follows\nsource: [src/modules/example/**]\n---\n\n# AGENTS.md\n| Need to know | Read |\n|---|---|\n| module pattern | docs/architecture/module-anatomy.md |"
        },
        {
          "label": "Above + llms.txt",
          "description": "Everything in the first option, plus a generated static/llms.txt so the deployed site is also agent-readable over HTTP, per the emerging convention. One more file to regenerate when pages change.",
          "preview": "docs-site/static/llms.txt\n\n# Project Name\n> One-line description\n\n## Architecture\n- [Module Anatomy](/architecture/module-anatomy): ..."
        },
        {
          "label": "Frontmatter only",
          "description": "Pages carry frontmatter but there's no routing index. Agents discover pages by globbing the docs directory. Simplest, but costs the agent tokens finding the right page instead of being pointed at it.",
          "preview": "---\ntitle: Module Anatomy\nsummary: ...\n---\n(no AGENTS.md changes)"
        }
      ],
      "multiSelect": false
    },
    {
      "question": "[Present the deep-page criterion you found in Phase 2, with the concrete component names it selects, as a proposal to confirm — not a blind menu. Example wording below.]",
      "header": "Component depth",
      "options": [
        {
          "label": "[Criterion] + reference table (Recommended)",
          "description": "State the exact rule from Phase 2 and which components it selects today, e.g.: 'A component gets a page when it does more than the standard N operations over one entity. Today that's X and Y; the other N components become one row each in a reference table.'",
          "preview": "architecture/pattern.md   ← worked via <cleanest instance>\n<components>/overview.md ← table, all rows\n<components>/X.md         ← deep page (meets criterion)\n<components>/Y.md         ← deep page (meets criterion)"
        },
        {
          "label": "Pattern + table only, no deep pages yet",
          "description": "Even components with real logic get folded into expanded table rows or a prose section at the bottom of the overview, rather than their own page. Leanest option, but works poorly once a component's logic needs more than a sentence or two to explain correctly.",
          "preview": "architecture/pattern.md\n<components>/overview.md  ← table + prose section per deviation"
        },
        {
          "label": "One page per component",
          "description": "Every component gets a full page regardless of complexity. Most conventional and most discoverable per-component, but for a codebase with several near-identical components this means writing (and later syncing) the same page N times.",
          "preview": "<components>/a.md\n<components>/b.md\n<components>/c.md\n... one per component, no differentiation by complexity"
        }
      ],
      "multiSelect": false
    },
    {
      "question": "Should the docs-contribution ruleset be a published page, and should AGENTS.md enforce it?",
      "header": "Doc rules",
      "options": [
        {
          "label": "Yes — published page + AGENTS.md enforcement (Recommended)",
          "description": "A documentation-guide page holds the rules and the deep-page criterion verbatim; AGENTS.md maps source paths to the doc pages that must update in the same commit when that path changes.",
          "preview": "contributing/documentation-guide.md\ncontributing/templates/*.md\n\n# AGENTS.md\n| Changed | Update |\n|---|---|\n| src/common/**  | architecture/*.md |\nSame commit."
        },
        {
          "label": "Published page only",
          "description": "The guide exists and is linked from the site, but nothing in AGENTS.md enforces checking it. Relies on reviewers noticing stale docs.",
          "preview": "contributing/documentation-guide.md\n(no AGENTS.md sync table)"
        },
        {
          "label": "Rules stay out of the site",
          "description": "Rules live only in AGENTS.md/CLAUDE.md, never published as a site page. Keeps the site purely product/technical, at the cost of the rules being less discoverable to a human contributor browsing the site itself.",
          "preview": "AGENTS.md → rules + routing table\ndocs-site → no meta pages"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

## Notes on asking well

- Question 3 (component depth) should never be asked before Phase 2 exploration — you need real component names and a real criterion to present, not a hypothetical. If you find yourself writing this question before reading any source, stop and go explore first.
- If the user's answer to question 1 reveals an external sync is already in progress or planned (a common answer), that's worth a follow-up note in the plan, not a new question round — see the "Mirror with a source-of-truth note" preview for how to structure the page so a future sync can overwrite the body cleanly (separate frontmatter from body, keep the body verbatim rather than reformatted).
- Batch all four into one `AskUserQuestion` call. Don't dribble them out one at a time — the user should see the whole shape of the decision space at once.
