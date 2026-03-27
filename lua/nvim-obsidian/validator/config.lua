-- Configuration validation functions
local path = require("nvim-obsidian.path")
local journal_format = require("nvim-obsidian.journal.format")
local journal_placeholders = require("nvim-obsidian.journal.placeholder_registry")

local M = {}

local function has_key(tbl, key)
    return type(tbl) == "table" and rawget(tbl, key) ~= nil
end

local function require_string(value, label)
    if type(value) ~= "string" or vim.trim(value) == "" then
        error(label .. " must be a non-empty string")
    end
end

local function require_boolean(value, label)
    if type(value) ~= "boolean" then
        error(label .. " must be a boolean")
    end
end

local function validate_string_list(value, label)
    if type(value) ~= "table" or #value == 0 then
        error(label .. " must be a non-empty list of strings")
    end
    for _, v in ipairs(value) do
        require_string(v, label .. "[]")
    end
end

local function validate_optional_hl_group(name, label)
    if name == nil then
        return
    end
    require_string(name, label)
end

function M.validate_dataview(cfg)
    local dv = cfg.dataview
    if type(dv) ~= "table" then
        error("dataview must be a table when provided")
    end

    require_boolean(dv.enabled, "dataview.enabled")

    if type(dv.render) ~= "table" then
        error("dataview.render must be a table")
    end

    validate_string_list(dv.render.when, "dataview.render.when")
    local allowed_when = {
        on_open = true,
        on_save = true,
        on_buf_enter = true,
    }
    for _, w in ipairs(dv.render.when) do
        if not allowed_when[w] then
            error("dataview.render.when contains invalid option: " .. w)
        end
    end

    require_string(dv.render.scope, "dataview.render.scope")
    local allowed_scope = {
        event = true,
        current = true,
        visible = true,
        loaded = true,
    }
    if not allowed_scope[dv.render.scope] then
        error("dataview.render.scope must be one of: event,current,visible,loaded")
    end

    validate_string_list(dv.render.patterns, "dataview.render.patterns")

    require_string(dv.placement, "dataview.placement")
    if dv.placement ~= "below_block" and dv.placement ~= "above_block" then
        error("dataview.placement must be one of: below_block,above_block")
    end

    if type(dv.messages) ~= "table" then
        error("dataview.messages must be a table")
    end
    if type(dv.messages.task_no_results) ~= "table" then
        error("dataview.messages.task_no_results must be a table")
    end
    require_boolean(dv.messages.task_no_results.enabled, "dataview.messages.task_no_results.enabled")
    require_string(dv.messages.task_no_results.text, "dataview.messages.task_no_results.text")

    if type(dv.highlights) ~= "table" then
        error("dataview.highlights must be a table")
    end
    validate_optional_hl_group(dv.highlights.header, "dataview.highlights.header")
    validate_optional_hl_group(dv.highlights.error, "dataview.highlights.error")
    validate_optional_hl_group(dv.highlights.table_link, "dataview.highlights.table_link")
    validate_optional_hl_group(dv.highlights.task_no_results, "dataview.highlights.task_no_results")
end

--- Validate journal configuration block
-- @param cfg table Config object being built
-- @param user table User-provided options
function M.validate_journal(cfg, user)
    if not has_key(user, "journal") then
        cfg.journal_enabled = false
        return
    end

    local journal = cfg.journal
    if type(journal) ~= "table" then
        error("journal must be a table when provided")
    end

    local required_types = { "daily", "weekly", "monthly", "yearly" }

    for _, note_type in ipairs(required_types) do
        if type(journal[note_type]) ~= "table" then
            error("journal." .. note_type .. " must be provided explicitly")
        end
        require_string(journal[note_type].subdir, "journal." .. note_type .. ".subdir")
        require_string(journal[note_type].title_format, "journal." .. note_type .. ".title_format")
        for _, key in ipairs(journal_format.extract_placeholders(journal[note_type].title_format)) do
            if not journal_placeholders.has(key) then
                error("journal." .. note_type .. ".title_format uses unregistered placeholder: " .. key)
            end
        end
        if journal[note_type].template ~= nil then
            require_string(journal[note_type].template, "journal." .. note_type .. ".template")
        end
    end

    cfg.journal_enabled = true
end

--- Validate core configuration
-- @param cfg table Config object to validate
function M.validate_config(cfg)
    if cfg.vault_root == "" then
        error("vault_root is required")
    end
    if not path.is_absolute(cfg.vault_root) then
        error("vault_root must be an absolute path")
    end
    if vim.fn.isdirectory(cfg.vault_root) == 0 then
        error("vault_root directory does not exist: " .. cfg.vault_root)
    end

    if cfg.templates ~= nil and type(cfg.templates) ~= "table" then
        error("templates must be a table when provided")
    end
    if cfg.templates and cfg.templates.standard ~= nil then
        require_string(cfg.templates.standard, "templates.standard")
    end

    M.validate_dataview(cfg)
end

return M
