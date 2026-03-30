# nvim-obsidian Implementation Review

Date: 2026-03-30
Scope: Contract and user guide alignment review.

## Findings

1. Watcher pipeline divergence
- Contract requires event sync for create/modify/delete/rename.
- Startup starts watcher, but no event handler bridge is wired to reindex event mode.
- Watcher event mapping currently emits only rename/modify and does not distinguish create/delete.

2. Note creation path routing divergence
- Guide shows relative `new_notes_subdir` routed inside vault.
- Creation path joins filename directly against `new_notes_subdir`/journal subdir without rebasing to `vault_root`.

3. Wikilink case-sensitivity divergence
- Contract says wikilink target resolution is case-sensitive.
- Follow-link missing target path delegates to ensure-open lookup that can fall back to case-insensitive matching.

4. Omni create/force-create divergence
- Force-create key behavior and create flow did not reliably use configured key and live prompt content in Telescope payload mode.

5. Insert template no-arg divergence
- Contract says `:ObsidianInsertTemplate` with no argument opens picker.
- Current implementation requires explicit query/path and returns not found otherwise.

6. Completion scope divergence
- Contract includes headings and block IDs in cmp candidates.
- Current source focuses on note title/alias candidates only; registration lifecycle is not fully evident in bootstrap.

7. Dataview scope divergence
- `dataview.render.scope` is validated but not applied in runtime trigger handling.

8. Follow invalid cursor behavior divergence
- Contract says invalid/non-wikilink follow should no-op.
- Current command emits warning for invalid cursor context.

## Notes

- Product and guide documents have a policy tension around journal placeholders.
- This review was static code-vs-contract analysis.