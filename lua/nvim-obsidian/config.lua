local path = require("nvim-obsidian.path")
local journal_format = require("nvim-obsidian.journal.format")
local locale = require("nvim-obsidian.locale")
local validator = require("nvim-obsidian.validator.config")

local M = {}

local defaults = {
    vault_root = "",
    locale = "en-US",
    notes_subdir = "10 Novas notas",
    force_create_key = "<S-CR>",
    templates = {},
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
