local errors = require("nvim_obsidian.core.shared.errors")

---Use-case: open date picker/visualizer through selected UI adapter.
---
---Maintains UI-agnostic orchestration by validating requests and delegating
---interaction lifecycle to the calendar buffer adapter.
local M = {}

-- Use-case responsibility:
-- - Validate caller intent and required dependencies.
-- - Normalize options into a stable request payload.
-- - Delegate interaction lifecycle to the selected adapter.
-- - Return a standardized result contract for all consumers.
--
-- This module must remain UI-agnostic. It should not call Neovim directly.

M.contract = {
    name = "open_date_picker",
    version = "mvp-v1",
    dependencies = {
        "date_picker",
        "adapters.neovim.calendar_buffer",
        "adapters.neovim.calendar_floating",
    },
    input = {
        mode = "visualizer|picker",
        initial_date = "table|nil",
        locale = "string|nil",
        marks = "table|nil",
        layout = "current|vsplit|hsplit|nil",
        ui_variant = "buffer|floating|nil",
        on_finish = "function|nil",
        week_start = "sunday|monday|nil",
    },
    output = {
        ok = "boolean",
        action = "selected|closed|cancelled|nil",
        date = "table|nil",
        cursor_date = "table|nil",
        selected_kind = "daily|weekly|monthly|yearly|nil",
        error = "domain_error|nil",
    },
}

-- Validate calendar mode at the use-case edge so adapters can assume a valid value.
--
-- Contract decision:
-- Returning nil for unknown values keeps failure handling explicit in execute().
---@param mode any
---@return string|nil
local function resolve_mode(mode)
    local value = tostring(mode or "visualizer")
    if value == "visualizer" or value == "picker" then
        return value
    end
    return nil
end

---@param layout any
---@return string|nil
local function resolve_layout(layout)
    local value = tostring(layout or "vsplit")
    if value == "current" or value == "vsplit" or value == "hsplit" then
        return value
    end
    return nil
end

---Execute open_date_picker orchestration.
---@param ctx table
---@param input table
---@return table
function M.execute(ctx, input)
    -- Hard boundary validation for orchestration input.
    -- We fail early with domain-style errors to keep downstream assumptions simple.
    if type(ctx) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end

    if type(input) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local mode = resolve_mode(input.mode)
    if not mode then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "mode must be visualizer or picker"),
        }
    end

    local layout = resolve_layout(input.layout)
    if not layout then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "layout must be current, vsplit, or hsplit"),
        }
    end

    local ui_variant = tostring(input.ui_variant or "buffer")
    if ui_variant ~= "buffer" and ui_variant ~= "floating" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ui_variant must be buffer or floating"),
        }
    end

    local date_picker = ctx.date_picker
    if type(date_picker) ~= "table" or type(date_picker.normalize_date) ~= "function" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.date_picker.normalize_date is required"),
        }
    end

    local calendar_adapter = nil
    if ui_variant == "floating" then
        if type(ctx.adapters) == "table" and type(ctx.adapters.calendar_floating) == "table" then
            calendar_adapter = ctx.adapters.calendar_floating
        end
    elseif type(ctx.adapters) == "table" and type(ctx.adapters.calendar_buffer) == "table" then
        calendar_adapter = ctx.adapters.calendar_buffer
    end

    if type(calendar_adapter) ~= "table" or type(calendar_adapter.open_calendar) ~= "function" then
        local missing_name = "ctx.adapters.calendar_buffer.open_calendar is required"
        if ui_variant == "floating" then
            missing_name = "ctx.adapters.calendar_floating.open_calendar is required"
        end
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, missing_name),
        }
    end

    local request = {
        -- Adapter request payload:
        -- All values here are already normalized/validated by this use-case.
        -- Frontends can rely on this contract rather than re-validating.
        mode = mode,
        initial_date = date_picker.normalize_date(input.initial_date),
        locale = type(input.locale) == "string" and input.locale or ((ctx.config and ctx.config.locale) or "en-US"),
        marks = type(input.marks) == "table" and input.marks or {},
        layout = layout,
        on_finish = type(input.on_finish) == "function" and input.on_finish or nil,
        week_start = input.week_start or
            ((ctx.config and ctx.config.calendar and ctx.config.calendar.week_start) or "sunday"),
        highlights = (ctx.config and ctx.config.calendar and ctx.config.calendar.highlights) or {},
    }

    local result = calendar_adapter.open_calendar(ctx, request)
    -- Defensive adapter contract check. Adapters are expected to return tables
    -- matching the output shape, but we guard this boundary explicitly.
    if type(result) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INTERNAL, "calendar adapter returned invalid response"),
        }
    end

    -- The adapter already owns the interaction loop; this use-case only forwards
    -- standardized output to callers.
    return {
        ok = result.ok == true,
        action = result.action,
        date = result.date,
        cursor_date = result.cursor_date,
        selected_kind = result.selected_kind,
        error = result.error,
    }
end

return M
