--- Buffer and window navigation adapter for Neovim
--- Provides a thin layer over vim.api for buffer/window operations
--- All functions handle missing APIs gracefully with sensible defaults
--- This adapter enables safe, defensive navigation without throwing errors

local M = {}

--- Create a buffer/window navigator with vim.api bindings
--- @param ctx table|nil Context with vim.api reference
--- @return table Navigator object with buffer, window, cursor, and split operations
function M.create_navigator(ctx)
    ctx = ctx or {}

    local navigator = {
        display_name = "buffer_window_navigator",
        _ctx = ctx,
    }

    -- Helper to safely call vim.api functions
    -- Wraps calls in pcall to prevent errors from propagating
    -- Returns nil if the function doesn't exist or fails
    local function safe_call(fn, ...)
        if not fn then return nil end
        local ok, result = pcall(fn, ...)
        if ok then return result end
        return nil
    end

    -- Helper to get vim.api reference
    -- Returns nil if vim or vim.api doesn't exist in context
    local function get_api()
        return ctx.vim and ctx.vim.api
    end

    -- Helper to get vim.fn reference
    -- Returns nil if vim or vim.fn doesn't exist in context
    local function get_fn()
        return ctx.vim and ctx.vim.fn
    end

    --- Get current buffer ID
    --- @return number|nil Current buffer ID or nil if error
    function navigator.get_current_buffer()
        local api = get_api()
        if not api or not api.nvim_get_current_buf then
            return nil
        end
        return safe_call(api.nvim_get_current_buf)
    end

    --- Get current window ID
    --- @return number|nil Current window ID or nil if error
    function navigator.get_current_window()
        local api = get_api()
        if not api or not api.nvim_get_current_win then
            return nil
        end
        return safe_call(api.nvim_get_current_win)
    end

    --- Open a file in a buffer
    --- Uses vim command for cross-platform path handling
    --- Returns nil if path is invalid or vim.api is unavailable
    --- @param filepath string|nil Path to file to open
    --- @return number|nil Buffer ID or nil if error
    function navigator.open_file(filepath)
        if not filepath then return nil end

        local api = get_api()
        if not api or not api.nvim_command then return nil end

        return safe_call(function()
            -- Use vim command to open file
            api.nvim_command("edit " .. vim.fn.fnameescape(filepath))
            return navigator.get_current_buffer()
        end)
    end

    --- Get buffer name (file path)
    --- @param buf_id number Buffer ID
    --- @return string|nil Buffer path or nil if error
    function navigator.get_buffer_name(buf_id)
        if not buf_id then return nil end

        local api = get_api()
        if not api or not api.nvim_buf_get_name then return nil end

        return safe_call(api.nvim_buf_get_name, buf_id)
    end

    --- Get lines from buffer
    --- Returns empty table on any error (API missing, invalid buffer, etc)
    --- This defensive approach prevents nil errors when reading buffer content
    --- @param buf_id number Buffer ID
    --- @param start_line number|nil Starting line (0-indexed), defaults to 0
    --- @param end_line number|nil Ending line (0-indexed), defaults to -1 (all)
    --- @return table|nil Array of lines or nil if error
    function navigator.get_buffer_lines(buf_id, start_line, end_line)
        if not buf_id then return nil end

        local api = get_api()
        if not api or not api.nvim_buf_get_lines then return nil end

        start_line = start_line or 0
        end_line = end_line or -1

        return safe_call(api.nvim_buf_get_lines, buf_id, start_line, end_line, false) or {}
    end

    --- Set text in buffer
    --- @param buf_id number Buffer ID
    --- @param row number Row (0-indexed)
    --- @param col number Column (0-indexed)
    --- @param text string Text to insert
    function navigator.set_buffer_text(buf_id, row, col, text)
        if not buf_id or not text then return end

        local api = get_api()
        if not api or not api.nvim_buf_set_lines then return end

        safe_call(function()
            api.nvim_buf_set_lines(buf_id, row, row + 1, false, { text })
        end)
    end

    --- List all buffers
    --- @return table Array of buffer IDs
    function navigator.list_buffers()
        local fn = get_fn()
        if not fn or not fn.buflisted then return {} end

        local buffers = {}
        for i = 1, vim.fn.bufnr("$") do
            if safe_call(fn.buflisted, i) then
                table.insert(buffers, i)
            end
        end
        return buffers
    end

    --- Get cursor position
    --- @return table|nil Position table {line, col} or nil if error
    function navigator.get_cursor_position()
        local api = get_api()
        if not api or not api.nvim_win_get_cursor then return nil end

        local win = navigator.get_current_window()
        if not win then return nil end

        local pos = safe_call(api.nvim_win_get_cursor, win)
        if pos and #pos >= 2 then
            return {
                line = pos[1],
                col = pos[2],
            }
        end
        return nil
    end

    --- Set cursor position
    --- @param line number|nil Line number (1-indexed), defaults to 1
    --- @param col number|nil Column number (0-indexed), defaults to 0
    function navigator.set_cursor_position(line, col)
        line = line or 1
        col = col or 0

        local api = get_api()
        if not api or not api.nvim_win_set_cursor then return end

        local win = navigator.get_current_window()
        if not win then return end

        safe_call(api.nvim_win_set_cursor, win, { line, col })
    end

    --- Center cursor on screen
    function navigator.center_cursor_on_screen()
        local api = get_api()
        if not api or not api.nvim_command then return end

        safe_call(function()
            api.nvim_command("normal! zz")
        end)
    end

    --- Navigate to line in buffer
    --- @param buf_id number Buffer ID
    --- @param line_num number Line number (1-indexed)
    function navigator.navigate_to_line(buf_id, line_num)
        if not buf_id or not line_num then return end

        navigator.jump_to_buffer(buf_id)
        navigator.set_cursor_position(line_num, 0)
    end

    --- Navigate to position in buffer
    --- @param buf_id number Buffer ID
    --- @param line_num number Line number (1-indexed)
    --- @param col_num number Column number (0-indexed)
    function navigator.navigate_to_position(buf_id, line_num, col_num)
        if not buf_id or not line_num then return end

        col_num = col_num or 0
        navigator.jump_to_buffer(buf_id)
        navigator.set_cursor_position(line_num, col_num)
    end

    --- Jump to a specific buffer
    --- @param buf_id number|nil Buffer ID
    function navigator.jump_to_buffer(buf_id)
        if not buf_id then return end

        local api = get_api()
        if not api or not api.nvim_set_current_buf then return end

        safe_call(api.nvim_set_current_buf, buf_id)
    end

    --- Switch to window that shows buffer
    --- @param buf_id number Buffer ID
    function navigator.switch_to_buffer_window(buf_id)
        if not buf_id then return end

        local fn = get_fn()
        if not fn or not fn.bufwinnr then return end

        local win = safe_call(fn.bufwinnr, buf_id)
        if win and win > 0 then
            local api = get_api()
            if api and api.nvim_set_current_win then
                safe_call(api.nvim_set_current_win, win)
            end
        end
    end

    --- Get buffer for window
    --- @param win_id number Window ID
    --- @return number|nil Buffer ID or nil if error/invalid window
    function navigator.get_window_buffer(win_id)
        if not win_id then return nil end

        local api = get_api()
        if not api or not api.nvim_win_get_buf then return nil end

        return safe_call(api.nvim_win_get_buf, win_id)
    end

    --- Close current window
    function navigator.close_window()
        local api = get_api()
        if not api or not api.nvim_win_close then return end

        local win = navigator.get_current_window()
        if not win then return end

        safe_call(api.nvim_win_close, win, false)
    end

    --- Open a split window
    --- @param direction string "horizontal" or "vertical"
    --- @param size number|nil Size of split (height for horizontal, width for vertical)
    --- @return number|nil Window ID of new split or nil if error
    function navigator.open_split(direction, size)
        local api = get_api()
        if not api or not api.nvim_open_win then return nil end

        direction = direction or "horizontal"
        size = size or 0

        return safe_call(function()
            local buf = api.nvim_create_buf(false, true)

            local config = {
                relative = "editor",
                width = 80,
                height = 20,
                col = 0,
                row = 0,
            }

            if direction == "vertical" then
                config.width = size > 0 and size or 40
            else
                config.height = size > 0 and size or 10
            end

            return api.nvim_open_win(buf, true, config)
        end)
    end

    return navigator
end

return M
