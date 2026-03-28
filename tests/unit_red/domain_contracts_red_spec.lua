---@diagnostic disable: undefined-global

describe("domain implementation red suite", function()
    it("requires vault catalog implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.vault_catalog.impl")
        assert(ok, "RED: missing vault_catalog implementation module")
    end)

    it("requires journal implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.journal.impl")
        assert(ok, "RED: missing journal implementation module")
    end)

    it("requires wiki link implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.wiki_link.impl")
        assert(ok, "RED: missing wiki_link implementation module")
    end)

    it("requires template implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.template.impl")
        assert(ok, "RED: missing template implementation module")
    end)

    it("requires dataview implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.dataview.impl")
        assert(ok, "RED: missing dataview implementation module")
    end)

    it("requires search ranking implementation module", function()
        local ok = pcall(require, "nvim_obsidian.core.domains.search_ranking.impl")
        assert(ok, "RED: missing search_ranking implementation module")
    end)
end)
