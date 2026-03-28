local bootstrap = require("nvim_obsidian.app.bootstrap")

local M = {}

function M.setup(opts)
    return bootstrap.start(opts or {})
end

return M
