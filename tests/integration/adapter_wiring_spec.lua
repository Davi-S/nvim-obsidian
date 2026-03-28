---@diagnostic disable: undefined-global

describe("adapter wiring", function()
    it("builds a container with domains, use-cases, and adapters", function()
        local container = require("nvim_obsidian.app.container").build({})

        assert(type(container) == "table")
        assert(type(container.domains) == "table")
        assert(type(container.use_cases) == "table")
        assert(type(container.adapters) == "table")

        assert(type(container.adapters.commands.register) == "function")
        assert(type(container.adapters.notifications.info) == "function")
        assert(type(container.adapters.navigation.open_path) == "function")
    end)

    it("registers command adapter during setup", function()
        require("nvim_obsidian").setup({})
        local commands = vim.api.nvim_get_commands({ builtin = false })

        assert(commands.ObsidianHealth ~= nil, "ObsidianHealth should be registered")
    end)
end)
