local path = require("nvim-obsidian.path")
local fmt = require("nvim-obsidian.journal.format")

local M = {}

local function ensure_md_title(input)
    local s = vim.trim(input)
    if s:sub(-3) == ".md" then
        s = s:sub(1, -4)
    end
    return s
end

local function get_patterns(cfg)
    if cfg.journal.patterns then
        return cfg.journal.patterns
    end

    local derived = fmt.derive_patterns(cfg.journal.title_formats)
    return {
        daily = derived.daily.pattern,
        weekly = derived.weekly.pattern,
        monthly = derived.monthly.pattern,
        yearly = derived.yearly.pattern,
    }
end

function M.classify_title(input, cfg)
    local title = ensure_md_title(input)
    if not cfg.journal_enabled then
        return "standard", title
    end

    local patterns = get_patterns(cfg)
    if title:match(patterns.yearly) then
        return "yearly", title
    end
    if title:match(patterns.weekly) then
        return "weekly", title
    end
    if title:match(patterns.daily) then
        return "daily", title
    end
    if title:match(patterns.monthly) then
        return "monthly", title
    end

    return "standard", title
end

function M.note_type_for_path(abs, cfg)
    if not cfg.journal_enabled then
        return "standard"
    end

    local parent = path.normalize(path.parent(abs))
    if parent == path.normalize(cfg.journal.daily.dir_abs) then
        return "daily"
    end
    if parent == path.normalize(cfg.journal.weekly.dir_abs) then
        return "weekly"
    end
    if parent == path.normalize(cfg.journal.monthly.dir_abs) then
        return "monthly"
    end
    if parent == path.normalize(cfg.journal.yearly.dir_abs) then
        return "yearly"
    end

    return "standard"
end

return M