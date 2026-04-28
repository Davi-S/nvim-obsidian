---Filesystem watcher adapter.
---
---Wraps libuv fs_event watching and emits normalized event payloads to the
---container callback (`on_fs_event` / `handle_fs_event`).
local M = {}
local active = nil
local errors = require("nvim_obsidian.core.shared.errors")

local function adapter_error(code, message, meta)
    return errors.new(code, message, meta)
end

local function get_loop()
    if not vim then return nil end
    return vim.loop or vim.uv
end

local function join_path(root, filename)
    if type(filename) ~= "string" or filename == "" then
        return root
    end
    if filename:sub(1, 1) == "/" then
        return filename
    end
    if root:sub(-1) == "/" then
        return root .. filename
    end
    return root .. "/" .. filename
end

local function path_exists(path, loop)
    if type(path) ~= "string" or path == "" then
        return false
    end

    local uv = loop
    if type(uv) == "table" and type(uv.fs_stat) == "function" then
        local ok, stat = pcall(uv.fs_stat, path)
        if ok then
            return stat ~= nil
        end
    end

    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end

    return false
end

local function event_kind(events, path, loop)
    if type(events) ~= "table" then
        return path_exists(path, loop) and "modify" or "delete"
    end

    if events.rename then
        return path_exists(path, loop) and "create" or "delete"
    end

    if events.change then
        return path_exists(path, loop) and "modify" or "delete"
    end

    return "modify"
end

---Start watching configured vault root.
---@param ctx table
---@return boolean
---@return table|nil
function M.start(ctx)
    ctx = ctx or {}
    local cfg = ctx.config or {}
    local root = cfg.vault_root or cfg.vault_dir or cfg.root or cfg.vault_path
    if type(root) ~= "string" or root == "" then
        return false, adapter_error(errors.codes.INVALID_INPUT, "watch root is required")
    end

    local loop = get_loop()
    if type(loop) ~= "table" or type(loop.new_fs_event) ~= "function" then
        return false, adapter_error(errors.codes.INTERNAL, "filesystem event loop is unavailable")
    end

    if active then
        M.stop()
    end

    local handle = loop.new_fs_event()
    if not handle then
        return false, adapter_error(errors.codes.INTERNAL, "failed to create filesystem watcher handle")
    end

    local on_event = ctx.on_fs_event or ctx.handle_fs_event

    local function start_handle(options)
        return handle:start(root, options, function(err, filename, events)
            if err then
                return
            end
            if type(on_event) ~= "function" then
                return
            end

            if type(filename) ~= "string" or filename == "" then
                pcall(on_event, {
                    kind = "rescan",
                    path = root,
                    raw = events,
                })
                return
            end

            local event_path = join_path(root, filename)
            local ev = {
                kind = event_kind(events, event_path, loop),
                path = event_path,
                raw = events,
            }

            pcall(on_event, ev)
        end)
    end

    local ok, start_err = start_handle({ recursive = true })
    if not ok then
        ok, start_err = start_handle({ recursive = false })
    end

    if not ok then
        if type(handle.close) == "function" then
            pcall(handle.close, handle)
        end
        return false, adapter_error(errors.codes.INTERNAL, "failed to start filesystem watcher", {
            reason = tostring(start_err or "failed-to-start-watcher"),
        })
    end

    active = {
        handle = handle,
        root = root,
    }

    return true, nil
end

---Stop active watcher and release resources.
---@return boolean
function M.stop()
    if not active then
        return true
    end

    local handle = active.handle
    if handle and type(handle.stop) == "function" then
        pcall(handle.stop, handle)
    end
    if handle and type(handle.close) == "function" then
        pcall(handle.close, handle)
    end

    active = nil
    return true
end

return M
