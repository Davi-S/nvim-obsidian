local M = {}

local EN_WEEKDAYS = {
    sunday = true,
    monday = true,
    tuesday = true,
    wednesday = true,
    thursday = true,
    friday = true,
    saturday = true,
}

local PT_WEEKDAYS = {
    domingo = true,
    segunda = true,
    ["segunda-feira"] = true,
    terca = true,
    ["terca-feira"] = true,
    ["terça"] = true,
    ["terça-feira"] = true,
    quarta = true,
    ["quarta-feira"] = true,
    quinta = true,
    ["quinta-feira"] = true,
    sexta = true,
    ["sexta-feira"] = true,
    sabado = true,
    sábado = true,
}

local EN_MONTHS = {
    january = true,
    february = true,
    march = true,
    april = true,
    may = true,
    june = true,
    july = true,
    august = true,
    september = true,
    october = true,
    november = true,
    december = true,
}

local PT_MONTHS = {
    janeiro = true,
    fevereiro = true,
    marco = true,
    ["março"] = true,
    abril = true,
    maio = true,
    junho = true,
    julho = true,
    agosto = true,
    setembro = true,
    outubro = true,
    novembro = true,
    dezembro = true,
}

local function trim(text)
    local s = tostring(text or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_date_input(date)
    if type(date) == "number" then
        return os.date("*t", date)
    end

    if type(date) == "table" and type(date.year) == "number" and type(date.month) == "number" and type(date.day) == "number" then
        return {
            year = date.year,
            month = date.month,
            day = date.day,
            hour = date.hour,
            min = date.min,
            sec = date.sec,
            wday = date.wday,
            yday = date.yday,
            isdst = date.isdst,
        }
    end

    return os.date("*t")
end

local function to_timestamp(date_tbl)
    return os.time({
        year = date_tbl.year,
        month = date_tbl.month,
        day = date_tbl.day,
        hour = date_tbl.hour or 12,
        min = date_tbl.min or 0,
        sec = date_tbl.sec or 0,
    })
end

local function from_timestamp(ts)
    local t = os.date("*t", ts)
    return {
        year = t.year,
        month = t.month,
        day = t.day,
    }
end

local function format_yyyy_mm_dd(date_tbl)
    return string.format("%04d-%02d-%02d", date_tbl.year, date_tbl.month, date_tbl.day)
end

local function format_yyyy_mm(date_tbl)
    return string.format("%04d-%02d", date_tbl.year, date_tbl.month)
end

local function format_yyyy(date_tbl)
    return string.format("%04d", date_tbl.year)
end

local function iso_week_parts(date_tbl)
    local ts = to_timestamp(date_tbl)
    local iso_year = tonumber(os.date("%G", ts)) or date_tbl.year
    local iso_week = tonumber(os.date("%V", ts)) or 1
    return iso_year, iso_week
end

local function iso_week_start(date_tbl)
    local ts = to_timestamp(date_tbl)
    local weekday = tonumber(os.date("%u", ts)) or 1
    local monday_ts = ts - ((weekday - 1) * 86400)
    return from_timestamp(monday_ts)
end

local function classify_by_keyword(raw)
    local s = raw:lower()

    if s == "today" or s == "tomorrow" or s == "yesterday" or s == "hoje" or s == "amanha" or s == "amanhã" or s == "ontem" then
        return "daily"
    end

    if s:match("^[+-]%d+d$") then
        return "daily"
    end

    if EN_WEEKDAYS[s] or PT_WEEKDAYS[s] then
        return "daily"
    end

    local left, right = s:match("^(%S+)%s+(%d%d%d%d)$")
    if left and right and (EN_MONTHS[left] or PT_MONTHS[left]) then
        return "monthly"
    end

    local year, month_word = s:match("^(%d%d%d%d)%s+(%S+)$")
    if year and month_word and (EN_MONTHS[month_word] or PT_MONTHS[month_word]) then
        return "monthly"
    end

    return nil
end

function M.classify_input(raw, _now)
    local s = trim(raw)
    if s == "" then
        return { kind = "none" }
    end

    if s:match("^%d%d%d%d%-%d%d%-%d%d$") then
        return { kind = "daily" }
    end

    if s:match("^%d%d%d%d%-%d%d$") then
        return { kind = "monthly" }
    end

    if s:match("^%d%d%d%d$") then
        return { kind = "yearly" }
    end

    if s:match("^%d%d%d%d%-W%d%d$") or s:match("^%d%d%d%d%s+[Ww]eek%s+%d%d$") or s:lower():match("^%d%d%d%d%s+semana%s+%d%d$") then
        return { kind = "weekly" }
    end

    local from_keyword = classify_by_keyword(s)
    if from_keyword then
        return { kind = from_keyword }
    end

    return { kind = "none" }
end

function M.build_title(kind, date, _locale)
    local dt = normalize_date_input(date)

    if kind == "daily" then
        return { title = format_yyyy_mm_dd(dt) }
    end

    if kind == "weekly" then
        local iso_year, iso_week = iso_week_parts(dt)
        return { title = string.format("%04d-W%02d", iso_year, iso_week) }
    end

    if kind == "monthly" then
        return { title = format_yyyy_mm(dt) }
    end

    if kind == "yearly" then
        return { title = format_yyyy(dt) }
    end

    return { title = "" }
end

local function adjust_month(year, month, delta)
    local idx = (year * 12 + (month - 1)) + delta
    local ny = math.floor(idx / 12)
    local nm = (idx % 12) + 1
    return ny, nm
end

function M.compute_adjacent(kind, date, direction)
    local dt = normalize_date_input(date)
    local dir = direction or "current"

    local delta = 0
    if dir == "next" then
        delta = 1
    elseif dir == "prev" then
        delta = -1
    end

    if kind == "daily" then
        local ts = to_timestamp(dt) + (delta * 86400)
        return { target_date = from_timestamp(ts) }
    end

    if kind == "weekly" then
        local monday = iso_week_start(dt)
        local ts = to_timestamp(monday) + (delta * 7 * 86400)
        return { target_date = from_timestamp(ts) }
    end

    if kind == "monthly" then
        local y, m = adjust_month(dt.year, dt.month, delta)
        return {
            target_date = {
                year = y,
                month = m,
                day = 1,
            },
        }
    end

    if kind == "yearly" then
        return {
            target_date = {
                year = dt.year + delta,
                month = 1,
                day = 1,
            },
        }
    end

    return {
        target_date = {
            year = dt.year,
            month = dt.month,
            day = dt.day,
        },
    }
end

return M
