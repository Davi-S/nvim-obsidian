---@diagnostic disable: undefined-global

local errors = require("nvim_obsidian.core.shared.errors")
local calendar_buffer = require("nvim_obsidian.adapters.neovim.calendar_buffer")

---Neovim floating-calendar adapter.
---
---Opens a centered floating window and delegates interaction/render behavior to
---the existing buffer calendar adapter to preserve picker parity.
local M = {}

-- Check that Neovim runtime APIs we rely on are available.
-- Defensive: some test runners or minimal environments mock/omit parts of
-- `vim`, so bail gracefully when required APIs are missing.
local function is_nvim_ready()
    return vim
        and type(vim) == "table"
        and type(vim.api) == "table"
        and type(vim.api.nvim_open_win) == "function"
        and type(vim.api.nvim_create_buf) == "function"
        and type(vim.api.nvim_get_current_win) == "function"
        and type(vim.api.nvim_set_current_win) == "function"
end

-- Normalize user-provided floating configuration. Ensure sensible
-- defaults and coerce types so callers can rely on numeric width/height
-- and a non-empty border string.
local function normalize_floating_config(value)
    local cfg = type(value) == "table" and value or {}
    local border = tostring(cfg.border or "rounded")
    if border == "" then
        border = "rounded"
    end
    return {
        width = tonumber(cfg.width) or 90,
        height = tonumber(cfg.height) or 24,
        border = border,
    }
end

---Open calendar in floating modal window.
---@param ctx table
---@param request table
---@return table
function M.open_calendar(ctx, request)
    if not is_nvim_ready() then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INTERNAL, "Neovim floating APIs are unavailable"),
        }
    end

    if type(ctx) ~= "table" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end

    -- Remember the window that invoked the calendar so we can restore
    -- focus when the float is closed.
    local origin_win = vim.api.nvim_get_current_win()

    -- Editor dimensions in character cells. `vim.o.columns`/`vim.o.lines`
    -- are used to clamp the requested float size and compute centering.
    local editor_width = tonumber(vim.o.columns) or 120
    local editor_height = tonumber(vim.o.lines) or 40

    local floating_cfg = normalize_floating_config(
        ctx.config and ctx.config.calendar and ctx.config.calendar.floating
    )

    -- Clamp to sensible minimums and ensure the float fits inside the editor
    -- area (leave a small margin).
    local width = math.max(40, math.min(editor_width - 4, math.floor(floating_cfg.width)))
    local height = math.max(12, math.min(editor_height - 4, math.floor(floating_cfg.height)))
    local row = math.max(0, math.floor((editor_height - height) / 2))
    local col = math.max(0, math.floor((editor_width - width) / 2))

    -- Create a scratch buffer for the floating window. Use pcall to guard
    -- against unexpected API failures in constrained/test environments.
    local ok_buf, seed_buf = pcall(vim.api.nvim_create_buf, false, true)
    if not ok_buf or type(seed_buf) ~= "number" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to create floating calendar buffer"),
        }
    end

    -- Open the floating window relative to the editor. If successful
    -- `float_win` will be a valid window id that we can later close.
    local ok_win, float_win = pcall(vim.api.nvim_open_win, seed_buf, true, {
        relative = "editor",
        anchor = "NW",
        width = width,
        height = height,
        row = row,
        col = col,
        border = floating_cfg.border,
        style = "minimal",
    })

    if not ok_win or type(float_win) ~= "number" then
        return {
            ok = false,
            action = nil,
            date = nil,
            cursor_date = nil,
            selected_kind = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to open floating calendar window"),
        }
    end

    -- Preserve any caller-provided `on_finish` so we can invoke it after
    -- closing/restoring windows.
    local original_on_finish = request and request.on_finish or nil

    -- Build a wrapped request for the buffer-based calendar adapter. We
    -- force `layout = "current"` so the buffer adapter renders in the
    -- provided window, and set `center_content` + `window_size` so the
    -- buffer can center its contents inside this float.
    local wrapped_request = {}
    if type(request) == "table" then
        for key, value in pairs(request) do
            wrapped_request[key] = value
        end
    end

    wrapped_request.layout = "current"
    wrapped_request.close_on_finish = true
    wrapped_request.center_content = true
    wrapped_request.window_size = {
        width = width,
        height = height,
    }

    -- Ensure the floating window is closed and focus restored when the
    -- buffer adapter signals completion, then call any original finish
    -- callback provided by the caller.
    wrapped_request.on_finish = function(payload)
        if type(vim.api.nvim_win_is_valid) == "function" and vim.api.nvim_win_is_valid(float_win) then
            pcall(vim.api.nvim_win_close, float_win, true)
        end
        if type(vim.api.nvim_win_is_valid) == "function" and vim.api.nvim_win_is_valid(origin_win) then
            pcall(vim.api.nvim_set_current_win, origin_win)
        end
        if type(original_on_finish) == "function" then
            pcall(original_on_finish, payload)
        end
    end

    return calendar_buffer.open_calendar(ctx, wrapped_request)
end

return M