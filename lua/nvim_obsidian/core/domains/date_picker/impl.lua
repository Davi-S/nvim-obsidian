local M = {}

-- Date-picker domain module.
--
-- This module is intentionally pure and framework-agnostic. It does not call Neovim,
-- perform IO, or reference other plugin adapters. Its job is to provide deterministic
-- date math and month-grid modeling that any frontend (buffer, floating window, CLI)
-- can reuse.

local SECONDS_PER_DAY = 24 * 60 * 60

-- Normalize incoming week-start options to a strict internal enum.
--
-- Why this helper exists:
-- - Frontends and callers may pass nil/unknown values.
-- - Domain logic should never branch on untrusted values repeatedly.
-- - Keeping this in one place guarantees consistent behavior across all frontends.
local function normalize_week_start(value)
    local key = tostring(value or "sunday")
    if key == "monday" then
        return "monday"
    end
    return "sunday"
end

-- Normalize a date-like table into a strict { year, month, day } shape.
--
-- Why this exists:
-- UI and use-cases may pass partial or malformed values. We enforce one strict format
-- at the domain boundary so downstream logic never has to guard repeatedly.
local function normalize_date(value)
    local fallback = os.date("*t")

    if type(value) ~= "table" then
        return {
            year = fallback.year,
            month = fallback.month,
            day = fallback.day,
        }
    end

    local y = tonumber(value.year) or fallback.year
    local m = tonumber(value.month) or fallback.month
    local d = tonumber(value.day) or fallback.day

    -- os.time() naturally normalizes overflow values (e.g., month 13), which gives us
    -- a robust and locale-safe correction path.
    local ts = os.time({
        year = y,
        month = m,
        day = d,
        hour = 12,
    })

    local dt = os.date("*t", ts)
    return {
        year = dt.year,
        month = dt.month,
        day = dt.day,
    }
end

-- Convert a normalized date to an ISO token used across the plugin.
-- This token is stable and easy to use as a map key for date marks.
--
-- Design note:
-- The token is intentionally backend-owned and frontend-agnostic so all
-- consumers (buffer/floating/CLI) can share one identity format.
local function to_token(date)
    local normalized = normalize_date(date)
    return string.format("%04d-%02d-%02d", normalized.year, normalized.month, normalized.day)
end

-- Return how many days exist in a given month.
--
-- Technique:
-- We use day=0 of next month, which Lua resolves to the last day of current month.
local function days_in_month(year, month)
    local ts = os.time({
        year = year,
        month = month + 1,
        day = 0,
        hour = 12,
    })
    local dt = os.date("*t", ts)
    return dt.day
end

-- Shift a date by N days and return normalized {year, month, day}.
--
-- Implementation detail:
-- We always compute from a noon timestamp. This mitigates edge cases around
-- DST transitions where midnight arithmetic can behave unexpectedly.
local function shift_days(date, delta_days)
    local base = normalize_date(date)
    local ts = os.time({
        year = base.year,
        month = base.month,
        day = base.day,
        hour = 12,
    })
    local shifted = ts + (tonumber(delta_days) or 0) * SECONDS_PER_DAY
    local out = os.date("*t", shifted)
    return {
        year = out.year,
        month = out.month,
        day = out.day,
    }
end

-- Shift a date by N months while clamping day safely.
--
-- Example:
-- Jan 31 + 1 month -> Feb 28/29 (never invalid).
local function shift_months(date, delta_months)
    local base = normalize_date(date)
    local delta = tonumber(delta_months) or 0

    local target_year = base.year
    local target_month = base.month + delta

    while target_month > 12 do
        target_month = target_month - 12
        target_year = target_year + 1
    end

    while target_month < 1 do
        target_month = target_month + 12
        target_year = target_year - 1
    end

    local month_days = tonumber(days_in_month(target_year, target_month)) or 28
    local base_day = tonumber(base.day) or 1
    local target_day = math.min(base_day, month_days)

    return {
        year = target_year,
        month = target_month,
        day = target_day,
    }
end

-- Shift a date by N years while clamping day safely.
--
-- This keeps leap-day and short-month transitions valid while preserving
-- maximum intent from the original date.
local function shift_years(date, delta_years)
    local base = normalize_date(date)
    local target_year = base.year + (tonumber(delta_years) or 0)
    local month_days = tonumber(days_in_month(target_year, base.month)) or 28
    local base_day = tonumber(base.day) or 1

    return {
        year = target_year,
        month = base.month,
        day = math.min(base_day, month_days),
    }
end

-- Weekday with Monday=1..Sunday=7 (ISO weekday), which matches common
-- calendar UX expectations and keeps grid alignment straightforward.
--
-- For sunday mode we intentionally remap to Sunday=1..Saturday=7 so matrix
-- generation stays symmetrical with monday mode (always 1..7 indexing).
local function weekday_index(date, week_start)
    local normalized = normalize_date(date)
    local ts = os.time({
        year = normalized.year,
        month = normalized.month,
        day = normalized.day,
        hour = 12,
    })

    local start = normalize_week_start(week_start)
    if start == "monday" then
        -- %u maps Monday..Sunday to 1..7.
        return tonumber(os.date("%u", ts)) or 1
    end

    -- %w maps Sunday..Saturday to 0..6; shift to 1..7.
    return (tonumber(os.date("%w", ts)) or 0) + 1
end

-- Build a 6x7 month matrix centered around the given date's month.
--
-- Output shape:
-- {
--   view = { year, month, day=1 },
--   weeks = {
--     {
--       {
--         date = { year, month, day },
--         token = "YYYY-MM-DD",
--         in_view_month = boolean,
--         weekday = 1..7,
--       },
--       ... 7 days
--     },
--     ... 6 weeks
--   }
-- }
--
-- Why always 6 rows:
-- This keeps rendering stable in text UIs and avoids cursor remapping when month
-- height changes between 4/5/6 rows.
local function month_matrix(anchor_date, options)
    -- All caller input is normalized inside the domain so matrix generation is
    -- deterministic and does not depend on frontend validation quality.
    local anchor = normalize_date(anchor_date)
    local week_start = normalize_week_start(type(options) == "table" and options.week_start or nil)
    local view_month_start = {
        year = anchor.year,
        month = anchor.month,
        day = 1,
    }

    local first_weekday = weekday_index(view_month_start, week_start)
    local grid_start = shift_days(view_month_start, -(first_weekday - 1))

    local weeks = {}

    -- Fixed 6-row strategy:
    -- We always produce a 6x7 grid. This avoids UI shape jitter across months
    -- and makes cursor mapping significantly simpler for text frontends.
    for row = 1, 6 do
        local week = {}
        for col = 1, 7 do
            local cell_index = ((row - 1) * 7) + (col - 1)
            local cell_date = shift_days(grid_start, cell_index)
            table.insert(week, {
                date = cell_date,
                token = to_token(cell_date),
                in_view_month = cell_date.month == anchor.month and cell_date.year == anchor.year,
                weekday = col,
            })
        end
        table.insert(weeks, week)
    end

    return {
        view = {
            year = anchor.year,
            month = anchor.month,
            day = 1,
        },
        week_start = week_start,
        weeks = weeks,
    }
end

-- Public API
M.normalize_date = normalize_date
M.to_token = to_token
M.days_in_month = days_in_month
M.shift_days = shift_days
M.shift_months = shift_months
M.shift_years = shift_years
M.month_matrix = month_matrix
M.normalize_week_start = normalize_week_start

return M
