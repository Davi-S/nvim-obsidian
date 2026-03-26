local path = require("nvim-obsidian.path")
local journal_classifier = require("nvim-obsidian.journal.classifier")
local journal_format = require("nvim-obsidian.journal.format")

local M = {}

local TASK_PATTERN = "^(%s*)%- %[(.)%]%s*(.*)$"

local function parse_iso_date(s)
    local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
        return nil
    end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function resolve_note_timestamp(note, cfg)
    local title = path.stem(note.filepath)
    local note_type = note.note_type or journal_classifier.note_type_for_path(note.filepath, cfg)

    if cfg.journal_enabled and note_type ~= "standard" then
        if note_type == "daily" then
            return journal_format.parse_daily_title(title, cfg)
        elseif note_type == "weekly" then
            return journal_format.parse_weekly_title(title, cfg)
        elseif note_type == "monthly" then
            return journal_format.parse_monthly_title(title, cfg)
        elseif note_type == "yearly" then
            return journal_format.parse_yearly_title(title, cfg)
        end
    end

    local fm_date = note.frontmatter and note.frontmatter.date or nil
    if type(fm_date) == "string" then
        return parse_iso_date(fm_date)
    end

    return nil
end

function M.collect(vault_notes, cfg, from_prefix)
    local tasks = {}
    local errors = {}

    local normalized_prefix = vim.trim(from_prefix or "")
    if normalized_prefix ~= "" and normalized_prefix:sub(-1) ~= "/" then
        normalized_prefix = normalized_prefix .. "/"
    end

    for _, note in ipairs(vault_notes) do
        local rel = note.relpath or path.rel_to_root(cfg.vault_root, note.filepath) or ""
        if normalized_prefix == "" or vim.startswith(rel, normalized_prefix) then
            local ts = resolve_note_timestamp(note, cfg)
            if not ts then
                table.insert(errors, string.format("dataview: missing date for note '%s'", rel))
            end

            local lines = vim.fn.readfile(note.filepath)
            for idx, line in ipairs(lines) do
                local indent, mark, text = line:match(TASK_PATTERN)
                if mark then
                    local prefix = indent or ""
                    table.insert(tasks, {
                        checked = mark ~= " ",
                        text = text or "",
                        raw = string.format("%s- [%s] %s", prefix, mark, text or ""),
                        line = idx,
                        file = {
                            path = rel,
                            name = path.stem(note.filepath),
                            link = {
                                date = ts,
                            },
                        },
                    })
                end
            end
        end
    end

    return tasks, errors
end

return M
