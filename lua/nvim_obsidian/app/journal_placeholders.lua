---Journal title placeholder engine.
---
---Supports built-in date placeholders plus user-registered custom resolvers.
---The renderer leaves unknown placeholders untouched to preserve intent.
local M = {}

local localize_month
local localize_weekday

local state = {
    custom = {},
}

local MONTH_NAMES = {
    ["en-US"] = {
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    },
    ["pt-BR"] = {
        "janeiro",
        "fevereiro",
        "março",
        "abril",
        "maio",
        "junho",
        "julho",
        "agosto",
        "setembro",
        "outubro",
        "novembro",
        "dezembro",
    },
}

local WEEKDAY_NAMES = {
    ["en-US"] = {
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
    },
    ["pt-BR"] = {
        "domingo",
        "segunda-feira",
        "terça-feira",
        "quarta-feira",
        "quinta-feira",
        "sexta-feira",
        "sábado",
    },
}

---Normalize token text for accent-insensitive comparisons.
---@param text any
---@return string
local function normalize_token(text)
    local s = tostring(text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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

    for accented, base in pairs(replacements) do
        s = s:gsub(accented, base)
    end

    return s
end

---@param month any
---@param locale any
---@return string|nil
local function month_name_by_locale(month, locale)
    local m = tonumber(month)
    if not m or m < 1 or m > 12 then
        return nil
    end
    return localize_month(tostring(locale or "en-US"), m)
end

---@param wday any
---@param locale any
---@return string|nil
local function weekday_name_by_locale(wday, locale)
    local d = tonumber(wday)
    if not d or d < 1 or d > 7 then
        return nil
    end
    return localize_weekday(tostring(locale or "en-US"), d)
end

---@param token any
---@param locale any
---@return integer|nil
local function parse_month_token(token, locale)
    local raw = tostring(token or "")
    if raw == "" then
        return nil
    end

    local numeric = tonumber(raw)
    if numeric and numeric >= 1 and numeric <= 12 then
        return math.floor(numeric)
    end

    local normalized = normalize_token(raw)
    if normalized == "" then
        return nil
    end

    local locale_names = MONTH_NAMES[tostring(locale or "")]
    if type(locale_names) == "table" then
        for idx, name in ipairs(locale_names) do
            if normalize_token(name) == normalized then
                return idx
            end
        end
    end

    for _, names in pairs(MONTH_NAMES) do
        for idx, name in ipairs(names) do
            if normalize_token(name) == normalized then
                return idx
            end
        end
    end

    return nil
end

---@param name any
---@return boolean
local function is_valid_name(name)
    return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

---Normalize accepted date inputs into an os.date table.
---@param date any
---@return table
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

---@param date_tbl table
---@return integer
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

localize_month = function(locale, month)
    local names = MONTH_NAMES[locale]
    if names and names[month] then
        return names[month]
    end
    return os.date("%B", to_timestamp({ year = 2000, month = month, day = 1 }))
end

localize_weekday = function(locale, wday)
    local names = WEEKDAY_NAMES[locale]
    if names and names[wday] then
        return names[wday]
    end
    return os.date("%A", to_timestamp({ year = 2000, month = 1, day = wday }))
end

local function build_base_placeholders(date_tbl, locale)
    local ts = to_timestamp(date_tbl)
    local iso_year = tonumber(os.date("%G", ts)) or date_tbl.year
    local iso_week = tonumber(os.date("%V", ts)) or 1
    local iso_weekday = tonumber(os.date("%u", ts)) or 1

    return {
        year = string.format("%04d", date_tbl.year),
        month = string.format("%02d", date_tbl.month),
        day = string.format("%02d", date_tbl.day),
        day2 = string.format("%02d", date_tbl.day),
        month_name = localize_month(locale, date_tbl.month),
        weekday_name = localize_weekday(locale, date_tbl.wday or tonumber(os.date("%w", ts)) + 1),
        iso_year = string.format("%04d", iso_year),
        iso_week = string.format("%02d", iso_week),
        iso_weekday = tostring(iso_weekday),
    }
end

---Register a custom placeholder resolver.
---@param name string
---@param resolver fun(context: table): any
---@param regex_fragment? string
---@return boolean
---@return string|nil
function M.register_placeholder(name, resolver, regex_fragment)
    if not is_valid_name(name) then
        return false, "invalid placeholder name"
    end
    if type(resolver) ~= "function" then
        return false, "placeholder resolver must be a function"
    end

    state.custom[name] = {
        resolver = resolver,
        regex_fragment = regex_fragment,
    }

    return true, nil
end

---Render title format by replacing placeholder tokens.
---@param title_format string
---@param opts? table
---@return string
function M.render_title_format(title_format, opts)
    local pattern = tostring(title_format or "")
    local config = (opts and opts.config) or {}
    local locale = tostring(config.locale or "en-US")
    local date_tbl = normalize_date_input(opts and opts.date)

    local base = build_base_placeholders(date_tbl, locale)
    local context = {
        config = config,
        date = date_tbl,
        placeholders = vim.deepcopy(base),
    }

    local rendered = pattern:gsub("{{([%a_][%w_]*)}}", function(name)
        if base[name] ~= nil then
            return tostring(base[name])
        end

        local custom = state.custom[name]
        if custom and type(custom.resolver) == "function" then
            local ok, value = pcall(custom.resolver, context)
            if ok and value ~= nil then
                return tostring(value)
            end
        end

        return "{{" .. name .. "}}"
    end)

    return rendered
end

---@param month any
---@param locale any
---@return string|nil
function M.month_name(month, locale)
    return month_name_by_locale(month, locale)
end

---@param wday any
---@param locale any
---@return string|nil
function M.weekday_name(wday, locale)
    return weekday_name_by_locale(wday, locale)
end

---@param token any
---@param locale any
---@return integer|nil
function M.parse_month_token(token, locale)
    return parse_month_token(token, locale)
end

---@param format string
---@param date any
---@param locale any
---@return string
function M.render_title(format, date, locale)
    return M.render_title_format(format, {
        date = date,
        config = {
            locale = tostring(locale or "en-US"),
        },
    })
end

---Test helper to clear registered custom placeholders.
function M._reset_for_tests()
    state.custom = {}
end

return M
