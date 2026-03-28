local primitives = require("nvim_obsidian.core.shared.primitives")

local M = {
    name = "wiki_link",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    models = {
        link_target = primitives.link_target,
    },
    api = {
        parse_at_cursor = {
            input = {
                line = "string",
                col = "integer",
            },
            output = {
                target = "link_target|nil",
                error = "domain_error|nil",
            },
        },
        resolve_target = {
            input = {
                target = primitives.link_target,
                candidate_notes = "note_identity[]",
            },
            output = {
                status = "resolved|missing|ambiguous",
                resolved_path = "string|nil",
                ambiguous_matches = "note_identity[]|nil",
            },
        },
    },
}

return M
