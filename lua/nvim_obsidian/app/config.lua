---@diagnostic disable: undefined-global

local M = {}

M.defaults = {
    log_level = "warn",
    locale = "en-US",
    force_create_key = "<S-CR>",
    dataview = {
        enabled = true,
        render = {
            when = { "on_open", "on_save" },
            scope = "event",
            patterns = { "*.md" },
        },
        placement = "below_block",
        messages = {
            task_no_results = {
                enabled = true,
                text = "Dataview: No results to show for task query.",
            },
        },
    },
}

local function is_absolute_path(path)
    if type(path) ~= "string" then
        return false
    end
    if path:match("^/") then
        return true
    end
    -- Allow Windows absolute paths for portability in tests/tooling.
    if path:match("^%a:[/\\]") then
        return true
    end
    return false
end

local function fail(msg)
    error("nvim-obsidian setup: " .. msg, 2)
end

function M.normalize(user_opts)
    local opts = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})

    if type(opts.vault_root) ~= "string" or opts.vault_root == "" then
        fail("vault_root is required and must be a non-empty string")
    end
    if not is_absolute_path(opts.vault_root) then
        fail("vault_root must be an absolute path")
    end

    if opts.new_notes_subdir == nil then
        opts.new_notes_subdir = opts.vault_root
    end

    if type(opts.new_notes_subdir) ~= "string" or opts.new_notes_subdir == "" then
        fail("new_notes_subdir must be a non-empty string when provided")
    end

    return opts
end

return M
