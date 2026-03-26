local backlinks = require("nvim-obsidian.backlinks")

describe("backlinks regex patterns", function()
    it("escapes PCRE metacharacters in note titles", function()
        local title = "Algoritmos e Estruturas de Dados 2 (CI1056)"
        local p1, p2, p3 = backlinks._patterns_for_title_for_tests(title)

        assert.are.equal("\\[\\[Algoritmos e Estruturas de Dados 2 \\(CI1056\\)\\]\\]", p1)
        assert.are.equal("\\[\\[Algoritmos e Estruturas de Dados 2 \\(CI1056\\)\\|", p2)
        assert.are.equal("\\[\\[Algoritmos e Estruturas de Dados 2 \\(CI1056\\)#", p3)
    end)

    it("escapes all common regex metacharacters", function()
        local title = "a.b[c]{d}(e)^$|?*+-"
        local p1, p2, p3 = backlinks._patterns_for_title_for_tests(title)

        assert.are.equal("\\[\\[a\\.b\\[c\\]\\{d\\}\\(e\\)\\^\\$\\|\\?\\*\\+\\-\\]\\]", p1)
        assert.are.equal("\\[\\[a\\.b\\[c\\]\\{d\\}\\(e\\)\\^\\$\\|\\?\\*\\+\\-\\|", p2)
        assert.are.equal("\\[\\[a\\.b\\[c\\]\\{d\\}\\(e\\)\\^\\$\\|\\?\\*\\+\\-#", p3)
    end)
end)
