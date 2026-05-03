---@diagnostic disable: undefined-global

---Neovim notifications adapter.
---
---Maps plugin events to `vim.notify` with configurable severity filtering and
---consistent message formatting.
-- Neovim notifications adapter.
--
-- Responsibilities and design notes:
-- - Provide a small adapter that surfaces plugin events as Neovim
--   notifications via `vim.notify` (or a substituted `vim` table supplied in
--   `ctx.vim` for testing).
-- - Support configurable log-level filtering so callers can emit noisy debug
--  /info events without overwhelming users when `config.log_level` is set to
--   a higher severity.
-- - Ensure message formatting is consistent (title, target, next step) and
--   return boolean success indicators so callers can decide whether to fall
--   back to alternate presentation channels.
--
local M = {}

local severity_order = {
    error = 1,
    warn = 2,
    info = 3,
}

-- `severity_order` is a numeric ordering used to decide whether an event
-- should be emitted given a configured minimum level. Lower numbers are
-- higher-severity.

---@param s any
---@return string|nil
local function trim(s)
    if type(s) ~= "string" then return nil end
    local stripped = s:match("^%s*(.-)%s*$")
    if stripped == "" then return nil end
    return stripped
end

-- Trim helper that returns `nil` for empty or non-string input. This simplifies
-- message construction by allowing presence checks with simple `if` tests.

---@param level any
---@return string
local function normalize_level(level)
    local key = tostring(level or "warn"):lower()
    if severity_order[key] then
        return key
    end
    return "warn"
end

-- Normalize arbitrary inputs into the adapter's allowed severity keys.

---@param ctx table|nil
---@return table|nil
local function resolve_vim(ctx)
    if type(ctx) == "table" and type(ctx.vim) == "table" then
        return ctx.vim
    end
    return vim
end

-- Allow tests to inject a fake `vim` implementation via `ctx.vim` so the
-- adapter can be exercised without depending on the real Neovim runtime.

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

-- Map the textual severity to Neovim's `vim.log.levels` constants when
-- available. Returns `nil` when the log API is not present; callers then
-- fall back to calling `vim.notify` with a no-op level in a safe `pcall`.

---@param configured_level any
---@param event_level any
---@return boolean
local function should_emit(configured_level, event_level)
    local configured = severity_order[normalize_level(configured_level)] or severity_order.warn
    local event = severity_order[normalize_level(event_level)] or severity_order.warn
    return event <= configured
end

-- Decide whether an event at `event_level` should be shown given
-- `configured_level` (both can be any value; they are normalized first).

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

-- Format a structured payload into a compact, human-readable single-line
-- message. Supported fields: `message`/`msg`, `command`, `target`, and
-- `next_step`. Unknown payload shapes are ignored so callers can evolve
-- payload contents without breaking the notifier.

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

        -- Build a single-line message from the payload. If formatting yields
        -- nothing (e.g., empty message) we silently drop the event and return
        -- false so callers can optionally fall back to other presenters.
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

        -- `vim.notify` may be unavailable or may raise; pcall protects the
        -- caller and returns a boolean success flag.
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
