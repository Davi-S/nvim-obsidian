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

function M.classify_input(input)
    local title = ensure_md_title(input)
    if title:match("^%d%d%d%d$") then
        return "yearly", title
    end
    if title:match("^%d%d%d%d%s+semana%s+%d%d?$") then
        return "weekly", title
    end
    if title:match("^%d%d%d%d%s+.+%s+%d%d?,%s+.+$") then
        return "daily", title
    end
    if title:match("^%d%d%d%d%s+[^,]+$") then
        return "monthly", title
    end
    return "standard", title
end

function M.path_for_type(note_type, title, cfg)
    local filename = title .. ".md"
    if note_type == "daily" then
        return path.join(cfg.journal.daily.dir_abs, filename)
    end
    if note_type == "weekly" then
        return path.join(cfg.journal.weekly.dir_abs, filename)
    end
    if note_type == "monthly" then
        return path.join(cfg.journal.monthly.dir_abs, filename)
    end
    if note_type == "yearly" then
        return path.join(cfg.journal.yearly.dir_abs, filename)
    end
    return path.join(cfg.notes_dir_abs, filename)
end

function M.template_for_type(note_type, cfg)
    return cfg.templates[note_type] or cfg.templates.standard
end

function M.render_template(template, title)
    local now = os.time()
    return template
        :gsub("{{title}}", title)
        :gsub("{{date}}", os.date("%Y-%m-%d", now))
end

function M.today_daily(cfg)
    local title = fmt.daily_title(os.time(), cfg)
    return "daily", title, M.path_for_type("daily", title, cfg)
end

return M
