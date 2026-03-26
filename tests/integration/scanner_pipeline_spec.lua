local scanner = require("nvim-obsidian.cache.scanner")
local vault = require("nvim-obsidian.model.vault")
local config = require("nvim-obsidian.config")

describe("integration scanner pipeline", function()
    local root

    local function write_file(filepath, lines)
        local parent = vim.fn.fnamemodify(filepath, ":h")
        vim.fn.mkdir(parent, "p")
        vim.fn.writefile(lines, filepath)
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")

        write_file(root .. "/10 Novas notas/Standard Note.md", {
            "---",
            "aliases: [Std Alias]",
            "tags: [std]",
            "---",
            "# Standard",
        })

        write_file(root .. "/11 Diario/11.01 Diario/2026 março 21, sabado.md", {
            "---",
            "aliases: [Daily Alias]",
            "tags: [daily]",
            "---",
            "# Daily",
        })

        config.set({
            vault_root = root,
            notes_dir_abs = root .. "/10 Novas notas",
            journal_enabled = true,
            journal = {
                daily = { dir_abs = root .. "/11 Diario/11.01 Diario" },
                weekly = { dir_abs = root .. "/11 Diario/11.02 Semanal" },
                monthly = { dir_abs = root .. "/11 Diario/11.03 Mensal" },
                yearly = { dir_abs = root .. "/11 Diario/11.04 Anual" },
            },
        })

        vault.reset()
    end)

    after_each(function()
        vault.reset()
        vim.fn.delete(root, "rf")
    end)

    it("indexes markdown files with parsed metadata and note types", function()
        scanner.refresh_all_sync()

        local all = vault.all_notes()
        assert.are.equal(2, #all)

        local standard_matches = vault.resolve_by_title_or_alias("Standard Note", { vault_root = root })
        assert.are.equal(1, #standard_matches)
        assert.are.equal("standard", standard_matches[1].note_type)
        assert.are.same({ "Std Alias" }, standard_matches[1].aliases)

        local daily_matches = vault.resolve_by_title_or_alias("Daily Alias", { vault_root = root })
        assert.are.equal(1, #daily_matches)
        assert.are.equal("daily", daily_matches[1].note_type)
        assert.are.same({ "daily" }, daily_matches[1].tags)
    end)
end)
