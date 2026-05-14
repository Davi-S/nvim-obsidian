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

    local function leading_spaces(line)
        local value = tostring(line or "")
        local trimmed = value:gsub("^%s+", "")
        return #value - #trimmed
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

    it("centers each calendar line independently in floating layout", function()
        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "visualizer",
            layout = "current",
            center_content = true,
            window_size = {
                width = 80,
                height = 24,
            },
            initial_date = { year = 2026, month = 3, day = 15 },
        })

        assert.is_true(leading_spaces(last_lines[1]) > 0)
        assert.is_true(leading_spaces(last_lines[2]) > leading_spaces(last_lines[1]))
        assert.is_true(leading_spaces(last_lines[3]) > leading_spaces(last_lines[1]))
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

    it("moves cursor right by exactly one day cell on first keypress (without centering)", function()
        -- This tests the navigation bug fix:
        -- The first keypress should move by exactly one day (3 logical columns),
        -- not jump to the last day of the week or behave unexpectedly.

        open_picker()

        -- Start position: day 15 (Sunday), which is at logical column 0
        -- Before the fix, first keypress would jump to column 18 (last day)
        -- After the fix, first keypress should move to column 3 (day 16)
        local initial_col = cursor[2]
        assert.is_true(initial_col >= 0)

        keymaps["l"]() -- Move right

        -- Cursor should have moved right by exactly 3 columns (one day)
        assert.equals(initial_col + 3, cursor[2])
    end)

    it("moves cursor left by exactly one day cell on first keypress (without centering)", function()
        open_picker()

        -- Move to a middle position first (day 16, column 3)
        keymaps["l"]()
        local middle_col = cursor[2]
        assert.equals(3, middle_col)

        -- Now move left - should go back by one cell
        keymaps["h"]()
        assert.equals(middle_col - 3, cursor[2])
    end)

    it("moves cursor correctly with consecutive keypresses (without centering)", function()
        -- After the first keypress fix, all subsequent presses should work correctly.
        open_picker()

        local initial_col = cursor[2]

        -- Right, right, right, left, left
        keymaps["l"]()
        keymaps["l"]()
        keymaps["l"]()
        local col_after_three_rights = cursor[2]
        assert.equals(initial_col + 9, col_after_three_rights)

        keymaps["h"]()
        keymaps["h"]()
        local col_after_two_lefts = cursor[2]
        assert.equals(col_after_three_rights - 6, col_after_two_lefts)
    end)

    it("moves cursor right by exactly one day cell on first keypress (with centering)", function()
        -- This is the critical test case: with centering enabled, line offsets are added.
        -- The bug manifested most clearly with centered layouts where logical vs buffer
        -- column confusion caused first keypress to jump incorrectly.

        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "picker",
            layout = "current",
            center_content = true,
            window_size = {
                width = 80,
                height = 24,
            },
            initial_date = { year = 2026, month = 3, day = 15 },
        })

        local initial_col = cursor[2]

        -- With centering, line offsets are added to visual columns.
        -- The state should track logical columns, so navigation should still move by 3.
        keymaps["l"]()

        local col_after_right = cursor[2]
        -- With offsets, the buffer column includes padding, but the movement should
        -- still be consistent: next_buffer_col = old_buffer_col + 3 + (new_offset - old_offset)
        -- For same row, offsets are identical, so: movement = 3
        assert.equals(initial_col + 3, col_after_right)
    end)

    it("alternates left-right navigation correctly with centering", function()
        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "picker",
            layout = "current",
            center_content = true,
            window_size = {
                width = 80,
                height = 24,
            },
            initial_date = { year = 2026, month = 3, day = 15 },
        })

        local col_0 = cursor[2]

        keymaps["l"]()
        local col_1 = cursor[2]
        assert.equals(col_0 + 3, col_1)

        keymaps["l"]()
        local col_2 = cursor[2]
        assert.equals(col_1 + 3, col_2)

        keymaps["h"]()
        local col_back_1 = cursor[2]
        assert.equals(col_1, col_back_1)

        keymaps["h"]()
        local col_back_0 = cursor[2]
        assert.equals(col_0, col_back_0)
    end)
end)
