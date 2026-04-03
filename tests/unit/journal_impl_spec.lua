---@diagnostic disable: undefined-global

local journal = require("nvim_obsidian.core.domains.journal.impl")

describe("journal domain implementation", function()
    it("classifies canonical date-like inputs", function()
        assert.are.equal("daily", journal.classify_input("2026-03-28").kind)
        assert.are.equal("weekly", journal.classify_input("2026-W13").kind)
        assert.are.equal("weekly", journal.classify_input("2026 week 13").kind)
        assert.are.equal("weekly", journal.classify_input("2026 semana 13").kind)
        assert.are.equal("monthly", journal.classify_input("2026-03").kind)
        assert.are.equal("yearly", journal.classify_input("2026").kind)
    end)

    it("classifies natural-language day and month inputs", function()
        assert.are.equal("daily", journal.classify_input("today").kind)
        assert.are.equal("daily", journal.classify_input("+1d").kind)
        assert.are.equal("daily", journal.classify_input("segunda-feira").kind)
        assert.are.equal("daily", journal.classify_input("2026 abril 06, segunda-feira").kind)
        assert.are.equal("daily", journal.classify_input("2026 março 29, domingo").kind)
        assert.are.equal("monthly", journal.classify_input("march 2026").kind)
        assert.are.equal("monthly", journal.classify_input("2026 março").kind)
        assert.are.equal("none", journal.classify_input("project alpha").kind)
    end)

    it("builds canonical titles for each journal kind", function()
        local date = { year = 2026, month = 3, day = 28 }

        assert.are.equal("2026-03-28", journal.build_title("daily", date, "en-US").title)
        assert.are.equal("2026-W13", journal.build_title("weekly", date, "en-US").title)
        assert.are.equal("2026-03", journal.build_title("monthly", date, "en-US").title)
        assert.are.equal("2026", journal.build_title("yearly", date, "en-US").title)
    end)

    it("computes adjacent dates with normalized anchors", function()
        local date = { year = 2026, month = 3, day = 28 }

        local daily_next = journal.compute_adjacent("daily", date, "next").target_date
        assert.are.same({ year = 2026, month = 3, day = 29 }, daily_next)

        local weekly_current = journal.compute_adjacent("weekly", date, "current").target_date
        assert.are.same({ year = 2026, month = 3, day = 23 }, weekly_current)

        local monthly_prev = journal.compute_adjacent("monthly", date, "prev").target_date
        assert.are.same({ year = 2026, month = 2, day = 1 }, monthly_prev)

        local yearly_next = journal.compute_adjacent("yearly", date, "next").target_date
        assert.are.same({ year = 2027, month = 1, day = 1 }, yearly_next)
    end)
end)
