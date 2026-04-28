---@diagnostic disable: undefined-global

local calendar_floating = require("nvim_obsidian.adapters.neovim.calendar_floating")
local calendar_buffer = require("nvim_obsidian.adapters.neovim.calendar_buffer")

describe("calendar floating adapter", function()
    local original_api
    local original_o
    local original_open_calendar

    before_each(function()
        _G.vim = _G.vim or {}
        original_api = _G.vim.api
        original_o = _G.vim.o
        original_open_calendar = calendar_buffer.open_calendar

        _G.vim.o = {
            columns = 140,
            lines = 50,
        }

        _G.vim.api = {
            nvim_open_win = function(_buf, _enter, _config)
                return 700
            end,
            nvim_create_buf = function()
                return 500
            end,
            nvim_get_current_win = function()
                return 100
            end,
            nvim_set_current_win = function()
            end,
            nvim_win_is_valid = function()
                return true
            end,
            nvim_win_close = function()
            end,
        }
    end)

    after_each(function()
        _G.vim.api = original_api
        _G.vim.o = original_o
        calendar_buffer.open_calendar = original_open_calendar
    end)

    it("opens a centered floating window and delegates to calendar buffer adapter", function()
        local observed = nil
        local received_payload = nil

        calendar_buffer.open_calendar = function(_ctx, request)
            observed = request
            request.on_finish({ action = "selected" })
            return {
                ok = true,
                action = "opened",
                date = nil,
                cursor_date = nil,
                selected_kind = nil,
                error = nil,
            }
        end

        local result = calendar_floating.open_calendar({
            config = {
                calendar = {
                    floating = {
                        width = 96,
                        height = 26,
                        border = "double",
                    },
                },
            },
            date_picker = {
                normalize_date = function(date)
                    return date
                end,
            },
        }, {
            mode = "picker",
            on_finish = function(payload)
                received_payload = payload
            end,
        })

        assert.is_true(result.ok)
        assert.is_table(observed)
        assert.equals("current", observed.layout)
        assert.is_true(observed.close_on_finish)
        assert.is_true(observed.center_content)
        assert.is_table(observed.window_size)
        assert.equals(96, observed.window_size.width)
        assert.equals(26, observed.window_size.height)
        assert.is_function(observed.on_finish)
        assert.is_table(received_payload)
        assert.equals("selected", received_payload.action)
    end)

    it("returns internal error when floating APIs are unavailable", function()
        _G.vim.api.nvim_open_win = nil

        local result = calendar_floating.open_calendar({}, {})

        assert.is_false(result.ok)
        assert.matches("floating APIs", tostring((result.error or {}).message))
    end)
end)
