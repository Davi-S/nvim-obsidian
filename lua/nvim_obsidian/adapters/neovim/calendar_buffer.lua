---@diagnostic disable: undefined-global

local errors = require("nvim_obsidian.core.shared.errors")

---Neovim calendar buffer adapter.
---
---Renders month grids for visualizer/picker modes and drives interactive
---selection callbacks used by journal/calendar commands.
local M = {}

-- Month labels are intentionally explicit for MVP readability.
-- A future enhancement can route this through locale-aware formatting.
local MONTH_NAMES = {
    [1] = "January",
    [2] = "February",
    [3] = "March",
    [4] = "April",
    [5] = "May",
    [6] = "June",
    [7] = "July",
    [8] = "August",
    [9] = "September",
    [10] = "October",
    [11] = "November",
    [12] = "December",
}

local WEEKDAY_LABELS = {
    sunday = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" },
    monday = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" },
}

-- Frontend-side normalization for week start.
--
-- Note:
-- The backend also normalizes this value. We normalize here too so rendering
-- decisions (labels/layout assumptions) are deterministic even before matrix usage.
local function resolve_week_start(value)
    if tostring(value or "") == "monday" then
        return "monday"
    end
    return "sunday"
end

local function resolve_highlights(value)
    -- Merge user-provided highlight groups with stable defaults.
    --
    -- This keeps the frontend resilient to partial user config while still
    -- making visual styling fully configurable.
    local user = type(value) == "table" and value or {}
    return {
        title = tostring(user.title or "Title"),
        weekday = tostring(user.weekday or "Comment"),
        in_month_day = tostring(user.in_month_day or "Normal"),
        outside_month_day = tostring(user.outside_month_day or "Comment"),
        today = tostring(user.today or "DiagnosticOk"),
        note_exists = tostring(user.note_exists or "Bold"),
    }
end

local function is_nvim_ready()
    return vim
        and type(vim) == "table"
        and type(vim.api) == "table"
        and type(vim.keymap) == "table"
        and type(vim.keymap.set) == "function"
end

-- Normalize mode so all downstream branches can assume one of two values.
local function normalize_mode(mode)
    if mode == "picker" then
        return "picker"
    end
    return "visualizer"
end

local function normalize_layout(layout)
    local value = tostring(layout or "vsplit")
    if value == "current" or value == "vsplit" or value == "hsplit" then
        return value
    end
    return "vsplit"
end

local function build_title_line(mode)
    if mode == "picker" then
        return "Obsidian Calendar (picker mode)"
    end
    return "Obsidian Calendar (visualizer mode)"
end

local function month_label(date)
    return string.format("%s %04d", MONTH_NAMES[date.month] or "Month", date.year)
end

-- Convert domain date table into Neovim cursor row/col for the day grid.
--
-- Grid starts at line 4 (1-based), and each day cell has width 3 in "DD " format.
local function day_to_cursor(matrix, target_token)
    for week_index, week in ipairs(matrix.weeks or {}) do
        for day_index, cell in ipairs(week) do
            if cell.token == target_token then
                local line = 3 + week_index
                local col = (day_index - 1) * 3
                return line, col
            end
        end
    end

    -- Fallback to first day cell if token is absent for any reason.
    return 4, 0
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function resolve_content_padding(state)
    local padding = type(state.content_padding) == "table" and state.content_padding or {}
    local top = math.max(0, tonumber(padding.top) or 0)
    return top
end

local function shift_line_to_tokens(line_to_tokens, top_offset)
    local shifted = {}
    local offset = math.max(0, tonumber(top_offset) or 0)

    for row, tokens in pairs(line_to_tokens or {}) do
        shifted[row + offset] = tokens
    end

    return shifted
end

local function compute_line_offsets(lines, window_width)
    local offsets = {}
    local width = math.max(0, tonumber(window_width) or 0)

    for index, line in ipairs(lines or {}) do
        local line_width = #line
        offsets[index] = math.max(0, math.floor((width - line_width) / 2))
    end

    return offsets
end

local function pad_lines(lines, top_pad, line_offsets)
    local padded = {}
    local top = math.max(0, tonumber(top_pad) or 0)

    for _ = 1, top do
        table.insert(padded, "")
    end

    for index, line in ipairs(lines or {}) do
        local left = math.max(0, tonumber(line_offsets and line_offsets[index]) or 0)
        table.insert(padded, string.rep(" ", left) .. line)
    end

    return padded
