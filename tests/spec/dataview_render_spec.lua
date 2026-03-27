local render = require("nvim-obsidian.dataview.render")

describe("dataview render", function()
    before_each(function()
        vim.api.nvim_set_hl(0, "Normal", { fg = 0xAABBCC })
    end)

    it("defaults dataview highlights to Normal", function()
        vim.api.nvim_set_hl(0, "Normal", { fg = 0x445566 })
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

    it("uses configured highlight overrides when provided", function()
        vim.api.nvim_set_hl(0, "MyDvHeader", { fg = 0x112233 })

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

        render.render_block(buf, block, result, nil, {
            highlights = {
                header = "MyDvHeader",
            },
        })

        local hl = vim.api.nvim_get_hl(0, { name = "NvimObsidianDataviewHeader", link = false })
        assert.are.equal(0x112233, hl.fg)
    end)

    it("supports above_block placement", function()
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

        render.render_block(buf, block, result, nil, {
            placement = "above_block",
        })

        local ns = vim.api.nvim_create_namespace("nvim-obsidian-dataview")
        local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
        assert.is_true(#marks >= 1)
        assert.are.equal(0, marks[1][2])
        assert.is_true(marks[1][4].virt_lines_above)
    end)

    it("can disable task no-results message", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "```dataview", "TASK", "```" })
        local block = { start_line = 1, end_line = 3 }
        local result = { groups = {} }

        render.render_block(buf, block, result, nil, {
            messages = {
                task_no_results = {
                    enabled = false,
                    text = "ignored",
                },
            },
        })

        local ns = vim.api.nvim_create_namespace("nvim-obsidian-dataview")
        local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
        assert.is_true(#marks >= 1)
        local virt = marks[1][4].virt_lines or {}
        assert.are.equal(0, #virt)
    end)
end)
