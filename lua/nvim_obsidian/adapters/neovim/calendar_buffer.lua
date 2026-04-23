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

-- Render labels in Monday-first order to match date-picker domain matrix.
local WEEKDAY_LABELS = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }

local function is_nvim_ready()
    return vim
        and type(vim) == "table"
        and type(vim.api) == "table"
        and type(vim.keymap) == "table"
        and type(vim.keymap.set) == "function"
        and type(vim.wait) == "function"
end

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
local function build_lines(date_picker, state)
    local matrix = date_picker.month_matrix(state.view_date)
    local lines = {}

    table.insert(lines, build_title_line(state.mode))
    table.insert(lines, month_label(state.view_date))
    table.insert(lines, table.concat(WEEKDAY_LABELS, " "))

    local line_to_tokens = {}

    for week_index, week in ipairs(matrix.weeks or {}) do
        local day_chunks = {}
        local tokens = {}

        for _, cell in ipairs(week) do
            -- In-month days use normal 2-digit format; out-of-month days keep the same shape
            -- with surrounding dots to make calendar boundaries obvious in plain text UI.
            if cell.in_view_month then
                table.insert(day_chunks, string.format("%02d", cell.date.day))
            else
                table.insert(day_chunks, string.format(".%02d", cell.date.day):sub(1, 2))
            end
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

local function ensure_buffer_opts(bufnr)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
end

local function render(date_picker, bufnr, state)
    local payload = build_lines(date_picker, state)

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, payload.lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    local token = date_picker.to_token(state.cursor_date)
    local line, col = day_to_cursor(payload.matrix, token)
    pcall(vim.api.nvim_win_set_cursor, state.winid, { line, col })

    state.line_to_tokens = payload.line_to_tokens
end

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

local function close_window(winid)
    if type(winid) == "number" and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_close, winid, true)
    end
end

function M.open_calendar(ctx, request)
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
    local now = os.date("*t")
    local start_date = date_picker.normalize_date(request and request.initial_date or now)

    -- Interactive state is centralized in one table so every mapping callback
    -- mutates one source of truth and re-renders from it.
    local state = {
        mode = mode,
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
            action = "closed",
            date = nil,
            cursor_date = nil,
            error = nil,
        },
        winid = nil,
        bufnr = nil,
        line_to_tokens = {},
    }

    -- Open a dedicated normal window/buffer. This intentionally favors simplicity and
    -- debuggability for MVP over advanced layout control.
    vim.cmd("botright new")
    state.winid = vim.api.nvim_get_current_win()
    state.bufnr = vim.api.nvim_get_current_buf()

    ensure_buffer_opts(state.bufnr)
    render(date_picker, state.bufnr, state)

    local function refresh_after_cursor_shift(new_cursor)
        state.cursor_date = date_picker.normalize_date(new_cursor)
        state.view_date = {
            year = state.cursor_date.year,
            month = state.cursor_date.month,
            day = 1,
        }
        render(date_picker, state.bufnr, state)
    end

    local function finish(action, selected_date)
        state.result.action = action
        state.result.date = selected_date and date_picker.normalize_date(selected_date) or nil
        state.result.cursor_date = date_picker.normalize_date(state.cursor_date)
        state.done = true
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

    -- Wait loop keeps this API synchronous for callers while still allowing Neovim
    -- to process key input and redraw events.
    vim.wait(24 * 60 * 60 * 1000, function()
        -- If user closed the window manually, treat as closed in visualizer mode and
        -- cancelled in picker mode (because no explicit date selection happened).
        if not state.done and (not state.winid or not vim.api.nvim_win_is_valid(state.winid)) then
            if state.mode == "picker" then
                state.result.action = "cancelled"
            else
                state.result.action = "closed"
            end
            state.result.cursor_date = date_picker.normalize_date(state.cursor_date)
            state.done = true
            return true
        end
        return state.done
    end, 20)

    close_window(state.winid)

    return state.result
end

return M
