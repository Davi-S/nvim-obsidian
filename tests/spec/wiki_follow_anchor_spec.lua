local config = require("nvim-obsidian.config")
local vault = require("nvim-obsidian.model.vault")
local scanner = require("nvim-obsidian.cache.scanner")
local wiki = require("nvim-obsidian.link.wiki")

describe("wiki follow anchors", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(root .. "/10 Novas notas", "p")

        local cfg = config.resolve({
            vault_root = root,
            locale = "pt-BR",
            new_notes_subdir = "10 Novas notas",
        })
        config.set(cfg)
        vault.reset()
    end)

    after_each(function()
        vault.reset()
        vim.fn.delete(root, "rf")
    end)

    it("follows heading and block wikilinks", function()
        local target = root .. "/10 Novas notas/2026 abril 21, terça-feira.md"
        vim.fn.writefile({
            "# Nota",
            "",
            "## Objetivos",
            "texto",
            "item ^d34ac8",
        }, target)

        local linker = root .. "/10 Novas notas/Linker.md"
        vim.fn.writefile({
            "[[2026 abril 21, terça-feira#Objetivos]]",
            "[[2026 abril 21, terça-feira#^d34ac8|T]]",
        }, linker)

        scanner.refresh_all_sync()

        vim.cmd("edit " .. vim.fn.fnameescape(linker))
        vim.api.nvim_win_set_cursor(0, { 1, 5 })
        wiki.follow()
        assert.are.equal(target, vim.api.nvim_buf_get_name(0))
        assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])

        vim.cmd("edit " .. vim.fn.fnameescape(linker))
        vim.api.nvim_win_set_cursor(0, { 2, 5 })
        wiki.follow()
        assert.are.equal(target, vim.api.nvim_buf_get_name(0))
        assert.are.equal(5, vim.api.nvim_win_get_cursor(0)[1])
    end)
end)
