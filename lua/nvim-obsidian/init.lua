local config_mod = require("nvim-obsidian.config")
local scanner = require("nvim-obsidian.cache.scanner")
local commands = require("nvim-obsidian.commands")

local M = {
    _did_setup = false,
}

local function ensure_hard_dependencies()
    local deps = {
        { module = "telescope",               label = "nvim-telescope/telescope.nvim" },
        { module = "cmp",                     label = "hrsh7th/nvim-cmp" },
        { module = "nvim-treesitter.parsers", label = "nvim-treesitter/nvim-treesitter" },
        { module = "plenary.job",             label = "nvim-lua/plenary.nvim" },
    }

    for _, dep in ipairs(deps) do
        local ok = pcall(require, dep.module)
        if not ok then
            error("nvim-obsidian requires dependency: " .. dep.label)
        end
    end
end

local function setup_cmp_source()
    local cmp = require("cmp")
    cmp.register_source("nvim_obsidian", require("nvim-obsidian.cmp.source").new())
end

function M.setup(opts)
    if M._did_setup then
        return
    end

    ensure_hard_dependencies()
    local cfg = config_mod.resolve(opts or {})
    config_mod.set(cfg)

    commands.register()
    setup_cmp_source()

    scanner.refresh_all_async(function()
        scanner.setup_autocmds()
        vim.notify("nvim-obsidian: vault cache ready", vim.log.levels.INFO)
    end)

    M._did_setup = true
end

return M
