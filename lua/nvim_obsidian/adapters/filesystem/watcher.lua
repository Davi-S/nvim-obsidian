local M = {}
local active = nil

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

local function event_kind(events)
    if type(events) ~= "table" then
        return "modify"
    end
    if events.rename then
        return "rename"
    end
    return "modify"
end

function M.start(ctx)
    ctx = ctx or {}
    local cfg = ctx.config or {}
    local root = cfg.vault_root or cfg.vault_dir or cfg.root or cfg.vault_path
    if type(root) ~= "string" or root == "" then
        return false, "watch-root-required"
    end

    local loop = get_loop()
    if type(loop) ~= "table" or type(loop.new_fs_event) ~= "function" then
        return false, "fs-event-unavailable"
    end

    if active then
        M.stop()
    end

    local handle = loop.new_fs_event()
    if not handle then
        return false, "failed-to-create-fs-event"
    end

    local on_event = ctx.on_fs_event or ctx.handle_fs_event

    local ok, start_err = handle:start(root, { recursive = true }, function(err, filename, events)
        if err then
            return
        end
        if type(on_event) ~= "function" then
            return
        end

        local ev = {
            kind = event_kind(events),
            path = join_path(root, filename),
            raw = events,
        }

        pcall(on_event, ev)
    end)

    if not ok then
        if type(handle.close) == "function" then
            pcall(handle.close, handle)
        end
        return false, tostring(start_err or "failed-to-start-watcher")
    end

    active = {
        handle = handle,
        root = root,
    }

    return true, nil
end

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