end

local function line_offset_for_index(state, index)
    local offsets = type(state.line_offsets) == "table" and state.line_offsets or {}
    return math.max(0, tonumber(offsets[index]) or 0)
end

local function line_index_for_row(state, row)
    local top_pad = resolve_content_padding(state)
    local line = tonumber(row)
    if not line then
        return nil
    end
    return line - top_pad
end

-- Build all buffer lines plus metadata needed for click/cursor translation.
--
-- Returns:
-- - lines: printable content for buffer
-- - matrix: domain matrix used for highlighting decisions
-- - line_to_tokens: reverse map for cursor/mouse token resolution
local function build_lines(date_picker, state)
    local matrix = date_picker.month_matrix(state.view_date, {
        week_start = state.week_start,
    })
    local lines = {}

    table.insert(lines, build_title_line(state.mode))
    table.insert(lines, month_label(state.view_date))
    local weekday_labels = WEEKDAY_LABELS[state.week_start] or WEEKDAY_LABELS.sunday
    table.insert(lines, table.concat(weekday_labels, " "))

    local line_to_tokens = {}

    for week_index, week in ipairs(matrix.weeks or {}) do
        local day_chunks = {}
        local tokens = {}

        for _, cell in ipairs(week) do
            -- Always keep two-character numeric day text. Differentiation between current
            -- month and adjacent months is handled by highlighting, not by mutating digits.
            table.insert(day_chunks, string.format("%02d", cell.date.day))
            table.insert(tokens, cell.token)
        end

        table.insert(lines, table.concat(day_chunks, " "))
        line_to_tokens[3 + week_index] = tokens
    end

    table.insert(lines, "")

    return {
        lines = lines,
        matrix = matrix,
        line_to_tokens = line_to_tokens,
    }
end

-- Lazily create one namespace per calendar instance.
--
-- We scope highlights to an instance namespace so redraw operations can clear
-- only calendar artifacts without touching user highlights.
local function ensure_namespace(state)
    if state.namespace then
        return state.namespace
    end
    if type(vim.api.nvim_create_namespace) ~= "function" then
        return nil
    end
    state.namespace = vim.api.nvim_create_namespace("nvim-obsidian-calendar")
    return state.namespace
end

local function apply_highlights(bufnr, state, payload)
    -- Highlighting is purely presentational; never mutate matrix/domain state.
    local ns = ensure_namespace(state)
    if not ns or type(vim.api.nvim_buf_add_highlight) ~= "function" then
        return
    end

    if type(vim.api.nvim_buf_clear_namespace) == "function" then
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end

    local highlights = state.highlights
    local today_token = state.today_token
    local marks = type(state.marks) == "table" and state.marks or {}
    local matrix = payload.matrix
    local top_pad = resolve_content_padding(state)

    -- Title line.
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.title, top_pad, line_offset_for_index(state, 1), -1)

    -- Weekday header line.
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.weekday, top_pad + 2, line_offset_for_index(state, 3), -1)

    -- Day cells lines (4..9 in 1-based display, 3..8 in 0-based buffer lines).
    for week_idx, week in ipairs(matrix.weeks or {}) do
        local line0 = top_pad + 2 + week_idx
        local line_index = 3 + week_idx
        for day_idx, cell in ipairs(week) do
            local col_start = line_offset_for_index(state, line_index) + (day_idx - 1) * 3
            local col_end = col_start + 2

            local group = highlights.in_month_day
            if not cell.in_view_month then
                group = highlights.outside_month_day
            end
            if marks[cell.token] then
                group = highlights.note_exists
            end
            if cell.token == today_token then
                group = highlights.today
            end

            vim.api.nvim_buf_add_highlight(bufnr, ns, group, line0, col_start, col_end)
        end
    end
end

-- Configure the backing buffer as an ephemeral UI surface.
local function ensure_buffer_opts(bufnr)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
end

