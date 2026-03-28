---@diagnostic disable: undefined-global

local M = {}

M.defaults = {
    log_level = "warn",
}

function M.normalize(user_opts)
    local opts = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})
    return opts
end

return M
