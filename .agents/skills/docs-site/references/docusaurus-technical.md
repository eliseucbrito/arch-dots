# Docusaurus technical setup

Mechanical details specific to Docusaurus 3. Read this before the first `npm run build`, since two of these (broken-link enforcement, the slug-stripping issue) will otherwise cost a debugging detour that looks like a content bug but isn't.

## Enforce broken-link checking from the start

In `docusaurus.config.ts`:

```ts
onBrokenLinks: 'throw',
```

Without this, a bad internal link silently ships. With it, `npm run build` fails on any link or the missing target, which is what makes "build after each batch of pages" in Phase 4 an actual verification step rather than a formality. Also check for `onBrokenAnchors` (Docusaurus 3.5+) — by default it only *warns* on a broken `#anchor` fragment, not fails the build. If precise cross-references matter (they do — a wrong anchor sends a reader to the top of the wrong section silently), treat anchor warnings in the build output as build failures worth fixing before moving on, even though the process exit code won't force you to.

## Category ordering: `_category_.json`

One per directory, controls sidebar position and the auto-generated index page:

```json
{
  "label": "Architecture",
  "position": 2,
  "link": {
    "type": "generated-index",
    "description": "One-line description of what this section covers."
  }
}
```

Don't rely on filename ordering (`01-foo.md`, `02-bar.md`) for section-level ordering if you're also fighting the slug-stripping issue below — `_category_.json`'s `position` field is unambiguous and doesn't interact with slugs at all.

## Numbered-filename slug stripping (ADR/decision pages)

Docusaurus strips a leading numeric prefix from a filename when generating the default slug, treating it as ordering metadata rather than part of the URL. `docs/adr/001-data-schema.md` does **not** become `/adr/001-data-schema` — it becomes `/adr/data-schema`.

This breaks any cross-reference written assuming the numbered slug (`[ADR-001](/adr/001-data-schema)`), and the break is silent until `onBrokenLinks: 'throw'` catches it at build time — which is exactly why building after each batch matters, this is the single most common broken-link cause in a decisions/ or adr/ directory.

Fix: set `slug` explicitly in frontmatter on any numbered file where you want the number to survive in the URL:

```yaml
---
title: "ADR-001: Data Schema"
slug: /adr/001-data-schema
---
```

This also makes the URL stable if a decision record ever gets renumbered — the frontmatter slug doesn't have to change just because the filename does, and vice versa.

## Anchor slugs on admonition-heavy pages

Docusaurus generates heading anchors from real `##`/`###` headings using GitHub-style slugging (lowercase, spaces to hyphens, punctuation stripped). It does **not** generate an anchor for admonition titles (`:::caution Some Title`) — those aren't headings, they're directive syntax, so a link like `#some-title` pointing at a caution box's title will silently 404 (or warn, per `onBrokenAnchors` above) even though the text is visibly right there on the page.

When cross-referencing into a page that has an unwired-code callout (see `references/unwired-code-pattern.md`), link to the nearest real `##`/`###` heading above or around the callout, not to a slug guessed from the callout's own title. Two ways to avoid guessing wrong:

1. Build and let the checker report the broken anchor (Docusaurus's error message shows source and target — mechanical to fix, and confirms the correct target rather than trusting a hand-computed guess).
2. For headings with backticks, punctuation, or symbols (`` ## `IDENTITY_SOURCE` — the DI port ``), don't hand-compute the slug — punctuation-stripping rules are not always intuitive (a heading like `` ## Repository — wraps `Repository<T>`, doesn't extend it `` slugs in a way that's easy to get wrong by hand). Build first, read the real slug out of the broken-anchor error or the rendered HTML, then fix the link.

## Verifying pages actually rendered (not just built without errors)

A clean build proves no broken links, not that content renders correctly — an admonition with malformed MDX syntax can still "build" while rendering as broken/empty. After a full section is done, serve the built output and check a couple of pages by content, not just status code:

```bash
npm run build
npm run serve -- --port <port> --no-open &
curl -s http://localhost:<port>/<path> | grep -o "<Some Known Heading Text>"
```

A `200` status code alone doesn't prove the page contains what you wrote — grep the served HTML for a string you know should be there.

## Templates directory placement

If the site's own `contributing/templates/*.md` files (see `templates/` in this skill) live under the `docs/` tree so Docusaurus can serve them, they'll get their own routes (e.g. `/contributing/templates/adr`) unless excluded. This is usually fine — it doesn't collide with real content pages as long as real ADR/decision pages use explicit `slug:` frontmatter (see above) rather than relying on default slugging, since the default slug for `templates/adr.md` and a real `adr/001-foo.md` land in different namespaces (`/contributing/templates/adr` vs `/adr/...`) and won't collide regardless — but verify this with a build rather than assuming it, since exclude patterns and route base paths vary by config.