-- Redraw the entire calendar view from the current state snapshot.
--
-- Rendering order:
-- 1) text lines
-- 2) cursor placement
-- 3) highlights
--
-- This order guarantees highlight application always matches final content.
local function render(date_picker, bufnr, state)
    local payload = build_lines(date_picker, state)
    local top_pad = 0
    local line_offsets = {}

    if state.center_content and type(state.window_size) == "table" then
        local content_height = #payload.lines
        top_pad = math.max(0, math.floor(((tonumber(state.window_size.height) or 0) - content_height) / 2))
        line_offsets = compute_line_offsets(payload.lines, state.window_size.width)
    end

    state.content_padding = {
        top = top_pad,
    }
    state.line_offsets = line_offsets

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, pad_lines(payload.lines, top_pad, line_offsets))
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local line, col
    if state.mode == "picker" and type(state.cursor_row) == "number" and type(state.cursor_col) == "number" then
        line = state.cursor_row
        col = state.cursor_col + line_offset_for_index(state, line_index_for_row(state, line) or 1)
    else
        local token = date_picker.to_token(state.cursor_date)
        line, col = day_to_cursor(payload.matrix, token)
        line = line + top_pad
        col = col + line_offset_for_index(state, 3 + (line - top_pad - 3))
    end
    pcall(vim.api.nvim_win_set_cursor, state.winid, { line, col })

    state.line_to_tokens = shift_line_to_tokens(payload.line_to_tokens, top_pad)

    if state.mode == "picker" and type(state.cursor_row) ~= "number" then
        state.cursor_row = line
        state.cursor_col = col
    end

    apply_highlights(bufnr, state, payload)
end

-- Convert current cursor position to a date token using line_to_tokens map.
--
-- This is used for mouse-driven selection/movement sync.
local function token_from_cursor(date_picker, state)
    local ok, pos = pcall(vim.api.nvim_win_get_cursor, state.winid)
    if not ok or type(pos) ~= "table" then
        return nil
    end

    local line = tonumber(pos[1])
    local col = tonumber(pos[2]) or 0
    local tokens = line and state.line_to_tokens[line] or nil
    if type(tokens) ~= "table" then
        return nil
    end

    local day_index = math.floor(col / 3) + 1
    local token = tokens[day_index]
    if type(token) ~= "string" then
        return nil
    end

    return token
end

-- Parse an ISO token back to a date table.
--
-- The frontend intentionally uses the same token shape as the backend contract.
local function parse_token(token)
    local y, m, d = tostring(token or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
        return nil
    end
    return {
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
    }
end

local function token_from_position(state, row, col)
    local tokens = state.line_to_tokens[row]
    if type(tokens) ~= "table" then
        return nil
    end

    local day_index = math.floor((tonumber(col) or 0) / 3) + 1
    local token = tokens[day_index]
    if type(token) ~= "string" then
        return nil
    end

    return token
end

-- Map the current cursor row to a journal kind.
--
-- Selection model:
-- - title row -> yearly
-- - month label row -> monthly
-- - weekday header row -> weekly
-- - day grid rows -> daily
--
-- This keeps scope selection simple and avoids a separate mode selector while
-- still supporting all journal note families from the same calendar view.
local function selection_kind_for_row(state, row)
    local line = tonumber(row)
    if not line then
        return nil
    end

    local top_pad = resolve_content_padding(state)

    if line <= top_pad then
        return nil
    end

    if line == top_pad + 1 then
        return nil
    end

    if line == top_pad + 2 then
        return "monthly"
    end

    if line == top_pad + 3 then
        return "weekly"
    end

    if line >= top_pad + 4 and line <= top_pad + 9 then
        return "daily"
    end

    return nil
end

-- Resolve picker selection kind using both row and column.
--
-- Month/year share the same visual line. The year can be selected by placing
-- the cursor over its digits in that line.
local function selection_kind_for_cursor(state, row, col)
    local line = tonumber(row)
    local column = tonumber(col) or 0
    if not line then
        return nil
    end

    local top_pad = resolve_content_padding(state)

    if line == top_pad + 2 then
        local month_name = MONTH_NAMES[(state.view_date or {}).month] or "Month"
        local year_start_col = #month_name + 1
        local line_left = line_offset_for_index(state, 2)
        if column >= line_left + year_start_col then
            return "yearly"
        end
        return "monthly"
    end

    return selection_kind_for_row(state, line)
end

local function is_picker_header_row(state, row)
    local top_pad = resolve_content_padding(state)
    return row == top_pad + 1 or row == top_pad + 2 or row == top_pad + 3
end

-- Title row (line 1) is informational only and should never receive picker focus.
-- Normalize row movement so all interactive navigation starts from line 2.
local function normalize_picker_row(state, row)
    local line = tonumber(row)
    if not line then
        return 2
    end
    local top_pad = resolve_content_padding(state)
    return clamp(line, top_pad + 2, top_pad + 9)
end

local function line_col_from_cursor(state, row, col)
    local line_index = line_index_for_row(state, row)
    local left = line_index and line_offset_for_index(state, line_index) or 0
    return math.max(0, (tonumber(col) or 0) - left)
end

-- Safe window closer helper used by finish paths.
local function close_window(winid)
    if type(winid) == "number" and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_close, winid, true)
    end
