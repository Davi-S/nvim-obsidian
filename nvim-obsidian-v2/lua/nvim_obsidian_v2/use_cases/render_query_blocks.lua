local M = {}

M.contract = {
    name = "render_query_blocks",
    version = "phase3-contract",
    dependencies = {
        "dataview",
        "vault_catalog",
        "parser.markdown",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        buffer = "integer",
        trigger = "on_open|on_save|manual",
    },
    output = {
        ok = "boolean",
        rendered_blocks = "integer|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    return { ok = false, reason = "phase3-contract-not-implemented" }
end

return M
