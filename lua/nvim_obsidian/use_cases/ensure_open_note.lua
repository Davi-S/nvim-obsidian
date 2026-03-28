local M = {}

M.contract = {
    name = "ensure_open_note",
    version = "phase3-contract",
    dependencies = {
        "journal",
        "vault_catalog",
        "template",
        "filesystem.io",
        "neovim.navigation",
    },
    input = {
        title_or_token = "string",
        create_if_missing = "boolean",
        origin = "omni|journal|link",
    },
    output = {
        ok = "boolean",
        path = "string|nil",
        created = "boolean|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    return { ok = false, reason = "phase3-contract-not-implemented" }
end

return M
