# ADR-003: Public API and Command Surface Philosophy

## Status

Accepted

## Date

March 28, 2026

## Context

V2 prioritizes standalone UX quality rather than backward compatibility with V1 configuration internals. Phase 0 defines a canonical command surface and clarifies that some V1-style commands are not in primary end-user workflow.

Implementation needs a stable policy for what is public and stable versus what remains internal and refactorable.

## Decision Drivers

- Keep user-facing behavior stable and explicit.
- Limit accidental public surface growth.
- Allow internal refactoring without breaking workflows.
- Align with Omni-first note creation workflow.

## Selected Approach

Minimal stable public surface (commands + documented config).

## Decision

Adopt a minimal, explicit public API philosophy:

Public and stable in V2.0:
- Documented command set.
- Documented configuration surface and defaults.
- User-visible behavior from product and UX contracts.
- Documented setup helper APIs:
	- `require("nvim_obsidian").template_register_placeholder(name, resolver)`
	- `require("nvim_obsidian").journal.register_placeholder(name, resolver, regex_fragment)`
	- `require("nvim_obsidian").journal.month_name(month, locale)`
	- `require("nvim_obsidian").journal.weekday_name(wday, locale)`
	- `require("nvim_obsidian").journal.parse_month_token(token, locale)`
	- `require("nvim_obsidian").journal.render_title(format, date, locale)`
	- `require("nvim_obsidian").wiki_link_under_cursor([line], [col])`
	- `require("nvim_obsidian").is_inside_vault([path])`

Internal and non-stable by default:
- Internal module names and wiring.
- Service composition details.
- Adapter implementation details.

Canonical V2.0 command set:
- :ObsidianOmni
- :ObsidianToday
- :ObsidianNext
- :ObsidianPrev
- :ObsidianFollow
- :ObsidianBacklinks
- :ObsidianSearch
- :ObsidianReindex
- :ObsidianInsertTemplate [type|path]
- :ObsidianRenderDataview

## Consequences

### Positive

- Stable user-facing contract.
- Better freedom to refactor internals safely.
- Clear support expectations.

### Negative

- Fewer sanctioned extension points initially.
- Requests for internal API stability may increase over time.

## Enforcement

- Only documented commands/config are treated as stable contract.
- Any new public command or config key requires contract update and ADR review.
- Internal modules are considered private unless explicitly promoted.

## Related Documents

- ../PRODUCT_CONTRACT.md
- ../UX_BEHAVIOR_CONTRACT.md
- ../PROJECT_CONTEXT.md
