---Calendar highlight group selection.
---
---This module maps day cell states (outside_month, has_note, is_today) to
---pre-defined highlight group names. The actual highlight definitions are
---provided by the user's colorscheme configuration.
---
---Highlight groups expected to be defined by colorscheme:
--- - ObsidianCalendarInMonth: Regular in-month day
--- - ObsidianCalendar_outside: Outside month (italic + muted)
--- - ObsidianCalendar_note: Day with existing note (bold + text color)
--- - ObsidianCalendar_today: Today (sapphire color)
--- - ObsidianCalendar_outside_note: Outside month + has note (italic + bold + muted)
--- - ObsidianCalendar_outside_today: Outside month + is today (italic + sapphire)
--- - ObsidianCalendar_note_today: Has note + is today (bold + sapphire)
--- - ObsidianCalendar_outside_note_today: All three (italic + bold + sapphire)

local M = {}

---Setup function (kept for API compatibility, no-op now that groups are in colorscheme).
function M.setup()
    -- Color extraction now handled by colorscheme configuration.
    -- This function kept for backward compatibility.
end

---Get the highlight group name for a day cell with given flags.
---
---@param is_outside_month boolean — day is outside the current view month
---@param has_note boolean — day has an existing journal/daily note
---@param is_today boolean — day is today
---@return string highlight_group_name
function M.get_day_hl_group(is_outside_month, has_note, is_today)
    -- Build group name from flags.
    local parts = {}

    if is_outside_month then
        table.insert(parts, "outside")
    end

    if has_note then
        table.insert(parts, "note")
    end

    if is_today then
        table.insert(parts, "today")
    end

    -- No flags: use default in-month style
    if #parts == 0 then
        return "ObsidianCalendarInMonth"
    end

    -- Combine flags into group name
    return "ObsidianCalendar_" .. table.concat(parts, "_")
end

return M
