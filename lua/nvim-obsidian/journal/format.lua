local M = {}

local PLACEHOLDER_CAPTURE = {
    year = "(%d%d%d%d)",
    iso_year = "(%d%d%d%d)",
    month_name = "(.+)",
    day2 = "(%d%d?)",
    weekday_name = "(.+)",
    iso_week = "(%d%d?)",
}

local function escape_lua_pattern_literal(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
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
        local capture = PLACEHOLDER_CAPTURE[key]
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

local function render_title(format, parts)
    return format
        :gsub("{{year}}", tostring(parts.year or ""))
        :gsub("{{iso_year}}", tostring(parts.iso_year or ""))
        :gsub("{{month_name}}", tostring(parts.month_name or ""))
        :gsub("{{day2}}", string.format("%02d", parts.day or 0))
        :gsub("{{weekday_name}}", tostring(parts.weekday_name or ""))
        :gsub("{{iso_week}}", tostring(parts.iso_week or ""))
end

function M.daily_title(ts, cfg)
    local t = os.date("*t", ts)
    local month = cfg.month_names[t.month] or vim.fn.tolower(os.date("%B", ts))
    local weekday = cfg.weekday_names[t.wday] or vim.fn.tolower(os.date("%A", ts))
    return render_title(cfg.journal.title_formats.daily, {
        year = t.year,
        month_name = month,
        day = t.day,
        weekday_name = weekday,
    })
end

function M.weekly_title(ts, cfg)
    local y = tonumber(os.date("%G", ts))
    local w = tonumber(os.date("%V", ts))
    return render_title(cfg.journal.title_formats.weekly, {
        iso_year = y,
        iso_week = w,
    })
end

function M.monthly_title(ts, cfg)
    local t = os.date("*t", ts)
    local month = cfg.month_names[t.month] or vim.fn.tolower(os.date("%B", ts))
    return render_title(cfg.journal.title_formats.monthly, {
        year = t.year,
        month_name = month,
    })
end

function M.yearly_title(ts, cfg)
    return render_title(cfg.journal.title_formats.yearly, {
        year = os.date("%Y", ts),
    })
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
    for idx, name in pairs(cfg.month_names) do
        if vim.fn.tolower(name) == lowered then
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
    local month_num
    for idx, name in pairs(cfg.month_names) do
        if vim.fn.tolower(name) == lowered then
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
