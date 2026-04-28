---Domain contract: candidate ranking and display labeling for search UX.
---
---The implementation is deterministic and side-effect free so callers can reuse
---it in picker and completion pathways.
local M = {
    name = "search_ranking",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    api = {
        score_candidates = {
            input = {
                query = "string",
                candidates = "table[]",
            },
            output = {
                ranked = "table[]",
            },
        },
        select_display = {
            input = {
                query = "string",
                candidate = "table",
                separator = "string",
            },
            output = {
                label = "string",
            },
        },
    },
}

return M
