local path = require("nvim-obsidian.path")
local journal_format = require("nvim-obsidian.journal.format")
local locale = require("nvim-obsidian.locale")
local validator = require("nvim-obsidian.validator.config")

local M = {}

local defaults = {
    vault_root = "",
    locale = "en-US",
    new_notes_subdir = "10 Novas notas",
    force_create_key = "<S-CR>",
    templates = {},
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
        highlights = {},
    },
}

local state = {}

function M.resolve(user)
    local user_opts = user or {}
    local cfg = vim.tbl_deep_extend("force", {}, defaults, user_opts)
    cfg.vault_root = path.normalize(vim.fn.expand(cfg.vault_root))

    validator.validate_config(cfg)
    validator.validate_journal(cfg, user_opts)

    local locale_data = locale.LOCALE_NAMES[cfg.locale] or locale.LOCALE_NAMES["en-US"]
    cfg.month_names = vim.deepcopy(locale_data.month_names)
    cfg.weekday_names = vim.deepcopy(locale_data.weekday_names)

    cfg.notes_dir_abs = path.join(cfg.vault_root, cfg.new_notes_subdir)
    if cfg.journal_enabled then
        -- Build flat title_formats table from nested structure (for internal use)
        cfg.journal.title_formats = {}
        for _, note_type in ipairs({ "daily", "weekly", "monthly", "yearly" }) do
            cfg.journal.title_formats[note_type] = cfg.journal[note_type].title_format
        end

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
