local registry = require("nvim-obsidian.journal.placeholder_registry")

local M = {}

local function escape_lua_pattern_literal(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

function M.extract_placeholders(format)
    local out = {}
    for key in (format or ""):gmatch("{{([%w_]+)}}") do
        out[#out + 1] = key
    end
    return out
end

local function compile_title_pattern(format)
    local parts = { "^" }
    local capture_order = {}
    local from = 1

    while true do
        local s, e, key = format:find("{{([%w_]+)}}", from)
        if not s then
            table.insert(parts, escape_lua_pattern_literal(format:sub(from)))
            break
        end

        table.insert(parts, escape_lua_pattern_literal(format:sub(from, s - 1)))
        local capture = registry.get_regex_fragment(key)
        if not capture then
            error("unsupported title format placeholder: " .. key)
        end

        table.insert(parts, capture)
        table.insert(capture_order, key)
        from = e + 1
    end

    table.insert(parts, "$")
    return {
        pattern = table.concat(parts),
        capture_order = capture_order,
    }
end

function M.derive_patterns(title_formats)
    return {
        daily = compile_title_pattern(title_formats.daily),
        weekly = compile_title_pattern(title_formats.weekly),
        monthly = compile_title_pattern(title_formats.monthly),
        yearly = compile_title_pattern(title_formats.yearly),
    }
end

local function get_pattern_spec(note_type, cfg)
    if cfg.journal.compiled_patterns and cfg.journal.compiled_patterns[note_type] then
        return cfg.journal.compiled_patterns[note_type]
    end

    local derived = M.derive_patterns(cfg.journal.title_formats)
    return derived[note_type]
end

local function match_named_fields(title, note_type, cfg)
    local spec = get_pattern_spec(note_type, cfg)
    local captures = { title:match(spec.pattern) }
    if #captures == 0 then
        return nil
    end

    local out = {}
    for idx, key in ipairs(spec.capture_order) do
        out[key] = captures[idx]
    end

    return out
end

local function iso_week_start(year, week)
    local jan4 = os.time({ year = year, month = 1, day = 4, hour = 12 })
    local jan4_wday = os.date("*t", jan4).wday
    local monday_delta = (jan4_wday + 5) % 7
    local week1_monday = jan4 - (monday_delta * 86400)
    return week1_monday + ((week - 1) * 7 * 86400)
end

local function build_render_ctx(ts, cfg, note_type)
    local local_dt = os.date("*t", ts)
    local utc_dt = os.date("!*t", ts)
    local month_name = cfg.month_names[local_dt.month] or vim.fn.tolower(os.date("%B", ts))
    local weekday_name = cfg.weekday_names[local_dt.wday] or vim.fn.tolower(os.date("%A", ts))

    return {
        timestamp = ts,
        note_type = note_type,
        date = {
            ["local"] = local_dt,
            utc = utc_dt,
            year = local_dt.year,
            month = local_dt.month,
            day = local_dt.day,
            wday = local_dt.wday,
            iso_year = tonumber(os.date("%G", ts)) or local_dt.year,
            iso_week = tonumber(os.date("%V", ts)) or 0,
        },
        locale = {
            month_name = month_name,
            weekday_name = weekday_name,
        },
        config = cfg,
    }
end

local function normalize_for_comparison(text)
    -- Remove common Portuguese diacritical marks for accent-insensitive comparison
    -- This allows matching "marco" with "março", "sábado" with "sabado", etc.
    local replacements = {
        ["á"] = "a",
        ["à"] = "a",
        ["ã"] = "a",
        ["â"] = "a",
        ["ä"] = "a",
        ["é"] = "e",
        ["è"] = "e",
        ["ê"] = "e",
        ["ë"] = "e",
        ["í"] = "i",
        ["ì"] = "i",
        ["î"] = "i",
        ["ï"] = "i",
        ["ó"] = "o",
        ["ò"] = "o",
        ["õ"] = "o",
        ["ô"] = "o",
        ["ö"] = "o",
        ["ú"] = "u",
        ["ù"] = "u",
        ["û"] = "u",
        ["ü"] = "u",
        ["ç"] = "c",
    }
    local result = text
    for accented, base in pairs(replacements) do
        result = result:gsub(accented, base)
    end
    return result
end

local function render_title(format, ts, cfg, note_type)
    local ctx = build_render_ctx(ts, cfg, note_type)
    return (format:gsub("{{([%w_]+)}}", function(key)
        local value, ok = registry.resolve(key, ctx)
        if not ok then
            error("unsupported title format placeholder: " .. key)
        end
        return value
    end))
end

function M.daily_title(ts, cfg)
    return render_title(cfg.journal.title_formats.daily, ts, cfg, "daily")
end

function M.weekly_title(ts, cfg)
    return render_title(cfg.journal.title_formats.weekly, ts, cfg, "weekly")
end

function M.monthly_title(ts, cfg)
    return render_title(cfg.journal.title_formats.monthly, ts, cfg, "monthly")
end

function M.yearly_title(ts, cfg)
    return render_title(cfg.journal.title_formats.yearly, ts, cfg, "yearly")
end

function M.parse_daily_title(title, cfg)
    local fields = match_named_fields(title, "daily", cfg)
    if not fields then
        return nil
    end

    local year = tonumber(fields.year)
    local day = tonumber(fields.day2)
    if not year or not day then
        return nil
    end

    local month_num
    local lowered = vim.fn.tolower(fields.month_name or "")
    local normalized = normalize_for_comparison(lowered)
    for idx, name in pairs(cfg.month_names) do
        local normalized_name = normalize_for_comparison(vim.fn.tolower(name))
        if normalized_name == normalized then
            month_num = idx
            break
        end
    end
    if not month_num then
        return nil
    end

    return os.time({ year = year, month = month_num, day = day, hour = 12 })
end

function M.parse_weekly_title(title, cfg)
    local fields = match_named_fields(title, "weekly", cfg)
    if not fields then
        return nil
    end
    local year = tonumber(fields.iso_year)
    local week = tonumber(fields.iso_week)
    if not year or not week then
        return nil
    end
    return iso_week_start(year, week)
end

function M.parse_monthly_title(title, cfg)
    local fields = match_named_fields(title, "monthly", cfg)
    if not fields then
        return nil
    end
    local year = tonumber(fields.year)
    if not year then
        return nil
    end
    local lowered = vim.fn.tolower(fields.month_name or "")
    local normalized = normalize_for_comparison(lowered)
    local month_num
    for idx, name in pairs(cfg.month_names) do
        local normalized_name = normalize_for_comparison(vim.fn.tolower(name))
        if normalized_name == normalized then
            month_num = idx
            break
        end
    end
    if not month_num then
        return nil
    end
    return os.time({ year = year, month = month_num, day = 1, hour = 12 })
end

function M.parse_yearly_title(title, cfg)
    local fields = match_named_fields(title, "yearly", cfg)
    local y = fields and fields.year or nil
    if not y then
        return nil
    end
    local year = tonumber(y)
    if not year then
        return nil
    end
    return os.time({ year = year, month = 1, day = 1, hour = 12 })
end

return M
