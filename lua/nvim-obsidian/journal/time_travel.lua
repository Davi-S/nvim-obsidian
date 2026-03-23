local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local fmt = require("nvim-obsidian.journal.format")
local router = require("nvim-obsidian.journal.router")

local M = {}

local function current_note_type_and_title(cfg)
    if not cfg.journal_enabled then
        error("journal is not configured")
    end

    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then
        return "daily", fmt.daily_title(os.time(), cfg)
    end
    if not path.is_inside(cfg.vault_root, file) then
        return "daily", fmt.daily_title(os.time(), cfg)
    end

    local nfile = path.normalize(file)
    local title = path.stem(nfile)
    local parent = path.normalize(path.parent(nfile))

    if parent == path.normalize(cfg.journal.daily.dir_abs) then
        return "daily", title
    end
    if parent == path.normalize(cfg.journal.weekly.dir_abs) then
        return "weekly", title
    end
    if parent == path.normalize(cfg.journal.monthly.dir_abs) then
        return "monthly", title
    end
    if parent == path.normalize(cfg.journal.yearly.dir_abs) then
        return "yearly", title
    end

    return "daily", fmt.daily_title(os.time(), cfg)
end

local function anchor_timestamp(note_type, title, cfg)
    if note_type == "daily" then
        return fmt.parse_daily_title(title, cfg) or os.time()
    end
    if note_type == "weekly" then
        return fmt.parse_weekly_title(title, cfg) or os.time()
    end
    if note_type == "monthly" then
        return fmt.parse_monthly_title(title, cfg) or os.time()
    end
    if note_type == "yearly" then
        return fmt.parse_yearly_title(title, cfg) or os.time()
    end
    return os.time()
end

local function shift(note_type, ts, delta)
    if note_type == "daily" then
        return ts + (delta * 86400)
    end
    if note_type == "weekly" then
        return ts + (delta * 7 * 86400)
    end
    local t = os.date("*t", ts)
    if type(t) ~= "table" then
        return ts
    end
    if note_type == "monthly" then
        t.month = t.month + delta
        return os.time(t)
    end
    if note_type == "yearly" then
        t.year = t.year + delta
        return os.time(t)
    end
    return ts
end

local function title_for_type(note_type, ts, cfg)
    if note_type == "daily" then
        return fmt.daily_title(ts, cfg)
    end
    if note_type == "weekly" then
        return fmt.weekly_title(ts, cfg)
    end
    if note_type == "monthly" then
        return fmt.monthly_title(ts, cfg)
    end
    return fmt.yearly_title(ts, cfg)
end

function M.open_relative(delta)
    local cfg = config.get()
    local note_type, title = current_note_type_and_title(cfg)
    local base = anchor_timestamp(note_type, title, cfg)
    local target = shift(note_type, base, delta)
    local target_title = title_for_type(note_type, target, cfg)
    local filepath = router.path_for_type(note_type, target_title, cfg)
    return note_type, target_title, filepath
end

return M
