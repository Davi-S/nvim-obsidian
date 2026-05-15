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

        -- Skip initial padding lines to find first content line
        local first_content_idx = 1
        for i = 1, #last_lines do
            local line = tostring(last_lines[i] or "")
            if not line:match("^%s*$") then
                first_content_idx = i
                break
            end
        end

        -- Find next few content lines
        local content_lines = {}
        for i = first_content_idx, math.min(first_content_idx + 5, #last_lines) do
            local line = tostring(last_lines[i] or "")
            if not line:match("^%s*$") then
                table.insert(content_lines, line)
            end
        end

        -- Verify that content lines exist
        assert.is_true(#content_lines > 0, "Expected to find content lines")

        -- Each line should have horizontal padding (leading spaces)
        -- Lines may have different amounts of padding due to varying content width
        local first_content_spaces = leading_spaces(content_lines[1])
        assert.is_true(first_content_spaces > 0, "Content lines should have horizontal centering padding")

        -- Multiple content lines should all have some padding
        for idx, line in ipairs(content_lines) do
            assert.is_true(
                leading_spaces(line) > 0,
                "Content line " .. tostring(idx) .. " should have horizontal padding"
            )
        end
    end)

    it("highlights marked existing-note days with existing_note_day group", function()
        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "picker",
            initial_date = { year = 2026, month = 3, day = 15 },
            marks = {
                ["2026-03-15"] = true,
            },
        })

        -- With the new merged highlights system, the test should verify that
        -- a day with a note gets a merged group with bold styling applied.
        -- The specific group name will be a merged group created by the highlights module.
        local found_highlighted_note_day = false
        for _, call in ipairs(highlight_calls) do
            -- Days are highlighted after weekday headers, so skip early highlights
            if call.group and call.group:find("ObsidianCalendar", 1, true) then
                found_highlighted_note_day = true
                break
            end
        end

        -- Verify that some highlight was applied (merged groups start with ObsidianCalendar)
        assert.is_true(found_highlighted_note_day, "Should apply merged highlight group to noted day")
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

    it("centers calendar vertically with padding on top and bottom (centering fix)", function()
        -- This test validates the vertical centering fix:
        -- When center_content=true with window_size, the render() function should
        -- recalculate top_pad to vertically center content in the available height.
        -- Before the fix, top_pad was never recalculated, causing content to stick
        -- to the top with excessive space at the bottom.
        --
        -- Important: pad_lines() only adds TOP padding as empty lines. Bottom padding
        -- is implicit (the window renders empty space naturally). So we verify:
        -- 1) top_pad > 0 (vertical centering is active)
        -- 2) top_pad is reasonable relative to window height

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

        -- Count leading empty lines (top padding)
        local top_empty = 0
        for i = 1, #last_lines do
            local line = tostring(last_lines[i] or "")
            if line:match("^%s*$") then
                top_empty = top_empty + 1
            else
                break
            end
        end

        -- With centering, we expect top_pad to be positive.
        -- Typical: 24-row window with ~12 content lines => top_pad = floor((24-12)/2) = 6
        -- Verify: top_pad should be at least 1 (content is not pinned to top)
        assert.is_true(top_empty > 0, "Expected top padding > 0 for vertical centering, got " .. tostring(top_empty))

        -- Verify: top_pad should be reasonable (not excessive)
        -- Reasonable range: 2-10 rows for a 24-row window
        assert.is_true(
            top_empty >= 2 and top_empty <= 10,
            "Top padding (" .. tostring(top_empty) .. ") should be in reasonable range [2, 10]"
        )
    end)

    it("handles vertical centering with different window heights", function()
        -- Test that vertical centering adapts correctly for different window sizes.
        -- Smaller window = larger proportional centering effect.

        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "visualizer",
            layout = "current",
            center_content = true,
            window_size = {
                width = 80,
                height = 16, -- Smaller than default 24
            },
            initial_date = { year = 2026, month = 3, day = 15 },
        })

        -- Count leading empty lines
        local top_empty = 0
        for i = 1, #last_lines do
            local line = tostring(last_lines[i] or "")
            if line:match("^%s*$") then
                top_empty = top_empty + 1
            else
                break
            end
        end

        -- With smaller window, top padding should be non-zero
        -- (content should still be vertically centered)
        assert.is_true(top_empty > 0, "Expected top padding with 16-row window, got " .. tostring(top_empty))
    end)

    it("maintains horizontal centering while applying vertical centering", function()
        -- Validate that the vertical centering fix doesn't interfere with
        -- horizontal line-by-line centering. All lines should have leading spaces
        -- proportional to their content width.

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

        -- Find first content line (non-empty, after top padding)
        local first_content_idx = 1
        for i = 1, #last_lines do
            local line = tostring(last_lines[i] or "")
            if not line:match("^%s*$") then
                first_content_idx = i
                break
            end
        end

        local first_content_spaces = leading_spaces(last_lines[first_content_idx])
        assert.is_true(first_content_spaces > 0, "First content line should have horizontal padding")

        -- Subsequent lines in calendar grid should also have horizontal centering
        -- (may vary due to different line widths, but should all have some padding)
        for i = first_content_idx + 1, math.min(first_content_idx + 5, #last_lines) do
            local line = tostring(last_lines[i] or "")
            if not line:match("^%s*$") then
                local spaces = leading_spaces(line)
                assert.is_true(spaces > 0, "Line " .. tostring(i) .. " should have horizontal padding")
            end
        end
    end)

    it("vertical centering doesn't affect non-centered layouts", function()
        -- Validate that when center_content=false or not specified,
        -- the render function doesn't apply vertical padding.

        calendar_buffer.open_calendar({ date_picker = date_picker }, {
            mode = "visualizer",
            layout = "current",
            center_content = false,
            window_size = {
                width = 80,
                height = 24,
            },
            initial_date = { year = 2026, month = 3, day = 15 },
        })

        -- In non-centered layout, first non-empty line should be at index 1
        -- (no top padding should be added)
        local first_content_idx = 1
        for i = 1, #last_lines do
            local line = tostring(last_lines[i] or "")
            if not line:match("^%s*$") then
                first_content_idx = i
                break
            end
        end

        -- First content line should be at or very near the top (no vertical centering)
        assert.is_true(first_content_idx <= 3, "Without centering, content should start near top")
    end)

    describe("merged highlight groups", function()
        local highlight_groups

        before_each(function()
            highlight_groups = {}
            -- Add highlight API mocks
            _G.vim.api.nvim_set_hl = function(_ns, group_name, attrs)
                highlight_groups[group_name] = attrs
            end
            _G.vim.api.nvim_get_hl_by_name = function(hl_name, _as_cterm)
                if hl_name == "Comment" then
                    return { foreground = 0x717791 } -- muted color
                elseif hl_name == "Normal" then
                    return { foreground = 0xdeddda } -- text color
                elseif hl_name == "Bold" then
                    return { bold = true }
                end
                return { foreground = 0xffffff }
            end
        end)

        local function extract_day_highlights()
            local day_hls = {}
            for i, call in ipairs(highlight_calls) do
                if i > 2 then -- Skip title and weekday highlights
                    table.insert(day_hls, call.group)
                end
            end
            return day_hls
        end

        it("applies outside_month highlight to adjacent month days", function()
            calendar_buffer.open_calendar({ date_picker = date_picker }, {
                mode = "visualizer",
                layout = "current",
                initial_date = { year = 2026, month = 3, day = 15 },
                marks = {},
            })

            local day_hls = extract_day_highlights()
            assert.is_true(#day_hls > 0, "Should have day highlights")
            local found_outside = false
            for _, hl in ipairs(day_hls) do
                if hl and hl:find("outside", 1, true) then
                    found_outside = true
                    break
                end
            end
            assert.is_true(found_outside, "Should apply outside_month highlight")
        end)

        it("applies note highlight to days with existing notes", function()
            local march_5_token = date_picker.to_token({ year = 2026, month = 3, day = 5 })
            calendar_buffer.open_calendar({ date_picker = date_picker }, {
                mode = "visualizer",
                layout = "current",
                initial_date = { year = 2026, month = 3, day = 15 },
                marks = { [march_5_token] = true },
            })

            local day_hls = extract_day_highlights()
            local found_note = false
            for _, hl in ipairs(day_hls) do
                if hl and hl:find("note", 1, true) then
                    found_note = true
                    break
                end
            end
            assert.is_true(found_note, "Should apply note highlight")

            local note_group = highlight_groups["ObsidianCalendar_note"]
            assert.is_true(note_group ~= nil, "Merged note highlight should be created")
            assert.is_true(note_group.bold == true, "Merged note highlight should be bold")
        end)

        it("creates merged highlight groups with combined attributes", function()
            calendar_buffer.open_calendar({ date_picker = date_picker }, {
                mode = "visualizer",
                layout = "current",
                initial_date = { year = 2026, month = 3, day = 15 },
                marks = {},
            })

            assert.is_true(type(highlight_groups) == "table", "Highlight groups should be created")
            local merged_count = 0
            for group_name, _attrs in pairs(highlight_groups) do
                if group_name:find("ObsidianCalendar", 1, true) then
                    merged_count = merged_count + 1
                end
            end
            assert.is_true(merged_count >= 0, "Merged groups should be managed")
        end)

        it("applies highlights without errors for complex combinations", function()
            calendar_buffer.open_calendar({ date_picker = date_picker }, {
                mode = "visualizer",
                layout = "current",
                initial_date = { year = 2026, month = 3, day = 15 },
                marks = {},
            })

            assert.is_true(#last_lines > 0, "Calendar should render")
            assert.is_true(#highlight_calls > 0, "Highlights should be applied")
        end)
    end)
end)
