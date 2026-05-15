---Calendar highlight merging and theming.
---
---This module reads the user's configured calendar highlight groups and merges
---their attributes at runtime so combined day states keep the right visual
---traits. Existing-note days stay bold, out-of-month days stay italic, and
---today's color takes precedence.

local M = {}

local DEFAULT_CONFIG = {
    title = "Title",
    weekday = "Comment",
    in_month_day = "Normal",
    outside_month_day = "Comment",
    today = "DiagnosticOk",
    note_exists = "Bold",
}

local FALLBACK_SAPPHIRE = "#4fc8ff"

local cached_config = vim.tbl_deep_extend("force", {}, DEFAULT_CONFIG)
local cached_signature = nil
local cached_style_groups = {}
local cached_merged_groups = {}

local function reset_cache(signature, config)
    cached_signature = signature
    cached_config = config
    cached_style_groups = {}
    cached_merged_groups = {}
end

local function normalize_group_name(value, fallback)
    if type(value) ~= "string" or value == "" then
        return fallback
    end
    return value
end

local function config_signature(config)
    return table.concat({
        normalize_group_name(config.title, DEFAULT_CONFIG.title),
        normalize_group_name(config.weekday, DEFAULT_CONFIG.weekday),
        normalize_group_name(config.in_month_day, DEFAULT_CONFIG.in_month_day),
        normalize_group_name(config.outside_month_day, DEFAULT_CONFIG.outside_month_day),
        normalize_group_name(config.today, DEFAULT_CONFIG.today),
        normalize_group_name(config.note_exists, DEFAULT_CONFIG.note_exists),
    }, "|")
end

local function to_hex(fg)
    if type(fg) ~= "number" then
        return nil
    end
    return string.format("#%06x", fg)
end

local function extract_style(group_name)
    if cached_style_groups[group_name] then
        return cached_style_groups[group_name]
    end

    local attrs = {}
    if type(vim.api.nvim_get_hl_by_name) == "function" then
        local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group_name, true)
        if ok and type(hl) == "table" then
            attrs.fg = to_hex(hl.foreground)
            if hl.bold == true then
                attrs.bold = true
            end
            if hl.italic == true then
                attrs.italic = true
            end
        end
    end

    cached_style_groups[group_name] = attrs
    return attrs
end

local function merge_attrs(is_outside_month, has_note, is_today)
    local attrs = {}
    local outside_style = extract_style(normalize_group_name(cached_config.outside_month_day, DEFAULT_CONFIG.outside_month_day))
    local note_style = extract_style(normalize_group_name(cached_config.note_exists, DEFAULT_CONFIG.note_exists))
    local today_style = extract_style(normalize_group_name(cached_config.today, DEFAULT_CONFIG.today))

    if is_outside_month then
        attrs.italic = outside_style.italic == true or true
        if not is_today and outside_style.fg then
            attrs.fg = outside_style.fg
        end
    end

    if has_note then
        attrs.bold = note_style.bold == true or true
        if not is_today and note_style.fg then
            attrs.fg = note_style.fg
        end
    end

    if is_today then
        attrs.fg = today_style.fg or FALLBACK_SAPPHIRE
        if today_style.bold == true then
            attrs.bold = true
        end
        if today_style.italic == true then
            attrs.italic = true
        end
    end

    return attrs
end

---Setup the calendar highlight system for a specific config.
---@param highlights table|nil
function M.setup(highlights)
    local config = vim.tbl_deep_extend("force", {}, DEFAULT_CONFIG, type(highlights) == "table" and highlights or {})
    local signature = config_signature(config)
    if signature ~= cached_signature then
        reset_cache(signature, config)
    else
        cached_merged_groups = {}
    end
end

---Get the highlight group name for a day cell with given flags.
---
---@param is_outside_month boolean — day is outside the current view month
---@param has_note boolean — day has an existing journal/daily note
---@param is_today boolean — day is today
---@return string highlight_group_name
function M.get_day_hl_group(is_outside_month, has_note, is_today)
    if not cached_signature then
        M.setup(nil)
    end

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

    local group_name = "ObsidianCalendar_" .. table.concat(parts, "_")
    if cached_merged_groups[group_name] then
        return group_name
    end

    local attrs = merge_attrs(is_outside_month, has_note, is_today)
    if type(vim.api.nvim_set_hl) == "function" then
        pcall(vim.api.nvim_set_hl, 0, group_name, attrs)
    end

    cached_merged_groups[group_name] = true
    return group_name
end

return M
