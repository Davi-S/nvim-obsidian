# nvim-obsidian Implementation Review

Date: 2026-03-30
Scope: Contract and user guide alignment review.

## Findings

1. Wikilink case-sensitivity divergence
- Contract says wikilink target resolution is case-sensitive.
- Follow-link missing target path delegates to ensure-open lookup that can fall back to case-insensitive matching.

1. Insert template no-arg divergence
- Contract says `:ObsidianInsertTemplate` with no argument opens picker.
- Current implementation requires explicit query/path and returns not found otherwise.

1. Completion scope divergence
- Contract includes headings and block IDs in cmp candidates.
- Current source focuses on note title/alias candidates only; registration lifecycle is not fully evident in bootstrap.

1. Follow invalid cursor behavior divergence
- Contract says invalid/non-wikilink follow should no-op.
- Current command emits warning for invalid cursor context.
