local bootstrap = require("nvim_obsidian_v2.app.bootstrap")

local M = {}

function M.setup(opts)
    return bootstrap.start(opts or {})
end

return M