end

-- Guarded callback execution to prevent consumer errors from breaking UI teardown.
local function safe_on_finish(handler, payload)
    if type(handler) ~= "function" then
        return
    end
    pcall(handler, payload)
end

---Open interactive calendar buffer UI.
---@param ctx table
---@param request table
---@return table
function M.open_calendar(ctx, request)
    -- Adapter boundary checks.
    -- This function must fail gracefully because it is called from command paths.
    if not is_nvim_ready() then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INTERNAL, "Neovim APIs required for calendar are unavailable"),
        }
    end

    local date_picker = ctx and ctx.date_picker
    if type(date_picker) ~= "table" or type(date_picker.normalize_date) ~= "function" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.date_picker.normalize_date is required"),
        }
    end

    local mode = normalize_mode(request and request.mode)
    local layout = normalize_layout(request and request.layout)
    local week_start = resolve_week_start(request and request.week_start)
    local highlights = resolve_highlights(request and request.highlights)
    local marks = type(request and request.marks) == "table" and request.marks or {}
    local on_finish = request and request.on_finish or nil
    local now = os.date("*t")
    local start_date = date_picker.normalize_date(request and request.initial_date or now)

    -- Interactive state is centralized in one table so every mapping callback
    -- mutates one source of truth and re-renders from it.
    --
    -- Keeping a single state object is important for future multi-frontend
    -- consistency (buffer view now, floating view later).
    local state = {
        mode = mode,
        layout = layout,
        close_on_finish = request and request.close_on_finish == true,
        center_content = request and request.center_content == true,
        window_size = type(request and request.window_size) == "table" and request.window_size or nil,
        week_start = week_start,
        highlights = highlights,
        marks = marks,
        today_token = date_picker.to_token(now),
        view_date = {
            year = start_date.year,
            month = start_date.month,
            day = 1,
        },
        cursor_date = {
            year = start_date.year,
            month = start_date.month,
            day = start_date.day,
        },
        done = false,
        result = {
            ok = true,
            action = "opened",
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = nil,
        },
        winid = nil,
        bufnr = nil,
        line_to_tokens = {},
        namespace = nil,
    }

    if layout == "vsplit" then
        -- Split defaults to vertical for calendar side-panel workflows.
        vim.cmd("botright vsplit")
    elseif layout == "hsplit" then
        -- Horizontal variant used by dedicated split command surface.
        vim.cmd("botright split")
    end
    state.winid = vim.api.nvim_get_current_win()

    -- A vertical split initially shows the same buffer as the source window.
    -- Create/switch to a dedicated scratch buffer so rendering the calendar
    -- does not overwrite the user's original note in both windows.
    local opened_bufnr = nil
    if type(vim.api.nvim_create_buf) == "function" and type(vim.api.nvim_win_set_buf) == "function" then
        local ok_create, bufnr = pcall(vim.api.nvim_create_buf, false, true)
        if ok_create and type(bufnr) == "number" and bufnr > 0 then
            local ok_set = pcall(vim.api.nvim_win_set_buf, state.winid, bufnr)
            if ok_set then
                opened_bufnr = bufnr
            end
        end
    end

    if not opened_bufnr then
        -- Compatibility fallback for minimal environments/mocks where
        -- nvim_create_buf or nvim_win_set_buf is unavailable.
        vim.cmd("enew")
        opened_bufnr = vim.api.nvim_get_current_buf()
    end

    state.bufnr = opened_bufnr

    ensure_buffer_opts(state.bufnr)
    render(date_picker, state.bufnr, state)

    local function refresh_after_cursor_shift(new_cursor)
        -- Cursor movement updates both cursor_date and view month so month boundaries
        -- are handled naturally when stepping across adjacent months.
        state.cursor_date = date_picker.normalize_date(new_cursor)
        state.view_date = {
            year = state.cursor_date.year,
            month = state.cursor_date.month,
            day = 1,
        }
        render(date_picker, state.bufnr, state)
    end

    local function refresh_picker_from_cursor()
        if type(state.cursor_row) ~= "number" then
            return
        end

        if state.cursor_row >= 4 then
            local token = token_from_position(state, state.cursor_row, state.cursor_col or 0)
            if token then
                local parsed = parse_token(token)
                if parsed then
                    state.cursor_date = date_picker.normalize_date(parsed)
                end
            end
        end

        render(date_picker, state.bufnr, state)
    end

    local function move_picker_row(delta)
        state.cursor_row = normalize_picker_row(state, (state.cursor_row or 4) + delta)

        if is_picker_header_row(state, state.cursor_row) then
            state.cursor_col = 0
        else
            state.cursor_col = clamp(state.cursor_col or 0, 0, 18)
        end

        refresh_picker_from_cursor()
    end

    local function move_picker_col(delta)
        local top_pad = resolve_content_padding(state)
        if not state.cursor_row or state.cursor_row < top_pad + 2 then
            return
        end

        if state.cursor_row == top_pad + 2 then
            -- Treat row 2 as two logical cells:
            -- 1) month cell (left side)
            -- 2) year cell (right side)
            --
            -- This matches the day-grid navigation model where one keypress
            -- moves one logical unit, not individual characters.
            local month_name = MONTH_NAMES[(state.view_date or {}).month] or "Month"
            local year_start_col = #month_name + 1
            local current_col = tonumber(state.cursor_col) or 0

            if delta > 0 then
                if current_col < year_start_col then
                    state.cursor_col = year_start_col
                else
                    state.cursor_col = year_start_col
                end
            elseif delta < 0 then
                if current_col >= year_start_col then
                    state.cursor_col = 0
                else
                    state.cursor_col = 0
                end
            end

            refresh_picker_from_cursor()
            return
        end

        -- Week/day grid rows are visually chunked in 3-character cells.
        state.cursor_col = clamp((state.cursor_col or 0) + (delta * 3), 0, 18)
        refresh_picker_from_cursor()
    end

    local function finish(action, selected_date, selected_kind)
        if state.done then
            return
        end

        -- Finish is idempotent: once done=true all later finish attempts are ignored.
        -- This protects against double-trigger scenarios from keymaps + autocmds.
        state.result.action = action
        state.result.date = selected_date and date_picker.normalize_date(selected_date) or nil
        state.result.cursor_date = date_picker.normalize_date(state.cursor_date)
        state.result.selected_kind = selected_kind
        state.done = true

        local payload = {
            ok = true,
            action = state.result.action,
            date = state.result.date,
            cursor_date = state.result.cursor_date,
            selected_kind = state.result.selected_kind,
            error = nil,

        }

        if action == "selected" then
            -- Selection path: run callback while calendar window is still active.
            --
            -- This allows consumers that call :edit/open_path to replace the
            -- calendar buffer in the same split, which is the expected picker UX.
            safe_on_finish(on_finish, payload)

            -- If callback did not replace this buffer, close the calendar window
            -- to preserve prior picker semantics.
            if (state.layout ~= "current" or state.close_on_finish)
                and type(vim.api.nvim_win_get_buf) == "function"
                and vim.api.nvim_win_is_valid(state.winid)
            then
                local ok_buf, current_buf = pcall(vim.api.nvim_win_get_buf, state.winid)
                if ok_buf and current_buf == state.bufnr then
                    close_window(state.winid)
                end
            end
            return
        end

        -- Non-selection paths still close before callback notification.
        if state.layout ~= "current" or state.close_on_finish then
            close_window(state.winid)
        end
        safe_on_finish(on_finish, payload)
    end

    local function move_by_days(delta)
        refresh_after_cursor_shift(date_picker.shift_days(state.cursor_date, delta))
    end

    local function move_by_months(delta)
        refresh_after_cursor_shift(date_picker.shift_months(state.cursor_date, delta))
    end

    local function move_by_years(delta)
        refresh_after_cursor_shift(date_picker.shift_years(state.cursor_date, delta))
    end

    local function move_to_today()
        local today = os.date("*t")
        refresh_after_cursor_shift({
            year = today.year,
            month = today.month,
            day = today.day,
        })
    end

    local function sync_cursor_from_window()
        -- Mouse navigation path:
        -- 1) read cursor cell
        -- 2) capture row/col and update date only for day-grid rows
        local ok, pos = pcall(vim.api.nvim_win_get_cursor, state.winid)
        if not ok or type(pos) ~= "table" then
            return
        end

        local new_row = tonumber(pos[1]) or state.cursor_row
        state.cursor_row = normalize_picker_row(state, new_row)
        state.cursor_col = line_col_from_cursor(state, state.cursor_row, pos[2])

        local top_pad = resolve_content_padding(state)
        if state.cursor_row and state.cursor_row >= top_pad + 4 then
            local token = token_from_position(state, state.cursor_row, state.cursor_col or 0)
            if token then
                local parsed = parse_token(token)
                if parsed then
                    state.cursor_date = date_picker.normalize_date(parsed)
                end
            end
        end

        render(date_picker, state.bufnr, state)
    end

    -- Buffer-local mappings keep calendar controls isolated from user global maps.
    local map_opts = { buffer = state.bufnr, silent = true, nowait = true }

    vim.keymap.set("n", "h", function()
        if state.mode == "picker" then
            move_picker_col(-1)
            return
        end
        move_by_days(-1)
    end, map_opts)

    vim.keymap.set("n", "l", function()
        if state.mode == "picker" then
            move_picker_col(1)
            return
        end
        move_by_days(1)
    end, map_opts)

    vim.keymap.set("n", "j", function()
        if state.mode == "picker" then
            move_picker_row(1)
            return
        end
        move_by_days(7)
    end, map_opts)

    vim.keymap.set("n", "k", function()
        if state.mode == "picker" then
            move_picker_row(-1)
            return
        end
        move_by_days(-7)
    end, map_opts)

    vim.keymap.set("n", "H", function() move_by_months(-1) end, map_opts)
    vim.keymap.set("n", "L", function() move_by_months(1) end, map_opts)
    vim.keymap.set("n", "J", function() move_by_years(-1) end, map_opts)
    vim.keymap.set("n", "K", function() move_by_years(1) end, map_opts)

    vim.keymap.set("n", "t", function()
        if state.mode == "picker" then
            local today = os.date("*t")
            state.cursor_date = {
                year = today.year,
                month = today.month,
                day = today.day,
            }
            state.view_date = {
                year = today.year,
                month = today.month,
                day = 1,
            }
            state.cursor_row = nil
            state.cursor_col = nil
            render(date_picker, state.bufnr, state)
            return
        end
        move_to_today()
    end, map_opts)

    vim.keymap.set("n", "<LeftMouse>", function()
        vim.cmd("normal! <LeftMouse>")
        sync_cursor_from_window()
    end, map_opts)

    vim.keymap.set("n", "<CR>", function()
        if state.mode == "picker" then
            -- The cursor row determines the journal kind. Cursor position inside
            -- the day grid selects daily notes; title/month/week rows select the
            -- broader journal families.
            local ok_row, pos = pcall(vim.api.nvim_win_get_cursor, state.winid)
            if not ok_row or type(pos) ~= "table" then
                return
            end

            local selected_kind = selection_kind_for_cursor(state, pos[1], pos[2])
            if not selected_kind then
                return
            end

            finish("selected", state.cursor_date, selected_kind)
            return
        end
        finish("closed", nil, nil)
    end, map_opts)

    vim.keymap.set("n", "q", function()
        finish("cancelled", nil, nil)
    end, map_opts)

    vim.keymap.set("n", "<Esc>", function()
        finish("cancelled", nil, nil)
    end, map_opts)

    -- If the user closes the buffer/window manually, finalize state without freezing the UI.
    -- This replaces the previous blocking wait loop with event-driven completion.
    if type(vim.api.nvim_create_autocmd) == "function" then
        vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
            buffer = state.bufnr,
            callback = function()
                if state.done then
                    return
                end

                if state.mode == "picker" then
                    state.result.action = "cancelled"
                else
                    state.result.action = "closed"
                end
                state.result.date = nil
                state.result.cursor_date = date_picker.normalize_date(state.cursor_date)
                state.result.selected_kind = nil
                state.done = true

                safe_on_finish(on_finish, {
                    ok = true,
                    action = state.result.action,
                    date = nil,
                    cursor_date = state.result.cursor_date,
                    selected_kind = nil,
                    error = nil,
                })
            end,
            once = true,
        })
    end

    return state.result
end

return M
