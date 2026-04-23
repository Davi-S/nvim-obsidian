local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "open_date_picker",
    version = "mvp-v1",
    dependencies = {
        "date_picker",
        "adapters.neovim.calendar_buffer",
    },
    input = {
        mode = "visualizer|picker",
        initial_date = "table|nil",
        locale = "string|nil",
        marks = "table|nil",
        ui_variant = "buffer|nil",
        on_finish = "function|nil",
    },
    output = {
        ok = "boolean",
        action = "selected|closed|cancelled|nil",
        date = "table|nil",
        cursor_date = "table|nil",
        error = "domain_error|nil",
    },
}

-- Validate calendar mode at the use-case edge so adapters can assume a valid value.
local function resolve_mode(mode)
    local value = tostring(mode or "visualizer")
    if value == "visualizer" or value == "picker" then
        return value
    end
    return nil
end

function M.execute(ctx, input)
    if type(ctx) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end

    if type(input) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
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
            error = errors.new(errors.codes.INVALID_INPUT, "mode must be visualizer or picker"),
        }
    end

    local ui_variant = tostring(input.ui_variant or "buffer")
    if ui_variant ~= "buffer" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ui_variant must be buffer for MVP"),
        }
    end

    local date_picker = ctx.date_picker
    if type(date_picker) ~= "table" or type(date_picker.normalize_date) ~= "function" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.date_picker.normalize_date is required"),
        }
    end

    local calendar_buffer = nil
    if type(ctx.adapters) == "table" and type(ctx.adapters.calendar_buffer) == "table" then
        calendar_buffer = ctx.adapters.calendar_buffer
    end

    if type(calendar_buffer) ~= "table" or type(calendar_buffer.open_calendar) ~= "function" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.adapters.calendar_buffer.open_calendar is required"),
        }
    end

    local request = {
        mode = mode,
        initial_date = date_picker.normalize_date(input.initial_date),
        locale = type(input.locale) == "string" and input.locale or ((ctx.config and ctx.config.locale) or "en-US"),
        marks = type(input.marks) == "table" and input.marks or {},
        on_finish = type(input.on_finish) == "function" and input.on_finish or nil,
    }

    local result = calendar_buffer.open_calendar(ctx, request)
    if type(result) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
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
        error = result.error,
    }
end

return M
