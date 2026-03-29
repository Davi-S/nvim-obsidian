local container = require("nvim_obsidian.app.container")
local dependencies = require("nvim_obsidian.app.dependencies")

local M = {}

local function run_startup_reindex(c)
    local reindex = c.use_cases and c.use_cases.reindex_sync
    if type(reindex) ~= "table" or type(reindex.execute) ~= "function" then
        return
    end

    local ok, result = pcall(reindex.execute, c, { mode = "startup" })
    if not ok then
        if c.notifications and c.notifications.error then
            c.notifications.error("nvim-obsidian: startup reindex failed")
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

local function schedule_startup_reindex(c)
    if vim and type(vim.schedule) == "function" then
        vim.schedule(function()
            run_startup_reindex(c)
        end)
        return
    end

    run_startup_reindex(c)
end

function M.start(opts)
    dependencies.verify_required_dependencies()

    local c = container.build(opts)
    c.adapters.commands.register(c)

    -- Keep setup non-blocking: startup reindex runs after setup returns.
    schedule_startup_reindex(c)

    return c
end

return M
