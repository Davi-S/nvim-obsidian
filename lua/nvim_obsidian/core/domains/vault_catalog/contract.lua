local primitives = require("nvim_obsidian.core.shared.primitives")

---Domain contract: in-memory catalog of vault note identities.
---
---Provides normalized note upsert/remove and identity-token lookup operations.
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
        find_by_identity_token = {
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
