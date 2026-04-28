---@diagnostic disable: undefined-global

local open_date_picker = require("nvim_obsidian.use_cases.open_date_picker")

describe("open_date_picker use case", function()
    local function base_ctx()
        return {
            config = {
                locale = "en-US",
                calendar = {
                    week_start = "sunday",
                    highlights = {
                        title = "Title",
                        weekday = "Comment",
                        in_month_day = "Normal",
                        outside_month_day = "Comment",
                        today = "DiagnosticOk",
                        note_exists = "Bold",
                    },
                },
            },
            date_picker = {
                normalize_date = function(date)
                    return {
                        year = tonumber((date or {}).year) or 2026,
                        month = tonumber((date or {}).month) or 4,
                        day = tonumber((date or {}).day) or 27,
                    }
                end,
            },
            adapters = {
                calendar_buffer = {
                    open_calendar = function(_ctx, _request)
                        return {
                            ok = true,
                            action = "opened",
                            date = nil,
                            cursor_date = nil,
                            selected_kind = nil,
                            error = nil,
                        }
                    end,
                },
                calendar_floating = {
                    open_calendar = function(_ctx, _request)
                        return {
                            ok = true,
                            action = "opened",
                            date = nil,
                            cursor_date = nil,
                            selected_kind = nil,
                            error = nil,
                        }
                    end,
                },
            },
        }
    end

    it("uses buffer adapter by default", function()
        local used_buffer = false
        local used_floating = false
        local ctx = base_ctx()

        ctx.adapters.calendar_buffer.open_calendar = function(_ctx, request)
            used_buffer = true
            assert.equals("visualizer", request.mode)
            return {
                ok = true,
                action = "opened",
                date = nil,
                cursor_date = nil,
                selected_kind = nil,
                error = nil,
            }
        end

        ctx.adapters.calendar_floating.open_calendar = function()
            used_floating = true
            return { ok = false, error = nil }
        end

        local result = open_date_picker.execute(ctx, {
            mode = "visualizer",
        })

        assert.is_true(result.ok)
        assert.is_true(used_buffer)
        assert.is_false(used_floating)
    end)

    it("routes to floating adapter when ui_variant is floating", function()
        local used_buffer = false
        local used_floating = false
        local ctx = base_ctx()

        ctx.adapters.calendar_buffer.open_calendar = function()
            used_buffer = true
            return { ok = false, error = nil }
        end

        ctx.adapters.calendar_floating.open_calendar = function(_ctx, request)
            used_floating = true
            assert.equals("picker", request.mode)
            return {
                ok = true,
                action = "opened",
                date = nil,
                cursor_date = nil,
                selected_kind = nil,
                error = nil,
            }
        end

        local result = open_date_picker.execute(ctx, {
            mode = "picker",
            ui_variant = "floating",
        })

        assert.is_true(result.ok)
        assert.is_false(used_buffer)
        assert.is_true(used_floating)
    end)

    it("rejects unsupported ui_variant", function()
        local ctx = base_ctx()
        local result = open_date_picker.execute(ctx, {
            mode = "visualizer",
            ui_variant = "drawer",
        })

        assert.is_false(result.ok)
        assert.matches("ui_variant must be buffer or floating", tostring((result.error or {}).message))
    end)
end)
