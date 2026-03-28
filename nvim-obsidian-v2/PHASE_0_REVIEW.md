# Phase 0 Review Snapshot (Revised)

Date: March 28, 2026
Status: Updated after clarification round

This snapshot supersedes the previous Phase 0 review summary.

## Revised Outcomes

1. Product contract updated to omni-first workflow and explicit command set.
2. UX behavior updated with open/create semantics for journal time travel commands.
3. Domain ownership updated to remove periodic reconcile ownership and remove deprecated commands.
4. Project context updated so there are no remaining contradictions with revised Phase 0 assumptions.

## Key Clarifications Applied

- No periodic automatic reconciliation loop in baseline.
- Case-sensitive note identity with case-insensitive search/discovery.
- No :ObsidianYesterday/:ObsidianTomorrow.
- :ObsidianNew/:ObsidianNewFromTemplate are not part of the primary end-user workflow, but may exist as singular-responsibility/internal building blocks.
- Placeholder model is user-registration only.
- No template inheritance.
- Journal model requires dedicated subdir per note type.
- Link follow behavior now covers missing note creation and missing anchor warnings.
- Omni matcher uses title/alias, not tags.
- Omni searchable objects are ordered title, aliases, relpath.
- Link resolution uses target token only; display alias does not resolve targets.
- Omni force-create is available in partial/no-match states; full matches open existing notes.
- Omni creation routing is journal-classifier-first, else standard new_notes_subdir.
- Omni display follows v1 policy and separator token is configurable.
- Omni discovery uses fuzzy matching on all three searchable fields (title, aliases, relpath).
- Telescope default open actions are preserved.
- V1 and V2 are not intended to run simultaneously.

## Source of Truth Files

- docs/PRODUCT_CONTRACT.md
- docs/DOMAIN_OWNERSHIP_MAP.md
- docs/UX_BEHAVIOR_CONTRACT.md
- PROJECT_CONTEXT.md

