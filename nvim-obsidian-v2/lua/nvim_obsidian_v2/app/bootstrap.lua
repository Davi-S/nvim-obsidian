local container = require("nvim_obsidian_v2.app.container")

local M = {}

function M.start(opts)
    local c = container.build(opts)
    c.adapters.commands.register(c)
    return c
end

return M
