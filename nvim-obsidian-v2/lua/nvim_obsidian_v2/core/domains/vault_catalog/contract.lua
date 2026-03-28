local primitives = require("nvim_obsidian_v2.core.shared.primitives")

local M = {
    name = "vault_catalog",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    models = {
        note_identity = primitives.note_identity,
    },
    api = {
        upsert_note = {
            input = {
                note = primitives.note_identity,
            },
            output = {
                ok = "boolean",
                error = "domain_error|nil",
            },
        },
        remove_note = {
            input = {
                path = "string",
            },
            output = {
                ok = "boolean",
                error = "domain_error|nil",
            },
        },
        find_by_title_or_alias = {
            input = {
                token = "string",
            },
            output = {
                matches = "note_identity[]",
            },
        },
    },
}

return M
