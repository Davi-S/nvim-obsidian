local M = {}

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

local function is_valid_name(name)
    return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
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

local function localize_month(locale, month)
    local names = MONTH_NAMES[locale]
    if names and names[month] then
        return names[month]
    end
    return os.date("%B", to_timestamp({ year = 2000, month = month, day = 1 }))
end

local function localize_weekday(locale, wday)
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

function M._reset_for_tests()
    state.custom = {}
end

return M
