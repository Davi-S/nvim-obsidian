---Template rendering context builder.
---
---This module assembles immutable context snapshots passed into template
---rendering and placeholder resolvers. It intentionally avoids exposing live
---mutable config references to keep template evaluation deterministic.
local M = {}

local ORIGIN_MAP = {
    omni = "omni_create",
    journal = "journal_navigation",
    link = "link_follow_create",
}

---@param value any
---@param seen? table
---@return any
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

---@param value any
---@param seen? table
---@return any
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

---Build normalized time parts used in template contexts.
---@param now_ts integer
---@return table
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

---Map high-level origin token into internal template origin key.
---@param input_origin string|nil
---@return string|nil
function M.resolve_origin(input_origin)
    return ORIGIN_MAP[input_origin or ""]
end

---Build immutable template rendering context.
---
---Implementation notes:
---1) `config_snapshot` is deep-copied then wrapped as readonly.
---2) `time` contains both scalar fields and helper formatter.
---3) `note` block is included only when minimum invariants are satisfied.
---@param opts? table
---@return table
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

        -- Invariant: when note is present, title and path are non-empty strings.
        if type(title) == "string" and title ~= "" and type(path) == "string" and path ~= "" then
            ctx.note = {
                kind = kind,
                title = title,
                path = path,
                yaml = {
                    title = title,
                    kind = kind,
                    date = render_time.iso_date,
                },
            }
        end
    end

    return ctx
end

return M
