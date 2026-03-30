# nvim-obsidian Implementation Review

Date: 2026-03-30
Scope: Contract and user guide alignment review.

## Findings

1. Note creation path routing divergence
- Guide shows relative `new_notes_subdir` routed inside vault.
- Creation path joins filename directly against `new_notes_subdir`/journal subdir without rebasing to `vault_root`.

1. Wikilink case-sensitivity divergence
- Contract says wikilink target resolution is case-sensitive.
- Follow-link missing target path delegates to ensure-open lookup that can fall back to case-insensitive matching.

1. Insert template no-arg divergence
- Contract says `:ObsidianInsertTemplate` with no argument opens picker.
- Current implementation requires explicit query/path and returns not found otherwise.

1. Completion scope divergence
- Contract includes headings and block IDs in cmp candidates.
- Current source focuses on note title/alias candidates only; registration lifecycle is not fully evident in bootstrap.

1. Dataview scope divergence
- `dataview.render.scope` is validated but not applied in runtime trigger handling.

1. Follow invalid cursor behavior divergence
- Contract says invalid/non-wikilink follow should no-op.
- Current command emits warning for invalid cursor context.

## Notes

- Product and guide documents have a policy tension around journal placeholders.
- This review was static code-vs-contract analysis.