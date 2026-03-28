local M = {}

M.contract = {
    name = "search_open_create",
    version = "phase3-contract",
    dependencies = {
        "search_ranking",
        "vault_catalog",
        "journal",
        "ensure_open_note",
        "picker.telescope",
    },
    input = {
        query = "string",
        allow_force_create = "boolean",
    },
    output = {
        ok = "boolean",
        action = "opened|created|cancelled",
        path = "string|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    return { ok = false, reason = "phase3-contract-not-implemented" }
end

return M
