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

-- Build user-facing keymap guidance shown in the buffer footer.
--
-- We keep this in one function so future keymap changes only touch one place.
local function build_help_line(mode)
    if mode == "picker" then
        return "Keys: h/j/k/l move | H/L month | J/K year | t today | <CR> select | q close"
    end
    return "Keys: h/j/k/l move | H/L month | J/K year | t today | <CR> close | q close"
end

local function month_label(date)
    return string.format("%s %04d", MONTH_NAMES[date.month] or "Month", date.year)
end

-- Convert domain date table into Neovim cursor row/col for the day grid.
--
-- Grid starts at line 4 (1-based), and each day cell has width 3 in "DD " format.
local function day_to_cursor(matrix, target_token, left_pad)
    for week_index, week in ipairs(matrix.weeks or {}) do
        for day_index, cell in ipairs(week) do
            if cell.token == target_token then
                local line = 3 + week_index
                local col = (day_index - 1) * 3
                if type(left_pad) == "number" and left_pad > 0 then
                    col = col + left_pad
                end
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
    table.insert(lines, build_help_line(state.mode))

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

    -- Title line.
    local top = type(state.top_pad) == "number" and state.top_pad or 0
    local left = type(state.left_pad) == "number" and state.left_pad or 0
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.title, 0 + top, 0 + left, -1)

    -- Weekday header line.
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.weekday, 2 + top, 0 + left, -1)

    -- Day cells lines (4..9 in 1-based display, 3..8 in 0-based buffer lines).
    for week_idx, week in ipairs(matrix.weeks or {}) do
        local line0 = 2 + week_idx + top
        for day_idx, cell in ipairs(week) do
            local col_start = (day_idx - 1) * 3 + left
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

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

    -- If this buffer is shown in a floating window, compute padding to center
    -- the rendered calendar inside the float. We add top empty lines and
    -- left-space padding and adjust highlight/column math accordingly.
    local out_lines = payload.lines
    local computed_top = 0
    local computed_left = 0
    if type(state.win_width) == "number" and type(state.win_height) == "number" then
        local max_len = 0
        for _, l in ipairs(payload.lines) do
            if #l > max_len then
                max_len = #l
            end
        end
        computed_left = math.max(0, math.floor((state.win_width - max_len) / 2))
        computed_top = math.max(0, math.floor((state.win_height - #payload.lines) / 2))
        state.left_pad = computed_left
        state.top_pad = computed_top

        local padded = {}
        for i = 1, computed_top do
            table.insert(padded, "")
        end
        local pad_str = string.rep(" ", computed_left)
        for _, l in ipairs(payload.lines) do
            table.insert(padded, pad_str .. l)
        end
        out_lines = padded
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out_lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local line, col
    if state.mode == "picker" and type(state.cursor_row) == "number" and type(state.cursor_col) == "number" then
        line = state.cursor_row
        col = state.cursor_col
    else
        local token = date_picker.to_token(state.cursor_date)
        line, col = day_to_cursor(payload.matrix, token, state.left_pad)
        if type(line) == "number" then
            line = line + (state.top_pad or 0)
        end
    end

    pcall(vim.api.nvim_win_set_cursor, state.winid, { line, col })

    state.line_to_tokens = payload.line_to_tokens

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
    local left_pad = type(state.left_pad) == "number" and state.left_pad or 0
    if col - left_pad < 0 then
        return nil
    end
    local tokens = line and state.line_to_tokens[line] or nil
    if type(tokens) ~= "table" then
        return nil
    end

    local day_index = math.floor((col - left_pad) / 3) + 1
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
    if type(row) ~= "number" or type(col) ~= "number" then
        return nil
    end
    local tokens = state.line_to_tokens[row]
    if type(tokens) ~= "table" then
        return nil
    end

    local left_pad = type(state.left_pad) == "number" and state.left_pad or 0
    local effective = (tonumber(col) or 0) - left_pad
    if effective < 0 then
        return nil
    end
    local day_index = math.floor(effective / 3) + 1
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
local function selection_kind_for_row(row)
    local line = tonumber(row)
    if not line then
        return nil
    end

    if line == 1 then
        return nil
    end

    if line == 2 then
        return "monthly"
    end

    if line == 3 then
        return "weekly"
    end

    if line >= 4 and line <= 9 then
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

    if line == 2 then
        local month_name = MONTH_NAMES[(state.view_date or {}).month] or "Month"
        local year_start_col = #month_name + 1
        if column >= year_start_col then
            return "yearly"
        end
        return "monthly"
    end

    return selection_kind_for_row(line)
end

local function is_picker_header_row(row)
    return row == 1 or row == 2 or row == 3
end

-- Title row (line 1) is informational only and should never receive picker focus.
-- Normalize row movement so all interactive navigation starts from line 2.
local function normalize_picker_row(row)
    local line = tonumber(row)
    if not line then
        return 2
    end
    return clamp(line, 2, 9)
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

    -- Detect floating window dimensions so we can center rendered content
    -- inside floating windows. Defaults remain zero for non-floating windows.
    state.left_pad = 0
    state.top_pad = 0
    do
        local ok_cfg, cfg = pcall(vim.api.nvim_win_get_config, state.winid)
        if ok_cfg and type(cfg) == "table" and cfg.relative and cfg.relative == "editor" then
            local ok_w, w = pcall(vim.api.nvim_win_get_width, state.winid)
            local ok_h, h = pcall(vim.api.nvim_win_get_height, state.winid)
            if ok_w and ok_h and type(w) == "number" and type(h) == "number" then
                state.win_width = w
                state.win_height = h
            end
        end
    end

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
        state.cursor_row = normalize_picker_row((state.cursor_row or 4) + delta)

        if is_picker_header_row(state.cursor_row) then
            state.cursor_col = 0
        else
            state.cursor_col = clamp(state.cursor_col or 0, 0, 18)
        end

        refresh_picker_from_cursor()
    end

    local function move_picker_col(delta)
        if not state.cursor_row or state.cursor_row < 2 then
            return
        end

        if state.cursor_row == 2 then
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
        state.cursor_row = normalize_picker_row(new_row)
        state.cursor_col = tonumber(pos[2]) or state.cursor_col

        if state.cursor_row and state.cursor_row >= 4 then
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
    -- NOTE: UI keybindings removed from in-buffer calendar to keep visual
    -- surface minimal. Keybinding documentation is preserved in the project
    -- docs. Consumers may bind keys externally if desired.
    -- However, when the calendar is opened inside a floating window we want
    -- to restore minimal in-buffer keybindings (close/select) so the UX for
    -- floating pickers matches prior behavior (q to close, <CR> to select).
    if request and request.floating and type(vim.keymap) == "table" and type(vim.keymap.set) == "function" then
        pcall(vim.keymap.set, "n", "q", function()
            if state.done then
                return
            end
            if state.mode == "picker" then
                finish("cancelled", nil, nil)
            else
                finish("closed", nil, nil)
            end
        end, { buffer = state.bufnr, silent = true })

        pcall(vim.keymap.set, "n", "<CR>", function()
            if state.done then
                return
            end

            if state.mode == "picker" then
                -- Determine selected_kind from cursor and map to date if possible.
                local kind = selection_kind_for_cursor(state, state.cursor_row or 0, state.cursor_col or 0)
                local selected_date = nil
                if state.cursor_row and state.cursor_row >= 4 then
                    local token = token_from_position(state, state.cursor_row, state.cursor_col or 0)
                    if token then
                        selected_date = parse_token(token)
                    end
                end
                if not selected_date then
                    selected_date = state.cursor_date
                end
                finish("selected", selected_date, kind)
                return
            end

            -- Visualizer mode: Enter closes the view.
            finish("closed", nil, nil)
        end, { buffer = state.bufnr, silent = true })
    end

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
