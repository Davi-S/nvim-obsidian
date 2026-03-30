# nvim-obsidian Implementation Review

Date: 2026-03-30
Scope: Contract and user guide alignment review.

## Findings

1. Insert template no-arg divergence
- ✅ RESOLVED: Contract updated to require argument (type or path).
- Updated PRODUCT_CONTRACT.md, UX_BEHAVIOR_CONTRACT.md, and USER_GUIDE.md.

2. Follow invalid cursor behavior divergence
- Contract says invalid/non-wikilink follow should no-op.
- Current command emits warning for invalid cursor context.
