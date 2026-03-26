local markdown = require("nvim-obsidian.parser.markdown")

describe("markdown structure parser", function()
    it("extracts headings with line numbers", function()
        local text = table.concat({
            "# Título",
            "",
            "## Objetivos",
            "### Próximos objetivos",
        }, "\n")

        local hs = markdown.extract_headings(text)
        assert.are.equal(3, #hs)
        assert.are.equal("Título", hs[1].text)
        assert.are.equal(1, hs[1].line)
        assert.are.equal("Objetivos", hs[2].text)
        assert.are.equal(3, hs[2].line)
    end)

    it("extracts block IDs", function()
        local text = table.concat({
            "- [ ] tarefa",
            "texto ^d34ac8",
            "outro ^abc-12",
        }, "\n")

        local blocks = markdown.extract_blocks(text)
        assert.are.equal(2, #blocks)
        assert.are.equal("d34ac8", blocks[1].id)
        assert.are.equal(2, blocks[1].line)
    end)
end)
