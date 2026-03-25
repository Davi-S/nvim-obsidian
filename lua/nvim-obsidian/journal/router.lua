local path = require("nvim-obsidian.path")
local fmt = require("nvim-obsidian.journal.format")
local classifier = require("nvim-obsidian.journal.classifier")

local M = {}

local function resolve_template_path(rel_or_abs, cfg)
    if path.is_absolute(rel_or_abs) then
        return rel_or_abs
    end

    local rel = rel_or_abs
    if rel:sub(-3) ~= ".md" then
        rel = rel .. ".md"
    end
    return path.join(cfg.vault_root, rel)
end

function M.classify_input(input, cfg)
    return classifier.classify_title(input, cfg)
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
    if cfg.journal_enabled and cfg.journal.templates and cfg.journal.templates[note_type] then
        local template_file = resolve_template_path(cfg.journal.templates[note_type], cfg)
        if vim.fn.filereadable(template_file) == 1 then
            return table.concat(vim.fn.readfile(template_file), "\n")
        end
        return ""
    end

    if cfg.templates and cfg.templates.standard then
        local template_file = resolve_template_path(cfg.templates.standard, cfg)
        if vim.fn.filereadable(template_file) == 1 then
            return table.concat(vim.fn.readfile(template_file), "\n")
        end
    end

    return ""
end

function M.render_template(template, title)
    local now = os.time()
    local src = template or ""
    if src == "" then
        return ""
    end

    return src
        :gsub("{{title}}", title)
        :gsub("{{date}}", os.date("%Y-%m-%d", now))
end

function M.today_daily(cfg)
    if not cfg.journal_enabled then
        error("journal is not configured")
    end

    local title = fmt.daily_title(os.time(), cfg)
    return "daily", title, M.path_for_type("daily", title, cfg)
end

return M
