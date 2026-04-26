---@diagnostic disable: undefined-global

---Configuration normalization and validation.
---
---This module is the single authority for default values and setup-time schema
---validation. It guarantees downstream layers receive a fully materialized
---configuration object with deterministic keys.
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
        highlights = {
            header = "Comment",
            task_text = "Normal",
            task_no_results = "Comment",
            table_header = "Comment",
            table_link = "Comment",
            error = "WarningMsg",
        },
        messages = {
            task_no_results = {
                enabled = true,
                text = "Dataview: No results to show for task query.",
            },
        },
    },
    -- Calendar/date-picker defaults.
    --
    -- This block is shared by all future calendar frontends because it is consumed
    -- via use-case orchestration, not directly in command handlers.
    calendar = {
        -- Week starts on Sunday by default; can be switched to Monday.
        week_start = "sunday",

        -- Highlight group names consumed by the buffer calendar frontend.
        -- These are names only; users control actual colors through colorschemes.
        highlights = {
            title = "Title",
            weekday = "Comment",
            in_month_day = "Normal",
            outside_month_day = "Comment",
            today = "DiagnosticOk",
            note_exists = "Bold",
        },
    },
}

---Check whether a path is absolute on Unix or Windows.
---@param path any
---@return boolean
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

---Raise a setup validation error with consistent prefix.
---@param msg string
local function fail(msg)
    error("nvim-obsidian setup: " .. msg, 2)
end

---@param value any
---@return boolean
local function is_non_empty_string(value)
    return type(value) == "string" and value ~= ""
end

---Validate enum-like field values.
---@param value any
---@param allowed table<string, boolean>
---@param field_name string
local function validate_enum(value, allowed, field_name)
    if not allowed[value] then
        fail(field_name .. " has invalid value: " .. tostring(value))
    end
end

---Validate non-empty list of non-empty strings.
---@param value any
---@param field_name string
local function validate_string_list(value, field_name)
    if type(value) ~= "table" then
        fail(field_name .. " must be a list of strings")
    end
    if #value == 0 then
        fail(field_name .. " cannot be empty")
    end
    for _, item in ipairs(value) do
        if not is_non_empty_string(item) then
            fail(field_name .. " must contain only non-empty strings")
        end
    end
end

---Validate dataview subsystem configuration.
---@param opts table
local function validate_dataview(opts)
    local dv = opts.dataview
    if type(dv) ~= "table" then
        fail("dataview must be a table")
    end

    if type(dv.enabled) ~= "boolean" then
        fail("dataview.enabled must be a boolean")
    end

    if type(dv.render) ~= "table" then
        fail("dataview.render must be a table")
    end

    validate_string_list(dv.render.when, "dataview.render.when")
    local allowed_when = {
        on_open = true,
        on_save = true,
    }
    for _, trigger in ipairs(dv.render.when) do
        validate_enum(trigger, allowed_when, "dataview.render.when")
    end

    validate_enum(dv.render.scope, {
        event = true,
        current = true,
        visible = true,
        loaded = true,
    }, "dataview.render.scope")

    validate_string_list(dv.render.patterns, "dataview.render.patterns")

    validate_enum(dv.placement, {
        below_block = true,
        above_block = true,
    }, "dataview.placement")

    if type(dv.messages) ~= "table" or type(dv.messages.task_no_results) ~= "table" then
        fail("dataview.messages.task_no_results must be configured")
    end

    if type(dv.messages.task_no_results.enabled) ~= "boolean" then
        fail("dataview.messages.task_no_results.enabled must be a boolean")
    end

    if not is_non_empty_string(dv.messages.task_no_results.text) then
        fail("dataview.messages.task_no_results.text must be a non-empty string")
    end
end

---Validate calendar subsystem configuration.
---@param opts table
local function validate_calendar(opts)
    -- Calendar config is required because defaults are always materialized via
    -- deep-merge in normalize().
    local calendar = opts.calendar
    if type(calendar) ~= "table" then
        fail("calendar must be a table")
    end

    -- Only two week-start modes are supported in current backend contract.
    validate_enum(calendar.week_start, {
        sunday = true,
        monday = true,
    }, "calendar.week_start")

    if type(calendar.highlights) ~= "table" then
        fail("calendar.highlights must be a table")
    end

    -- All highlight keys are mandatory post-merge so frontends can avoid nil checks
    -- in render hot paths.
    local required_groups = {
        "title",
        "weekday",
        "in_month_day",
        "outside_month_day",
        "today",
        "note_exists",
    }

    for _, key in ipairs(required_groups) do
        if not is_non_empty_string(calendar.highlights[key]) then
            fail("calendar.highlights." .. key .. " must be a non-empty string")
        end
    end
end

---Validate optional journal section templates and format configuration.
---@param opts table
local function validate_journal(opts)
    if opts.journal == nil then
        return
    end

    if type(opts.journal) ~= "table" then
        fail("journal must be a table when provided")
    end

    for _, kind in ipairs({ "daily", "weekly", "monthly", "yearly" }) do
        local section = opts.journal[kind]
        if section ~= nil then
            if type(section) ~= "table" then
                fail("journal." .. kind .. " must be a table")
            end
            if not is_non_empty_string(section.subdir) then
                fail("journal." .. kind .. ".subdir must be a non-empty string")
            end
            if not is_non_empty_string(section.title_format) then
                fail("journal." .. kind .. ".title_format must be a non-empty string")
            end
        end
    end
end

---Normalize and validate user options against defaults.
---@param user_opts? table
---@return table opts
function M.normalize(user_opts)
    -- Merge user input over defaults so feature modules can rely on complete config.
    local opts = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})

    -- Keep calendar highlight defaults explicit even if callers provide only a
    -- partial calendar table. This guards against shallow user config and makes
    -- the rendered UI contract deterministic.
    if type(opts.calendar) ~= "table" then
        opts.calendar = {}
    end
    if type(opts.calendar.highlights) ~= "table" then
        opts.calendar.highlights = {}
    end

    local default_calendar_highlights = M.defaults.calendar.highlights
    for key, value in pairs(default_calendar_highlights) do
        if type(opts.calendar.highlights[key]) ~= "string" or opts.calendar.highlights[key] == "" then
            opts.calendar.highlights[key] = value
        end
    end

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

    if not is_non_empty_string(opts.locale) then
        fail("locale must be a non-empty string")
    end

    if not is_non_empty_string(opts.force_create_key) then
        fail("force_create_key must be a non-empty string")
    end

    validate_enum(opts.log_level, {
        error = true,
        warn = true,
        info = true,
    }, "log_level")

    -- Validate subsystem configs independently so error messages stay focused.
    validate_dataview(opts)
    validate_calendar(opts)
    validate_journal(opts)

    return opts
end

return M
