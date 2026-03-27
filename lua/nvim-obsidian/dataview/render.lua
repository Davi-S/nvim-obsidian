local M = {}

local NS = vim.api.nvim_create_namespace("nvim-obsidian-dataview")

local function dv_opts(cfg)
    local defaults = {
        placement = "below_block",
        messages = {
            task_no_results = {
                enabled = true,
                text = "Dataview: No results to show for task query.",
            },
        },
        highlights = {
            error = "WarningMsg",
        },
    }
    return vim.tbl_deep_extend("force", defaults, cfg or {})
end

local function hl_fg(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if not ok or not hl then
        return nil
    end
    return hl.fg
end

local function ensure_highlights(cfg)
    local opts = dv_opts(cfg)
    local user_hl = opts.highlights or {}

    local header_hl = user_hl.header
    if header_hl and vim.fn.hlexists(header_hl) == 1 then
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewHeader", { link = header_hl, default = false })
    else
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
    end

    local table_link_hl = user_hl.table_link
    if table_link_hl and vim.fn.hlexists(table_link_hl) == 1 then
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewTableLink", { link = table_link_hl, default = false })
    else
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewTableLink", { link = "NvimObsidianDataviewHeader", default = false })
    end

    local no_results_hl = user_hl.task_no_results
    if no_results_hl and vim.fn.hlexists(no_results_hl) == 1 then
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewTaskNoResults", { link = no_results_hl, default = false })
    else
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewTaskNoResults", { link = "NvimObsidianDataviewHeader", default = false })
    end

    local error_hl = user_hl.error or "WarningMsg"
    if vim.fn.hlexists(error_hl) == 1 then
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewError", { link = error_hl, default = false })
    else
        vim.api.nvim_set_hl(0, "NvimObsidianDataviewError", { link = "WarningMsg", default = false })
    end
end

function M.clear_buffer(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
end

local function pad_right(s, width)
    local text = tostring(s or "")
    local missing = width - vim.fn.strdisplaywidth(text)
    if missing <= 0 then
        return text
    end
    return text .. string.rep(" ", missing)
end

local function pad_left(s, width)
    local text = tostring(s or "")
    local missing = width - vim.fn.strdisplaywidth(text)
    if missing <= 0 then
        return text
    end
    return string.rep(" ", missing) .. text
end

local function build_table_lines(columns, rows, link_cols)
    local widths = {}
    local numeric_cols = {}
    for i, col in ipairs(columns) do
        widths[i] = vim.fn.strdisplaywidth(tostring(col))
        numeric_cols[i] = true
    end

    for _, row in ipairs(rows) do
        for i = 1, #columns do
            local cell = row[i] or ""
            local text = tostring(cell)
            local n = vim.fn.strdisplaywidth(text)
            if n > (widths[i] or 0) then
                widths[i] = n
            end
            if tonumber(text) == nil then
                numeric_cols[i] = false
            end
        end
    end

    local lines = {}

    local header_line = {}
    for i, col in ipairs(columns) do
        header_line[#header_line + 1] = { pad_right(col, widths[i]), "Normal" }
        if i < #columns then
            header_line[#header_line + 1] = { "  ", "Normal" }
        end
    end
    lines[#lines + 1] = header_line

    local total_width = 0
    for i, w in ipairs(widths) do
        total_width = total_width + w
        if i < #widths then
            total_width = total_width + 2
        end
    end
    lines[#lines + 1] = { { string.rep("-", total_width), "Normal" } }

    for _, row in ipairs(rows) do
        local row_line = {}
        for i = 1, #columns do
            local text = tostring(row[i] or "")
            local padded
            if numeric_cols[i] then
                padded = pad_left(text, widths[i])
            else
                padded = pad_right(text, widths[i])
            end

            local hl = (link_cols and link_cols[i]) and "NvimObsidianDataviewTableLink" or "Normal"
            row_line[#row_line + 1] = { padded, hl }
            if i < #columns then
                row_line[#row_line + 1] = { "  ", "Normal" }
            end
        end
        lines[#lines + 1] = row_line
    end

    return lines
end

function M.render_block(bufnr, block, result, errors, cfg)
    local opts = dv_opts(cfg)
    ensure_highlights(opts)

    local virt = {}

    if errors and #errors > 0 then
        for _, err in ipairs(errors) do
            table.insert(virt, { { err, "NvimObsidianDataviewError" } })
        end
    elseif result and result.kind == "TABLE" and result.table then
        local lines = build_table_lines(result.table.columns or {}, result.table.rows or {}, result.table.link_cols)
        if #lines == 0 then
            table.insert(virt, { { "dataview: no results", "NvimObsidianDataviewHeader" } })
        else
            for _, line in ipairs(lines) do
                table.insert(virt, line)
            end
            table.insert(virt, { { "", "Normal" } })
        end
    elseif result and result.groups and #result.groups == 0 then
        if opts.messages.task_no_results.enabled then
            table.insert(virt, { { opts.messages.task_no_results.text, "NvimObsidianDataviewTaskNoResults" } })
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

    local place_above = opts.placement == "above_block"
    local anchor_line = place_above and math.max(block.start_line - 1, 0) or (block.end_line - 1)

    vim.api.nvim_buf_set_extmark(bufnr, NS, anchor_line, 0, {
        virt_lines = virt,
        virt_lines_above = place_above,
        hl_mode = "combine",
    })
end

return M
