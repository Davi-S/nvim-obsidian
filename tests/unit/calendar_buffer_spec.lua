---@diagnostic disable: undefined-global

local calendar_buffer = require("nvim_obsidian.adapters.neovim.calendar_buffer")
local date_picker = require("nvim_obsidian.core.domains.date_picker.impl")

describe("calendar buffer adapter", function()
    local original_api
    local original_keymap
    local original_cmd
    local original_schedule
    local original_defer_fn

    local keymaps
    local cursor
    local last_lines
    local close_called
    local highlight_calls

    local function setup_vim_mocks()
        keymaps = {}
        cursor = { 4, 0 }
        last_lines = {}
        close_called = false
        highlight_calls = {}

        _G.vim = _G.vim or {}

        original_api = _G.vim.api
        original_keymap = _G.vim.keymap
        original_cmd = _G.vim.cmd
        original_schedule = _G.vim.schedule
        original_defer_fn = _G.vim.defer_fn

        _G.vim.api = {
            nvim_create_namespace = function()
                return 1
            end,
            nvim_buf_add_highlight = function(_bufnr, _ns, group, _line, _col_start, _col_end)
                table.insert(highlight_calls, {
                    group = group,
                })
            end,
            nvim_buf_clear_namespace = function()
            end,
            nvim_set_option_value = function()
            end,
            nvim_buf_set_lines = function(_bufnr, _start, _end, _strict, lines)
                last_lines = lines
            end,
            nvim_win_set_cursor = function(_winid, pos)
                cursor = { pos[1], pos[2] }
            end,
            nvim_win_get_cursor = function()
                return { cursor[1], cursor[2] }
            end,
            nvim_get_current_win = function()
                return 100
            end,
            nvim_get_current_buf = function()
                return 200
            end,
            nvim_create_autocmd = function(_events, _opts)
                return 1
            end,
            nvim_win_is_valid = function()
                return true
            end,
            nvim_win_close = function()
                close_called = true
            end,
        }

        _G.vim.keymap = {
            set = function(_mode, lhs, rhs, _opts)
                keymaps[lhs] = rhs
            end,
        }

        _G.vim.cmd = function()
        end
        _G.vim.schedule = function(fn)
            fn()
        end
        _G.vim.defer_fn = function(fn, _ms)
            fn()
        end
    end

    local function restore_vim_mocks()
        _G.vim.api = original_api
        _G.vim.keymap = original_keymap
        _G.vim.cmd = original_cmd
        _G.vim.schedule = original_schedule
        _G.vim.defer_fn = original_defer_fn
    end

    local function open_picker(on_finish)
        return calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "picker",
            initial_date = { year = 2026, month = 3, day = 15 },
            on_finish = on_finish,
        })
    end

    local function go_to_row_two()
        -- Picker starts in day-grid row; step up until row 2.
        for _ = 1, 10 do
            keymaps["k"]()
            if cursor[1] == 2 then
                return
            end
        end
    end

    before_each(function()
        setup_vim_mocks()
    end)

    after_each(function()
        restore_vim_mocks()
    end)

    it("does not allow title row focus", function()
        open_picker()

        go_to_row_two()
        assert.equals(2, cursor[1])

        keymaps["k"]()
        assert.equals(2, cursor[1])
    end)

    it("jumps row-2 selection between month and year in one keypress", function()
        open_picker()

        go_to_row_two()
        assert.equals(2, cursor[1])
        assert.equals(0, cursor[2])

        keymaps["l"]()
        -- March -> year starts at column #"March" + 1 = 6
        assert.equals(6, cursor[2])

        keymaps["h"]()
        assert.equals(0, cursor[2])
    end)

    it("maps row-2 month cursor to monthly selection", function()
        local finished = nil
        open_picker(function(payload)
            finished = payload
        end)

        go_to_row_two()
        assert.equals(0, cursor[2])

        keymaps["<CR>"]()

        assert.is_table(finished)
        assert.equals("selected", finished.action)
        assert.equals("monthly", finished.selected_kind)
    end)

    it("maps row-2 year cursor to yearly selection", function()
        local finished = nil
        open_picker(function(payload)
            finished = payload
        end)

        go_to_row_two()
        keymaps["l"]()
        assert.equals(6, cursor[2])

        keymaps["<CR>"]()

        assert.is_table(finished)
        assert.equals("selected", finished.action)
        assert.equals("yearly", finished.selected_kind)
    end)

    it("keeps visible month when hovering an out-of-month day", function()
        open_picker()

        assert.equals("March 2026", last_lines[2])

        -- First visible day for March 2026 Sunday-start matrix is outside month.
        cursor = { 4, 0 }
        keymaps["<LeftMouse>"]()

        assert.equals("March 2026", last_lines[2])
    end)

    it("highlights marked existing-note days with existing_note_day group", function()
        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "picker",
            initial_date = { year = 2026, month = 3, day = 15 },
            marks = {
                ["2026-03-15"] = true,
            },
        })

        local found = false
        for _, call in ipairs(highlight_calls) do
            if call.group == "Bold" then
                found = true
                break
            end
        end

        assert.is_true(found)
    end)
end)
