local container = require("nvim_obsidian.app.container")
local dependencies = require("nvim_obsidian.app.dependencies")

---Application bootstrap orchestrator.
---
---This module wires dependency verification, container construction, command
---registration, and deferred startup indexing into one setup entrypoint.
local M = {}

---Run initial vault reindex after setup.
---@param c table Runtime dependency container.
local function run_startup_reindex(c)
    local reindex = c.use_cases and c.use_cases.reindex_sync
    if type(reindex) ~= "table" or type(reindex.execute) ~= "function" then
        return
    end

    local ok, result = pcall(reindex.execute, c, { mode = "startup" })
    if not ok then
        local message = "nvim-obsidian: startup reindex failed: " .. tostring(result)
        if c.notifications and c.notifications.error then
            c.notifications.error(message)
        end
        return
    end

    if type(result) ~= "table" then
        local message = "nvim-obsidian: startup reindex returned invalid result"
        if c.notifications and c.notifications.error then
            c.notifications.error(message)
        end
        return
    end

    if not result.ok then
        local message = "startup reindex failed"
        if result.error and result.error.message then
            message = result.error.message
        end
        if c.notifications and c.notifications.error then
            c.notifications.error("nvim-obsidian: " .. message)
        end
        return
    end

    if c.notifications and c.notifications.info then
        c.notifications.info("nvim-obsidian: vault cache ready")
    end
end

---Schedule startup reindex on Neovim event loop when available.
---
---Setup should return quickly to avoid blocking user startup. Reindexing is
---therefore deferred unless scheduling is unavailable (tests/headless fallback).
---@param c table Runtime dependency container.
local function schedule_startup_reindex(c)
    if vim and type(vim.schedule) == "function" then
        vim.schedule(function()
            run_startup_reindex(c)
        end)
        return
    end

    run_startup_reindex(c)
end

---Start plugin runtime and return the fully wired container.
---@param opts? table User setup options.
---@return table container
function M.start(opts)
    dependencies.verify_required_dependencies()

    local c = container.build(opts)
    c.adapters.commands.register(c)

    -- Keep setup non-blocking: startup reindex runs after setup returns.
    schedule_startup_reindex(c)

    return c
end

return M
