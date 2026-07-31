---
title: <Concept Name>
summary: One sentence — what a reader gets from this page without opening it.
source: [<globs of the code this page documents>]
audience: [developer, agent]
---

Use this template for architecture/cross-cutting pages: explaining how a mechanism works end to
end, not a specific component's business rules (use `module-page.md` for that) or an external
decision record (use `adr.md` for that).

## What it is

One or two sentences, then the mechanism itself — the actual flow through real code, not a
restatement of which files are involved. Wherever possible, trace a concrete example (a real
request, a real piece of data) through the mechanism rather than describing it in the abstract.
Abstract description reads fine and verifies nothing; a worked example is falsifiable by anyone
reading the same code.

## Where it lives

Point at the specific files (`path/to/file.ext:line` where a line reference adds real precision,
not decoration), not just the containing directory.

## How it's used elsewhere

Cross-links to components or other architecture pages that depend on this mechanism.

## Known gaps

If part of the mechanism is unwired, stubbed, or only partially applied, say so here — see the
unwired-code pattern. This section is not optional filler; if there's nothing to put here, that's
worth double-checking rather than assuming, since fully-wired cross-cutting mechanisms are rarer
than they look from the outside.
