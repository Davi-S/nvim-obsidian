local M = {}

local REQUIRED_DEPENDENCIES = {
    {
        module = "telescope",
        name = "nvim-telescope/telescope.nvim",
    },
    {
        module = "cmp",
        name = "hrsh7th/nvim-cmp",
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

function M.verify_required_dependencies()
    for _, dep in ipairs(REQUIRED_DEPENDENCIES) do
        local ok = pcall(require, dep.module)
        if not ok then
            error("nvim-obsidian requires dependency: " .. dep.name, 2)
        end
    end
end

return M
