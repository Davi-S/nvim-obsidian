local render = require("nvim-obsidian.dataview.render")

describe("dataview render", function()
    before_each(function()
        vim.api.nvim_set_hl(0, "Normal", { fg = 0xAABBCC })
        pcall(vim.api.nvim_set_hl, 0, "markdownLinkText", {})
        pcall(vim.api.nvim_set_hl, 0, "@lsp.type.class.markdown", {})
        pcall(vim.api.nvim_set_hl, 0, "@lsp.type.decorator.markdown", {})
    end)

    it("uses markdownLinkText color when available", function()
        vim.api.nvim_set_hl(0, "markdownLinkText", { fg = 0x112233 })

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "```dataview", "TASK", "```" })
        local block = { start_line = 1, end_line = 3 }
        local result = {
            groups = {
                {
                    key = "a",
                    rows = {
                        { raw = "- [ ] t", file = { name = "Note A" } },
                    },
                },
            },
        }

        render.render_block(buf, block, result, nil)

        local hl = vim.api.nvim_get_hl(0, { name = "NvimObsidianDataviewHeader", link = false })
        assert.are.equal(0x112233, hl.fg)
    end)

    it("falls back to Normal text color when markdown link color is unavailable", function()
        vim.api.nvim_set_hl(0, "Normal", { fg = 0x445566 })
        pcall(vim.api.nvim_set_hl, 0, "markdownLinkText", {})

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "```dataview", "TASK", "```" })
        local block = { start_line = 1, end_line = 3 }
        local result = {
            groups = {
                {
                    key = "a",
                    rows = {
                        { raw = "- [ ] t", file = { name = "Note A" } },
                    },
                },
            },
        }

        render.render_block(buf, block, result, nil)

        local hl = vim.api.nvim_get_hl(0, { name = "NvimObsidianDataviewHeader", link = false })
        assert.are.equal(0x445566, hl.fg)
    end)
end)
