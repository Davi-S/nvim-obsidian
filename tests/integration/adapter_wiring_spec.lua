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

        -- Use-case bridge ports should be available at top-level context.
        assert(type(container.navigation.open_path) == "function")
        assert(type(container.fs_io.read_file) == "function")
        assert(type(container.frontmatter.parse) == "function")
        assert(type(container.watcher.start) == "function")
    end)

    it("registers command adapter during setup", function()
        require("nvim_obsidian").setup({})
        local commands = vim.api.nvim_get_commands({ builtin = false })

        assert(commands.ObsidianHealth ~= nil, "ObsidianHealth should be registered")
    end)

    it("navigation adapter open_path is no longer phase2 skeleton", function()
        local ok, err = require("nvim_obsidian.adapters.neovim.navigation").open_path(
        "/tmp/nvim_obsidian_adapter_wiring_test.md")
        assert(type(ok) == "boolean")
        assert(err ~= "phase2-skeleton-not-implemented")
    end)
end)
