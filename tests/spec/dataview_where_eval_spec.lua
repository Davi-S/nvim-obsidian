local where_eval = require("nvim-obsidian.dataview.where_eval")

describe("dataview where evaluator", function()
    it("evaluates checked predicate and date comparisons", function()
        local row = {
            checked = false,
            file = { link = { date = os.time({ year = 2026, month = 3, day = 26, hour = 12 }) } },
        }

        local ok, err = where_eval.match("!checked AND file.link.date > date(2026-03-25)", row)
        assert.is_nil(err)
        assert.is_true(ok)
    end)

    it("supports checked marker as any char upstream", function()
        local row = {
            checked = true,
            file = { link = { date = os.time({ year = 2026, month = 3, day = 26, hour = 12 }) } },
        }

        local ok, err = where_eval.match("checked", row)
        assert.is_nil(err)
        assert.is_true(ok)
    end)
end)
