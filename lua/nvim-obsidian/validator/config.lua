-- Configuration validation functions
local path = require("nvim-obsidian.path")

local M = {}

local function has_key(tbl, key)
    return type(tbl) == "table" and rawget(tbl, key) ~= nil
end

local function require_string(value, label)
    if type(value) ~= "string" or vim.trim(value) == "" then
        error(label .. " must be a non-empty string")
    end
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

    if type(journal.title_formats) ~= "table" then
        error("journal.title_formats must be provided explicitly")
    end
    if journal.templates ~= nil and type(journal.templates) ~= "table" then
        error("journal.templates must be a table when provided")
    end

    for _, note_type in ipairs(required_types) do
        if type(journal[note_type]) ~= "table" then
            error("journal." .. note_type .. " must be provided explicitly")
        end
        require_string(journal[note_type].subdir, "journal." .. note_type .. ".subdir")
        require_string(journal.title_formats[note_type], "journal.title_formats." .. note_type)
        if journal.templates and journal.templates[note_type] ~= nil then
            require_string(journal.templates[note_type], "journal.templates." .. note_type)
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
end

return M
