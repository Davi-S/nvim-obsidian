local M = {}

local NS = vim.api.nvim_create_namespace("nvim-obsidian-dataview")

local function ensure_highlights()
    vim.api.nvim_set_hl(0, "NvimObsidianDataviewHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "NvimObsidianDataviewError", { link = "WarningMsg", default = true })
end

local function fmt_date(ts)
    if not ts then
        return "(sem data)"
    end
    return os.date("%Y-%m-%d", ts)
end

function M.clear_buffer(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
end

function M.render_block(bufnr, block, result, errors)
    ensure_highlights()

    local virt = {}

    if errors and #errors > 0 then
        for _, err in ipairs(errors) do
            table.insert(virt, { { err, "NvimObsidianDataviewError" } })
        end
    elseif not result or not result.groups then
        table.insert(virt, { { "dataview: no results", "NvimObsidianDataviewHeader" } })
    else
        for _, grp in ipairs(result.groups) do
            local header = string.format("%s (%d)", fmt_date(grp.group_key.date), #grp.rows)
            table.insert(virt, { { header, "NvimObsidianDataviewHeader" } })
            table.insert(virt, { { "", "Normal" } })
            for _, row in ipairs(grp.rows) do
                table.insert(virt, { { row.raw, "Normal" } })
            end
            table.insert(virt, { { "", "Normal" } })
        end
    end

    vim.api.nvim_buf_set_extmark(bufnr, NS, block.start_line - 1, 0, {
        virt_lines = virt,
        virt_lines_above = false,
        end_line = block.end_line,
        hl_mode = "combine",
    })
end

return M
