---@diagnostic disable: undefined-global

local errors = require("nvim_obsidian.core.shared.errors")
local calendar_buffer = require("nvim_obsidian.adapters.neovim.calendar_buffer")

---Neovim floating-calendar adapter.
---
---Opens a centered floating window and delegates interaction/render behavior to
---the existing buffer calendar adapter to preserve picker parity.
local M = {}

local function is_nvim_ready()
    return vim
        and type(vim) == "table"
        and type(vim.api) == "table"
        and type(vim.api.nvim_open_win) == "function"
        and type(vim.api.nvim_create_buf) == "function"
        and type(vim.api.nvim_get_current_win) == "function"
        and type(vim.api.nvim_set_current_win) == "function"
end

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

    local origin_win = vim.api.nvim_get_current_win()
    local editor_width = tonumber(vim.o.columns) or 120
    local editor_height = tonumber(vim.o.lines) or 40

    local floating_cfg = normalize_floating_config(
        ctx.config and ctx.config.calendar and ctx.config.calendar.floating
    )

    local width = math.max(40, math.min(editor_width - 4, math.floor(floating_cfg.width)))
    local height = math.max(12, math.min(editor_height - 4, math.floor(floating_cfg.height)))
    local row = math.max(1, math.floor((editor_height - height) / 2) - 1)
    local col = math.max(0, math.floor((editor_width - width) / 2))

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

    local original_on_finish = request and request.on_finish or nil

    local wrapped_request = {}
    if type(request) == "table" then
        for key, value in pairs(request) do
            wrapped_request[key] = value
        end
    end

    wrapped_request.layout = "current"
    wrapped_request.close_on_finish = true
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
