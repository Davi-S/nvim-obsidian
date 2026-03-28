local M = {}

M.contract = {
    name = "reindex_sync",
    version = "phase3-contract",
    dependencies = {
        "filesystem.io",
        "filesystem.watcher",
        "vault_catalog",
        "parser.frontmatter",
        "neovim.notifications",
    },
    input = {
        mode = "startup|manual|event",
        event = "table|nil",
    },
    output = {
        ok = "boolean",
        stats = "table|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    return { ok = false, reason = "phase3-contract-not-implemented" }
end

return M
