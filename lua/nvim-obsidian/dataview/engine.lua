local block_parser = require("nvim-obsidian.dataview.block_parser")
local task_source = require("nvim-obsidian.dataview.task_source")
local executor = require("nvim-obsidian.dataview.executor")
local render = require("nvim-obsidian.dataview.render")
local vault = require("nvim-obsidian.model.vault")
local config = require("nvim-obsidian.config")

local M = {}

function M.refresh_open_markdown_buffers()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= "" and name:sub(-3) == ".md" then
                M.refresh_buffer(bufnr)
            end
        end
    end
end

function M.refresh_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local cfg = config.get()
    if not cfg then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local blocks = block_parser.find_blocks(lines)

    render.clear_buffer(bufnr)

    if #blocks == 0 then
        return
    end

    local notes = vault.all_notes()

    for _, block in ipairs(blocks) do
        local query, parse_err = block_parser.parse_query(block.body_lines)
        if not query then
            render.render_block(bufnr, block, nil, { "dataview: " .. parse_err })
        else
            local tasks, source_errors = task_source.collect(notes, cfg, query.from)
            local result, exec_errors = executor.execute(query, tasks)

            local all_errors = {}
            for _, e in ipairs(source_errors or {}) do
                table.insert(all_errors, e)
            end
            for _, e in ipairs(exec_errors or {}) do
                table.insert(all_errors, e)
            end

            if #all_errors > 0 then
                render.render_block(bufnr, block, result, all_errors)
            else
                render.render_block(bufnr, block, result, nil)
            end
        end
    end
end

function M.setup_autocmds()
    local group = vim.api.nvim_create_augroup("NvimObsidianDataview", { clear = true })

    vim.api.nvim_create_autocmd({ "BufRead", "BufWritePost" }, {
        group = group,
        pattern = "*.md",
        callback = function(args)
            M.refresh_buffer(args.buf)
        end,
    })
end

return M
