local M = {}

local NS = vim.api.nvim_create_namespace("nvim-obsidian-dataview")

local function hl_fg(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if not ok or not hl then
        return nil
    end
    return hl.fg
end

local function ensure_highlights()
    local sapphire_fg = hl_fg("markdownLinkText")
    if not sapphire_fg then
        sapphire_fg = hl_fg("@lsp.type.class.markdown")
    end
    if not sapphire_fg then
        sapphire_fg = hl_fg("@lsp.type.decorator.markdown")
    end

    if sapphire_fg then
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewHeader", { fg = sapphire_fg, default = false })
    else
        local text_fg = hl_fg("Normal")
        if text_fg then
            vim.api.nvim_set_hl(0, "NvimObsidianDataviewHeader", { fg = text_fg, default = false })
        else
            vim.api.nvim_set_hl(0, "NvimObsidianDataviewHeader", { link = "Normal", default = false })
        end
    end
    vim.api.nvim_set_hl(0, "NvimObsidianDataviewError", { link = "WarningMsg", default = true })
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
            -- Get the file name from the first task in the group
            local file_name = (grp.rows[1] and grp.rows[1].file and grp.rows[1].file.name) or grp.key or "Unknown"
            local header = file_name
            table.insert(virt, { { header, "NvimObsidianDataviewHeader" } })
            table.insert(virt, { { "", "Normal" } })
            for _, row in ipairs(grp.rows) do
                table.insert(virt, { { row.raw, "Normal" } })
            end
            table.insert(virt, { { "", "Normal" } })
        end
    end

    vim.api.nvim_buf_set_extmark(bufnr, NS, block.end_line - 1, 0, {
        virt_lines = virt,
        virt_lines_above = false,
        hl_mode = "combine",
    })
end

return M
