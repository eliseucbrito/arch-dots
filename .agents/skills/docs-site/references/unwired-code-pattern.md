# Documenting unwired code

The single highest-value thing this skill produces. A page that describes a mechanism as working when it isn't is worse than no page — it sends an agent (or a developer) to write code against a contract that doesn't hold, with a confidence a raw code search wouldn't have given them.

## How to find it

While reading source for Phase 2 (you're already reading it for the deep-page decision, this is the same pass, not an extra one), notice anything that *looks* wired but might not be:

- A decorator/annotation with full supporting infrastructure (guard, middleware, interceptor) but grep shows it's applied nowhere, or in far fewer places than the infrastructure implies.
- A DTO, schema, or type that exists and is exported but nothing imports it outside its own definition and test file.
- An exception/error class hierarchy where only the base class or one subclass is ever actually thrown; the rest exist "for when we need them."
- A config flag, feature flag, or env var that's read in one place but nothing branches on the value in any code path that matters.
- A field on a model that's populated from user input rather than from the source that would make it trustworthy (e.g. an audit field taken from a request body instead of the authenticated session).

The tell is usually: the mechanism has *more infrastructure* than its *usage count* would justify. Real, load-bearing mechanisms tend to have usage roughly proportional to their supporting code. A guard with zero annotated routes, a validator with zero callers, an exception hierarchy with one live subclass — these ratios are the signal.

## How to verify

Grep for real usage, excluding the definition and excluding tests that only exercise the mechanism in isolation:

```bash
grep -rn "<Symbol>" <src-root>/ --include="*.<ext>" | grep -v spec | grep -v "<definition-file>"
```

Be precise about what counts as "used." A test file that imports an exception class to verify a filter formats it correctly is testing the *filter*, not proving the exception is thrown anywhere in a real request path. Distinguish these in your grep and in your writing — don't let "it's exercised in a test" collapse into "it's used."

## How to write it

A callout box, placed exactly where a reader would otherwise assume the mechanism works, not tucked into a footnote at the bottom of the page:

```markdown
:::caution `@Roles` is applied to zero endpoints today
The guard, decorator, and role hierarchy are fully wired — `RolesGuard` is
registered globally and reads `@Roles(...)` metadata correctly. But no
controller in the codebase declares `@Roles` on any route. In practice, any
authenticated user can call every endpoint regardless of role. Re-verify with
`grep -rn "@Roles" src/modules | grep -v spec` before assuming a given route
is restricted — check the controller directly.
:::
```

Three things every instance of this pattern needs:

1. **What exists** — describe the infrastructure honestly; don't undersell it either. Half-built mechanisms are common and worth documenting accurately in both directions.
2. **What actually happens instead** — the reader's real question. If nothing enforces X, say what the absence of X actually means for someone hitting the system right now.
3. **A re-check command** — the exact grep/search, so the claim has an expiration test built in. Code changes; a paragraph of prose doesn't self-invalidate, but a command the reader can run does.

## Worked examples from different flavors

**Unused guard/decorator** (auth, validation, feature-gating):
> `@Roles` is applied to zero endpoints. The guard and hierarchy work; nothing invokes them per-route yet.

**Dead DTO/schema:**
> `PaginationQueryDto` and `PaginatedResponseDto` exist under `common/pagination/` but no service imports either. Every list endpoint returns the full unbounded result set — there's no `?page=`/`?limit=` support today.

**Unreferenced exception subclasses:**
> `AppException` has 10 domain-specific subclasses with structured error codes. Only one (`AccessDeniedException`, from the auth guard) is ever thrown in production code; the other nine are exercised only in the filter's own test file, which verifies the filter *would* handle them correctly if something threw them — nothing does.

**Field populated from the wrong source:**
> `created_by`/`updated_by` are nullable UUID columns, but populated from the request body, not the authenticated session — any caller can set them to an arbitrary value. Don't treat these as a trustworthy audit trail.

## Where this goes in the site structure

Put the callout on the page that documents the *mechanism*, not a separate "known issues" page — a separate page gets skipped by anyone reading the mechanism's real page, which is exactly the reader who needs to see it. If a component's overview table would otherwise show a column implying enforcement that doesn't exist yet (e.g. a "Required Role" column when no role is enforced), omit the column entirely rather than filling it with dashes that read as "not applicable" instead of "not built" — link to the mechanism's page instead, where the callout lives.

Re-run every unwired-code grep once more right before final delivery, not just when you first found the gap — you may have touched other parts of the codebase in the same session, and the whole point of this pattern is that it's a live claim, not a fact fixed at write time.
