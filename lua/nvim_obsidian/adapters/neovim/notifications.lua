---@diagnostic disable: undefined-global

---Neovim notifications adapter.
---
---Maps plugin events to `vim.notify` with configurable severity filtering and
---consistent message formatting.
local M = {}

local severity_order = {
    error = 1,
    warn = 2,
    info = 3,
}

---@param s any
---@return string|nil
local function trim(s)
    if type(s) ~= "string" then return nil end
    local stripped = s:match("^%s*(.-)%s*$")
    if stripped == "" then return nil end
    return stripped
end

---@param level any
---@return string
local function normalize_level(level)
    local key = tostring(level or "warn"):lower()
    if severity_order[key] then
        return key
    end
    return "warn"
end

---@param ctx table|nil
---@return table|nil
local function resolve_vim(ctx)
    if type(ctx) == "table" and type(ctx.vim) == "table" then
        return ctx.vim
    end
    return vim
end

---@param vim_ref table|nil
---@param level any
---@return integer|nil
local function resolve_log_constant(vim_ref, level)
    local key = normalize_level(level)
    if not vim_ref or type(vim_ref.log) ~= "table" or type(vim_ref.log.levels) ~= "table" then
        return nil
    end

    if key == "error" then
        return vim_ref.log.levels.ERROR
    elseif key == "warn" then
        return vim_ref.log.levels.WARN
    end

    return vim_ref.log.levels.INFO
end

---@param configured_level any
---@param event_level any
---@return boolean
local function should_emit(configured_level, event_level)
    local configured = severity_order[normalize_level(configured_level)] or severity_order.warn
    local event = severity_order[normalize_level(event_level)] or severity_order.warn
    return event <= configured
end

---@param payload any
---@return string|nil
local function format_message(payload)
    if type(payload) == "string" then
        return trim(payload)
    end

    if type(payload) ~= "table" then
        return nil
    end

    local message = trim(payload.message or payload.msg)
    if not message then
        return nil
    end

    local parts = {}
    local command = trim(payload.command)
    if command then
        table.insert(parts, "[" .. command .. "] " .. message)
    else
        table.insert(parts, message)
    end

    local target = trim(payload.target)
    if target then
        table.insert(parts, "target: " .. target)
    end

    local next_step = trim(payload.next_step)
    if next_step then
        table.insert(parts, "next: " .. next_step)
    end

    return table.concat(parts, " | ")
end

---Create severity-aware notifier bound to setup config.
---@param ctx table|nil { vim?: table, config?: table, title?: string }
---@return table
function M.create_notifier(ctx)
    ctx = ctx or {}
    local config = type(ctx.config) == "table" and ctx.config or {}
    local plugin_title = trim(ctx.title) or "nvim-obsidian"

    local notifier = {
        display_name = "neovim_notifications",
        _ctx = ctx,
    }

    ---Emit a notification.
    ---@param payload string|table
    ---@param level string
    ---@return boolean
    function notifier.notify(payload, level)
        local event_level = normalize_level(level)
        if not should_emit(config.log_level, event_level) then
            return false
        end

        local msg = format_message(payload)
        if not msg then
            return false
        end

        local vim_ref = resolve_vim(ctx)
        if type(vim_ref) ~= "table" or type(vim_ref.notify) ~= "function" then
            return false
        end

        local opts = {
            title = plugin_title,
        }
        local log_level = resolve_log_constant(vim_ref, event_level)

        local ok = pcall(vim_ref.notify, msg, log_level, opts)
        return ok
    end

    function notifier.info(payload)
        return notifier.notify(payload, "info")
    end

    function notifier.warn(payload)
        return notifier.notify(payload, "warn")
    end

    function notifier.error(payload)
        return notifier.notify(payload, "error")
    end

    return notifier
end

local function default_notifier()
    return M.create_notifier({
        vim = vim,
        config = { log_level = "info" },
    })
end

---Send info-level notification using default notifier.
---@param payload any
function M.info(payload)
    return default_notifier().info(payload)
end

---Send warning-level notification using default notifier.
---@param payload any
function M.warn(payload)
    return default_notifier().warn(payload)
end

---Send error-level notification using default notifier.
---@param payload any
function M.error(payload)
    return default_notifier().error(payload)
end

return M
