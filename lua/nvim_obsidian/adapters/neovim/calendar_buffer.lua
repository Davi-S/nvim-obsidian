---@diagnostic disable: undefined-global

local errors = require("nvim_obsidian.core.shared.errors")

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
    local matrix = payload.matrix

    -- Title line.
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.title, 0, 0, -1)

    -- Weekday header line.
    vim.api.nvim_buf_add_highlight(bufnr, ns, highlights.weekday, 2, 0, -1)

    -- Day cells lines (4..9 in 1-based display, 3..8 in 0-based buffer lines).
    for week_idx, week in ipairs(matrix.weeks or {}) do
        local line0 = 2 + week_idx
        for day_idx, cell in ipairs(week) do
            local col_start = (day_idx - 1) * 3
            local col_end = col_start + 2

            local group = highlights.in_month_day
            if not cell.in_view_month then
                group = highlights.outside_month_day
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
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, payload.lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local token = date_picker.to_token(state.cursor_date)
    local line, col = day_to_cursor(payload.matrix, token)
    pcall(vim.api.nvim_win_set_cursor, state.winid, { line, col })

    state.line_to_tokens = payload.line_to_tokens
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
    local week_start = resolve_week_start(request and request.week_start)
    local highlights = resolve_highlights(request and request.highlights)
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
        week_start = week_start,
        highlights = highlights,
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
            error = nil,
        },
        winid = nil,
        bufnr = nil,
        line_to_tokens = {},
        namespace = nil,
    }

    -- Open a dedicated normal window/buffer. This intentionally favors simplicity and
    -- debuggability for MVP over advanced layout control.
    vim.cmd("botright new")
    state.winid = vim.api.nvim_get_current_win()
    state.bufnr = vim.api.nvim_get_current_buf()

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

    local function finish(action, selected_date)
        if state.done then
            return
        end

        -- Finish is idempotent: once done=true all later finish attempts are ignored.
        -- This protects against double-trigger scenarios from keymaps + autocmds.
        state.result.action = action
        state.result.date = selected_date and date_picker.normalize_date(selected_date) or nil
        state.result.cursor_date = date_picker.normalize_date(state.cursor_date)
        state.done = true

        safe_on_finish(on_finish, {
            ok = true,
            action = state.result.action,
            date = state.result.date,
            cursor_date = state.result.cursor_date,
            error = nil,
        })

        close_window(state.winid)
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
        -- 2) map to token
        -- 3) parse token into date
        -- 4) redraw consistent month/cursor state
        local token = token_from_cursor(date_picker, state)
        if not token then
            return
        end

        local parsed = parse_token(token)
        if not parsed then
            return
        end

        state.cursor_date = date_picker.normalize_date(parsed)
        -- Keep the visible month aligned with the selected day when mouse navigation
        -- crosses month boundaries.
        state.view_date = {
            year = state.cursor_date.year,
            month = state.cursor_date.month,
            day = 1,
        }
        render(date_picker, state.bufnr, state)
    end

    -- Buffer-local mappings keep calendar controls isolated from user global maps.
    local map_opts = { buffer = state.bufnr, silent = true, nowait = true }

    vim.keymap.set("n", "h", function() move_by_days(-1) end, map_opts)
    vim.keymap.set("n", "l", function() move_by_days(1) end, map_opts)
    vim.keymap.set("n", "j", function() move_by_days(7) end, map_opts)
    vim.keymap.set("n", "k", function() move_by_days(-7) end, map_opts)

    vim.keymap.set("n", "H", function() move_by_months(-1) end, map_opts)
    vim.keymap.set("n", "L", function() move_by_months(1) end, map_opts)
    vim.keymap.set("n", "J", function() move_by_years(-1) end, map_opts)
    vim.keymap.set("n", "K", function() move_by_years(1) end, map_opts)

    vim.keymap.set("n", "t", function() move_to_today() end, map_opts)

    vim.keymap.set("n", "<LeftMouse>", function()
        vim.cmd("normal! <LeftMouse>")
        sync_cursor_from_window()
    end, map_opts)

    vim.keymap.set("n", "<CR>", function()
        if state.mode == "picker" then
            finish("selected", state.cursor_date)
            return
        end
        finish("closed", nil)
    end, map_opts)

    vim.keymap.set("n", "q", function()
        finish("cancelled", nil)
    end, map_opts)

    vim.keymap.set("n", "<Esc>", function()
        finish("cancelled", nil)
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
                state.done = true

                safe_on_finish(on_finish, {
                    ok = true,
                    action = state.result.action,
                    date = nil,
                    cursor_date = state.result.cursor_date,
                    error = nil,
                })
            end,
            once = true,
        })
    end

    return state.result
end

return M
