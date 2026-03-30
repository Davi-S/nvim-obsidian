local bootstrap = require("nvim_obsidian.app.bootstrap")
local template_impl = require("nvim_obsidian.core.domains.template.impl")
local journal_placeholders = require("nvim_obsidian.app.journal_placeholders")

local M = {}
local state = {
    container = nil,
    normalized_input = nil,
}

local function current_line_and_col()
    if not vim or type(vim) ~= "table" or type(vim.api) ~= "table" then
        return nil, nil
    end

    if type(vim.api.nvim_get_current_line) ~= "function" then
        return nil, nil
    end

    if type(vim.api.nvim_win_get_cursor) ~= "function" then
        return nil, nil
    end

    local ok_line, line = pcall(vim.api.nvim_get_current_line)
    if not ok_line then
        return nil, nil
    end

    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok_cursor or type(cursor) ~= "table" then
        return nil, nil
    end

    local cursor_col = tonumber(cursor[2]) or 0
    return line, cursor_col + 1
end

local function current_buffer_path_or_cwd()
    if not vim or type(vim) ~= "table" then
        return nil
    end

    local candidate = nil
    if type(vim.fn) == "table" and type(vim.fn.expand) == "function" then
        local ok_file, current_file = pcall(vim.fn.expand, "%:p")
        if ok_file and type(current_file) == "string" and current_file ~= "" then
            candidate = current_file
        end
    end

    if candidate == nil and type(vim.fn) == "table" and type(vim.fn.getcwd) == "function" then
        local ok_cwd, cwd = pcall(vim.fn.getcwd)
        if ok_cwd and type(cwd) == "string" and cwd ~= "" then
            candidate = cwd
        end
    end

    return candidate
end

local function normalize_slashes(path)
    local p = tostring(path or "")
    p = p:gsub("\\", "/")
    p = p:gsub("//+", "/")
    return p
end

local function has_path_prefix(path, prefix)
    if type(path) ~= "string" or type(prefix) ~= "string" then
        return false
    end

    local normalized_path = normalize_slashes(path)
    local normalized_prefix = normalize_slashes(prefix)
    if normalized_path == "" or normalized_prefix == "" then
        return false
    end

    if normalized_prefix:sub(-1) ~= "/" then
        normalized_prefix = normalized_prefix .. "/"
    end

    if normalized_path == normalized_prefix:sub(1, -2) then
        return true
    end

    return normalized_path:sub(1, #normalized_prefix) == normalized_prefix
end

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

function M.wiki_link_under_cursor(line, col)
    local container = state.container
    local wiki_link = container and container.wiki_link
    if not wiki_link or type(wiki_link.parse_at_cursor) ~= "function" then
        error("nvim-obsidian not initialized; call setup() first", 2)
    end

    local cursor_line = line
    local cursor_col = col

    if cursor_line == nil or cursor_col == nil then
        cursor_line, cursor_col = current_line_and_col()
    end

    return wiki_link.parse_at_cursor(cursor_line, cursor_col)
end

function M.is_inside_vault(path)
    local container = state.container
    local config = container and container.config
    local vault_root = config and config.vault_root
    if type(vault_root) ~= "string" or vault_root == "" then
        error("nvim-obsidian not initialized; call setup() first", 2)
    end

    local candidate = path
    if candidate == nil then
        candidate = current_buffer_path_or_cwd()
    end

    return has_path_prefix(candidate, vault_root)
end

return M
