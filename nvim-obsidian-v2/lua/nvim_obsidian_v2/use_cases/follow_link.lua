local M = {}

M.contract = {
    name = "follow_link",
    version = "phase3-contract",
    dependencies = {
        "wiki_link",
        "vault_catalog",
        "ensure_open_note",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        line = "string",
        col = "integer",
        buffer_path = "string",
    },
    output = {
        ok = "boolean",
        status = "opened|created|ambiguous|invalid|missing_anchor",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    return { ok = false, reason = "phase3-contract-not-implemented" }
end

return M
