local path = require("nvim-obsidian.path")
local readonly = require("nvim-obsidian.template.readonly")

local M = {}

local function date_or_empty(fmt, timestamp)
    local ok, value = pcall(os.date, fmt, timestamp)
    if not ok then
        return ""
    end
    return value
end

function M.build(params)
    local cfg = params.cfg
    local timestamp = params.timestamp or os.time()
    local note_abs = params.note_abs_path or ""
    local note_rel = ""
    if note_abs ~= "" and cfg and cfg.vault_root then
        note_rel = path.rel_to_root(cfg.vault_root, note_abs) or ""
    end

    local local_dt = os.date("*t", timestamp)
    local utc_dt = os.date("!*t", timestamp)

    local month_name = ""
    local weekday_name = ""
    if cfg and cfg.month_names and local_dt and local_dt.month then
        month_name = cfg.month_names[local_dt.month] or ""
    end
    if cfg and cfg.weekday_names and local_dt and local_dt.wday then
        weekday_name = cfg.weekday_names[local_dt.wday] or ""
    end

    local ctx = {
        note = {
            title = params.title or "",
            type = params.note_type or "standard",
            input = params.input or "",
            filename = note_abs ~= "" and path.basename(note_abs) or "",
            basename = note_abs ~= "" and path.stem(note_abs) or (params.title or ""),
            abs_path = note_abs,
            rel_path = note_rel,
            aliases = params.aliases or {},
            tags = params.tags or {},
        },
        time = {
            timestamp = timestamp,
            ["local"] = local_dt,
            utc = utc_dt,
            iso = {
                date = date_or_empty("%Y-%m-%d", timestamp),
                datetime = date_or_empty("%Y-%m-%dT%H:%M:%S", timestamp),
                week = tonumber(date_or_empty("%V", timestamp)) or 0,
                year = tonumber(date_or_empty("%G", timestamp)) or tonumber(date_or_empty("%Y", timestamp)) or 0,
            },
            locale = {
                month_name = month_name,
                weekday_name = weekday_name,
            },
            format_local = function(pattern)
                return date_or_empty(pattern, timestamp)
            end,
            format_utc = function(pattern)
                return date_or_empty("!" .. pattern, timestamp)
            end,
        },
        config = readonly.wrap(cfg or {}),
    }

    return ctx
end

return M
