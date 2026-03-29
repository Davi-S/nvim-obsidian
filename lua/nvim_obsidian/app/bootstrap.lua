local container = require("nvim_obsidian.app.container")
local dependencies = require("nvim_obsidian.app.dependencies")

local M = {}

function M.start(opts)
    dependencies.verify_required_dependencies()

    local c = container.build(opts)
    c.adapters.commands.register(c)

    local reindex = c.use_cases and c.use_cases.reindex_sync
    if type(reindex) == "table" and type(reindex.execute) == "function" then
        local result = reindex.execute(c, { mode = "startup" })
        if not result.ok then
            local message = "startup reindex failed"
            if result.error and result.error.message then
                message = result.error.message
            end
            if c.notifications and c.notifications.error then
                c.notifications.error("nvim-obsidian: " .. message)
            end
            error("nvim-obsidian setup: " .. message, 2)
        end

        if c.notifications and c.notifications.info then
            c.notifications.info("nvim-obsidian: vault cache ready")
        end
    end

    return c
end

return M
