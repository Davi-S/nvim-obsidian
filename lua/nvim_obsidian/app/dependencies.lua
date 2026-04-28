---Dependency verification for required runtime plugins.
---
---The plugin assumes these integrations exist at startup because adapters and
---use-cases depend on them directly. Fail fast to keep setup errors explicit.
local M = {}

local REQUIRED_DEPENDENCIES = {
    {
        module = "telescope",
        name = "nvim-telescope/telescope.nvim",
    },
    {
        module = "blink.cmp",
        name = "saghen/blink.cmp",
    },
    {
        module = "nvim-treesitter.parsers",
        name = "nvim-treesitter/nvim-treesitter",
    },
    {
        module = "plenary.job",
        name = "nvim-lua/plenary.nvim",
    },
}

---Verify required runtime plugin dependencies are loadable.
function M.verify_required_dependencies()
    for _, dep in ipairs(REQUIRED_DEPENDENCIES) do
        local ok = pcall(require, dep.module)
        if not ok then
            error("nvim-obsidian requires dependency: " .. dep.name, 2)
        end
    end
end

return M
