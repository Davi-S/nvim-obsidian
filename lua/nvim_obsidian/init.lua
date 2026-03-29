local bootstrap = require("nvim_obsidian.app.bootstrap")
local template_impl = require("nvim_obsidian.core.domains.template.impl")
local journal_placeholders = require("nvim_obsidian.app.journal_placeholders")

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

function M.template_register_placeholder(name, resolver)
    local registered = template_impl.register_placeholders({
        [name] = resolver,
    })

    if not registered or not registered.ok then
        local message = "failed to register template placeholder"
        if registered and registered.error and registered.error.message then
            message = registered.error.message
        end
        error("nvim-obsidian setup: " .. message, 2)
    end
end

M.journal = {}

function M.journal.register_placeholder(name, resolver, regex_fragment)
    local ok, message = journal_placeholders.register_placeholder(name, resolver, regex_fragment)
    if not ok then
        error("nvim-obsidian setup: " .. tostring(message or "failed to register journal placeholder"), 2)
    end
end

return M
