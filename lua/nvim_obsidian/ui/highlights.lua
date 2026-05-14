---Calendar highlight merging and theming.
---
---This module creates and manages Neovim highlight groups for calendar cells
---that combine multiple visual traits (italic for out-of-month, bold for notes,
---sapphire color for today) into single merged highlight groups.
---
---Merging happens at setup time; per-cell rendering only looks up cached group names.

local M = {}

-- Cached base highlight attributes: {fg, bold, italic, etc.}
local cached_base_attrs = {}

-- Cached merged highlight groups: {[flags_key] = "GroupName"}
local cached_merged_groups = {}

-- Well-known highlight group names for fallback retrieval.
local FALLBACK_GROUPS = {
    comment = "Comment",
    normal = "Normal",
    diagnostic_ok = "DiagnosticOk",
}

-- Default sapphire hex if colorscheme doesn't define one.
local FALLBACK_SAPPHIRE = "#4fc8ff"

---Extract fg color from a Neovim highlight group.
---Returns {r, g, b} table or nil if not found.
local function get_hl_color(hl_name)
    if type(vim.api.nvim_get_hl_by_name) ~= "function" then
        return nil
    end

    local ok, hl = pcall(vim.api.nvim_get_hl_by_name, hl_name, true)
    if not ok or not hl or not hl.foreground then
        return nil
    end

    local fg = hl.foreground
    if type(fg) ~= "number" then
        return nil
    end

    -- Convert RGB integer to {r, g, b} for comparison.
    return {
        r = bit.band(bit.rshift(fg, 16), 0xFF),
        g = bit.band(bit.rshift(fg, 8), 0xFF),
        b = bit.band(fg, 0xFF),
    }
end

---Convert {r, g, b} back to hex string for vim.api.nvim_set_hl.
local function rgb_to_hex(rgb)
    if not rgb or not rgb.r or not rgb.g or not rgb.b then
        return nil
    end
    return string.format("#%02x%02x%02x", rgb.r, rgb.g, rgb.b)
end

---Setup calendar base highlight attributes once at plugin load.
---Reads from base groups and caches attributes for later merging.
function M.setup()
    -- Read muted color (for out-of-month) from Comment group.
    local muted_fg = get_hl_color(FALLBACK_GROUPS.comment)
    if muted_fg then
        cached_base_attrs.muted_fg = rgb_to_hex(muted_fg)
    end

    -- Read text color (for notes) from Normal group.
    local text_fg = get_hl_color(FALLBACK_GROUPS.normal)
    if text_fg then
        cached_base_attrs.text_fg = rgb_to_hex(text_fg)
    end

    -- Sapphire is typically a branding color not available in base highlights.
    -- We assume it's defined in the colorscheme or use fallback.
    cached_base_attrs.sapphire_fg = FALLBACK_SAPPHIRE
end

---Get or create a merged highlight group for a day cell with given flags.
---
---Returns the highlight group name (string) to apply to the cell.
---
---@param is_outside_month boolean — day is outside the current view month
---@param has_note boolean — day has an existing journal/daily note
---@param is_today boolean — day is today
---@return string highlight_group_name
function M.get_day_hl_group(is_outside_month, has_note, is_today)
    -- Build a cache key from the flags.
    local key = string.format("o=%s,n=%s,t=%s", tostring(is_outside_month), tostring(has_note), tostring(is_today))

    -- Return cached group if already created.
    if cached_merged_groups[key] then
        return cached_merged_groups[key]
    end

    -- Compute merged attributes based on flags and precedence rules.
    local attrs = {}

    -- Base: start with in_month_day style (normal text, no special traits).
    -- This is overridden by the following flags.

    -- Rule 1: is_outside_month contributes italic + muted color.
    -- BUT if is_today, we'll override the color (see Rule 3).
    if is_outside_month then
        attrs.italic = true
        if not is_today then
            -- Only use muted color if NOT today (today color takes precedence).
            attrs.fg = cached_base_attrs.muted_fg or FALLBACK_GROUPS.comment
        end
    end

    -- Rule 2: has_note contributes bold + text color.
    -- UNLESS is_today, then we use sapphire instead (see Rule 3).
    if has_note then
        attrs.bold = true
        if not is_today then
            attrs.fg = cached_base_attrs.text_fg or FALLBACK_GROUPS.normal
        end
    end

    -- Rule 3: is_today takes precedence for color.
    -- Sapphire overrides both muted (outside) and text (note) colors.
    if is_today then
        attrs.fg = cached_base_attrs.sapphire_fg or FALLBACK_SAPPHIRE
        -- Bold is preserved from has_note if present; if not, no bold needed for today-only.
    end

    -- Create deterministic group name from flags.
    local group_parts = {}
    if is_outside_month then
        table.insert(group_parts, "outside")
    end
    if has_note then
        table.insert(group_parts, "note")
    end
    if is_today then
        table.insert(group_parts, "today")
    end

    local group_name
    if #group_parts == 0 then
        -- No special flags: use default in_month style (Normal).
        group_name = "ObsidianCalendarInMonth"
    else
        group_name = "ObsidianCalendar_" .. table.concat(group_parts, "_")
    end

    -- Define the highlight group via Neovim API.
    -- Use pcall for safety in case Neovim API is not available.
    if type(vim.api.nvim_set_hl) == "function" then
        pcall(vim.api.nvim_set_hl, 0, group_name, attrs)
    end

    -- Cache the group name for this flag combination.
    cached_merged_groups[key] = group_name

    return group_name
end

return M
