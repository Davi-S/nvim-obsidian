local bootstrap = require("nvim_obsidian.app.bootstrap")

local M = {}
local state = {
    container = nil,
    normalized_input = nil,
}

local function deep_equal(a, b)
    if vim and type(vim.deep_equal) == "function" then
        return vim.deep_equal(a, b)
    end
    return false
end

local function deep_copy(v)
    if vim and type(vim.deepcopy) == "function" then
        return vim.deepcopy(v)
    end
    return v
end

function M.setup(opts)
    local input = opts or {}

    if state.container ~= nil and deep_equal(input, state.normalized_input) then
        return state.container
    end

    local container = bootstrap.start(input)
    state.container = container
    state.normalized_input = deep_copy(input)
    return container
end

return M
