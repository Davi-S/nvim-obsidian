local M = {}

local function iso_week_start(year, week)
    local jan4 = os.time({ year = year, month = 1, day = 4, hour = 12 })
    local jan4_wday = os.date("*t", jan4).wday
    local monday_delta = (jan4_wday + 5) % 7
    local week1_monday = jan4 - (monday_delta * 86400)
    return week1_monday + ((week - 1) * 7 * 86400)
end

function M.daily_title(ts, cfg)
    local t = os.date("*t", ts)
    local month = cfg.month_names[t.month] or vim.fn.tolower(os.date("%B", ts))
    local weekday = cfg.weekday_names[t.wday] or vim.fn.tolower(os.date("%A", ts))
    return string.format("%04d %s %02d, %s", t.year, month, t.day, weekday)
end

function M.weekly_title(ts)
    local y = tonumber(os.date("%G", ts))
    local w = tonumber(os.date("%V", ts))
    return string.format("%04d semana %d", y, w)
end

function M.monthly_title(ts, cfg)
    local t = os.date("*t", ts)
    local month = cfg.month_names[t.month] or vim.fn.tolower(os.date("%B", ts))
    return string.format("%04d %s", t.year, month)
end

function M.yearly_title(ts)
    return os.date("%Y", ts)
end

function M.parse_daily_title(title, cfg)
    local y, mname, d = title:match("^(%d%d%d%d)%s+(.+)%s+(%d%d?),")
    if not y then
        return nil
    end

    local year = tonumber(y)
    local day = tonumber(d)
    if not year or not day then
        return nil
    end

    local month_num
    local lowered = vim.fn.tolower(mname)
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

function M.parse_weekly_title(title)
    local y, w = title:match("^(%d%d%d%d)%s+semana%s+(%d%d?)$")
    if not y then
        return nil
    end
    local year = tonumber(y)
    local week = tonumber(w)
    if not year or not week then
        return nil
    end
    return iso_week_start(year, week)
end

function M.parse_monthly_title(title, cfg)
    local y, mname = title:match("^(%d%d%d%d)%s+(.+)$")
    if not y then
        return nil
    end
    local year = tonumber(y)
    if not year then
        return nil
    end
    local lowered = vim.fn.tolower(mname)
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

function M.parse_yearly_title(title)
    local y = title:match("^(%d%d%d%d)$")
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
