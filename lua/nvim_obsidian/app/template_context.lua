local M = {}

local ORIGIN_MAP = {
    omni = "omni_create",
    journal = "journal_navigation",
    link = "link_follow_create",
}

local function deep_copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    local cache = seen or {}
    if cache[value] then
        return cache[value]
    end

    local out = {}
    cache[value] = out
    for k, v in pairs(value) do
        out[deep_copy(k, cache)] = deep_copy(v, cache)
    end
    return out
end

local function deep_readonly(value, seen)
    if type(value) ~= "table" then
        return value
    end

    local cache = seen or {}
    if cache[value] then
        return cache[value]
    end

    local out = {}
    cache[value] = out
    for k, v in pairs(value) do
        out[k] = deep_readonly(v, cache)
    end

    return setmetatable(out, {
        __newindex = function()
            error("template context is immutable", 2)
        end,
        __metatable = "locked",
    })
end

local function time_parts(now_ts)
    local t = os.date("*t", now_ts)
    return {
        now_ts = now_ts,
        iso_date = os.date("%Y-%m-%d", now_ts),
        iso_datetime = os.date("%Y-%m-%dT%H:%M:%S", now_ts),
        year = t.year,
        month = t.month,
        day = t.day,
        hour = t.hour,
        min = t.min,
        sec = t.sec,
        wday = t.wday,
        yday = t.yday,
        iso_year = tonumber(os.date("%G", now_ts)) or t.year,
        iso_week = tonumber(os.date("%V", now_ts)) or 1,
        iso_weekday = tonumber(os.date("%u", now_ts)) or 1,
    }
end

local function parse_note_date(note_kind, note_title, render_time)
    if note_kind == "daily" and type(note_title) == "string" then
        local y, m, d = note_title:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        if y and m and d then
            local ts = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = 12,
                min = 0,
                sec = 0,
            })
            return {
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                iso_year = tonumber(os.date("%G", ts)) or tonumber(y),
                iso_week = tonumber(os.date("%V", ts)) or 1,
                iso_weekday = tonumber(os.date("%u", ts)) or 1,
            }
        end
    end

    if note_kind == "weekly" and type(note_title) == "string" then
        local y, w = note_title:match("^(%d%d%d%d)%-W(%d%d)$")
        if y and w then
            return {
                year = tonumber(y),
                month = nil,
                day = nil,
                iso_year = tonumber(y),
                iso_week = tonumber(w),
                iso_weekday = nil,
            }
        end
    end

    if note_kind == "monthly" and type(note_title) == "string" then
        local y, m = note_title:match("^(%d%d%d%d)%-(%d%d)$")
        if y and m then
            local ts = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = 1,
                hour = 12,
                min = 0,
                sec = 0,
            })
            return {
                year = tonumber(y),
                month = tonumber(m),
                day = nil,
                iso_year = tonumber(os.date("%G", ts)) or tonumber(y),
                iso_week = tonumber(os.date("%V", ts)) or 1,
                iso_weekday = nil,
            }
        end
    end

    if note_kind == "yearly" and type(note_title) == "string" then
        local y = note_title:match("^(%d%d%d%d)$")
        if y then
            local ts = os.time({
                year = tonumber(y),
                month = 1,
                day = 1,
                hour = 12,
                min = 0,
                sec = 0,
            })
            return {
                year = tonumber(y),
                month = nil,
                day = nil,
                iso_year = tonumber(os.date("%G", ts)) or tonumber(y),
                iso_week = tonumber(os.date("%V", ts)) or 1,
                iso_weekday = nil,
            }
        end
    end

    if note_kind == "note" then
        return nil
    end

    return {
        year = render_time.year,
        month = render_time.month,
        day = render_time.day,
        iso_year = render_time.iso_year,
        iso_week = render_time.iso_week,
        iso_weekday = render_time.iso_weekday,
    }
end

function M.resolve_origin(input_origin)
    return ORIGIN_MAP[input_origin or ""]
end

function M.build(opts)
    local options = opts or {}
    local now_ts = tonumber(options.now) or os.time()
    local render_time = time_parts(now_ts)

    local ctx = {
        meta = {
            origin = options.meta_origin,
            command = options.command,
        },
        config = deep_readonly(deep_copy(options.config_snapshot or {})),
        time = render_time,
        note = nil,
    }

    ctx.time.format_local = function(fmt)
        local pattern = type(fmt) == "string" and fmt ~= "" and fmt or "%Y-%m-%d"
        return os.date(pattern, now_ts)
    end

    if type(options.note) == "table" then
        local kind = options.note.kind
        local title = options.note.title
        local path = options.note.path

        ctx.note = {
            kind = kind,
            title = title,
            path = path,
            yaml = {
                title = title,
                kind = kind,
                date = render_time.iso_date,
            },
            date = parse_note_date(kind, title, render_time),
        }
    end

    return ctx
end

return M
