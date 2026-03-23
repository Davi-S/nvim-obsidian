local path = require("nvim-obsidian.path")
local journal_format = require("nvim-obsidian.journal.format")

local M = {}

local LOCALE_NAMES = {
    ["en-US"] = {
        month_names = {
            [1] = "january",
            [2] = "february",
            [3] = "march",
            [4] = "april",
            [5] = "may",
            [6] = "june",
            [7] = "july",
            [8] = "august",
            [9] = "september",
            [10] = "october",
            [11] = "november",
            [12] = "december",
        },
        weekday_names = {
            [1] = "sunday",
            [2] = "monday",
            [3] = "tuesday",
            [4] = "wednesday",
            [5] = "thursday",
            [6] = "friday",
            [7] = "saturday",
        },
    },
    ["pt-BR"] = {
        month_names = {
            [1] = "janeiro",
            [2] = "fevereiro",
            [3] = "março",
            [4] = "abril",
            [5] = "maio",
            [6] = "junho",
            [7] = "julho",
            [8] = "agosto",
            [9] = "setembro",
            [10] = "outubro",
            [11] = "novembro",
            [12] = "dezembro",
        },
        weekday_names = {
            [1] = "domingo",
            [2] = "segunda-feira",
            [3] = "terca-feira",
            [4] = "quarta-feira",
            [5] = "quinta-feira",
            [6] = "sexta-feira",
            [7] = "sábado",
        },
    },
}

local defaults = {
    vault_root = "",
    locale = "en-US",
    notes_subdir = "10 Novas notas",
    force_create_key = "<S-CR>",
    templates = {},
}

local state = {}

local function has_key(tbl, key)
    return type(tbl) == "table" and rawget(tbl, key) ~= nil
end

local function require_string(value, label)
    if type(value) ~= "string" or vim.trim(value) == "" then
        error(label .. " must be a non-empty string")
    end
end

local function validate_journal(cfg, user)
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

local function validate(cfg)
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

function M.resolve(user)
    local user_opts = user or {}
    local cfg = vim.tbl_deep_extend("force", {}, defaults, user_opts)
    cfg.vault_root = path.normalize(vim.fn.expand(cfg.vault_root))

    validate(cfg)
    validate_journal(cfg, user_opts)

    local locale_data = LOCALE_NAMES[cfg.locale] or LOCALE_NAMES["en-US"]
    cfg.month_names = vim.deepcopy(locale_data.month_names)
    cfg.weekday_names = vim.deepcopy(locale_data.weekday_names)

    cfg.notes_dir_abs = path.join(cfg.vault_root, cfg.notes_subdir)
    if cfg.journal_enabled then
        cfg.journal.compiled_patterns = journal_format.derive_patterns(cfg.journal.title_formats)
        cfg.journal.patterns = {
            daily = cfg.journal.compiled_patterns.daily.pattern,
            weekly = cfg.journal.compiled_patterns.weekly.pattern,
            monthly = cfg.journal.compiled_patterns.monthly.pattern,
            yearly = cfg.journal.compiled_patterns.yearly.pattern,
        }

        cfg.journal.daily.dir_abs = path.join(cfg.vault_root, cfg.journal.daily.subdir)
        cfg.journal.weekly.dir_abs = path.join(cfg.vault_root, cfg.journal.weekly.subdir)
        cfg.journal.monthly.dir_abs = path.join(cfg.vault_root, cfg.journal.monthly.subdir)
        cfg.journal.yearly.dir_abs = path.join(cfg.vault_root, cfg.journal.yearly.subdir)
    end

    return cfg
end

function M.set(cfg)
    state.cfg = cfg
end

function M.get()
    return state.cfg
end

return M
