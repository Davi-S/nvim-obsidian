local block_parser = require("nvim-obsidian.dataview.block_parser")
local task_source = require("nvim-obsidian.dataview.task_source")
local table_source = require("nvim-obsidian.dataview.table_source")
local executor = require("nvim-obsidian.dataview.executor")
local render = require("nvim-obsidian.dataview.render")
local vault = require("nvim-obsidian.model.vault")
local config = require("nvim-obsidian.config")

local M = {}

local WHEN_TO_EVENTS = {
    on_open = "BufReadPost",
    on_save = "BufWritePost",
    on_buf_enter = "BufEnter",
}

local function markdown_loaded_buffers()
    local out = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= "" and name:sub(-3) == ".md" then
                table.insert(out, bufnr)
            end
        end
    end
    return out
end

local function visible_markdown_buffers()
    local out = {}
    local seen = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        if not seen[bufnr] then
            seen[bufnr] = true
            if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
                local name = vim.api.nvim_buf_get_name(bufnr)
                if name ~= "" and name:sub(-3) == ".md" then
                    table.insert(out, bufnr)
                end
            end
        end
    end
    return out
end

local function target_buffers_for_scope(scope, event_buf)
    if scope == "current" then
        return { vim.api.nvim_get_current_buf() }
    end
    if scope == "visible" then
        return visible_markdown_buffers()
    end
    if scope == "loaded" then
        return markdown_loaded_buffers()
    end
    return { event_buf }
end

function M.refresh_open_markdown_buffers()
    for _, bufnr in ipairs(markdown_loaded_buffers()) do
        M.refresh_buffer(bufnr)
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

    if cfg.dataview and cfg.dataview.enabled == false then
        render.clear_buffer(bufnr)
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
            render.render_block(bufnr, block, nil, { "dataview: " .. parse_err }, cfg.dataview)
        else
            local rows, source_errors
            if query.kind == "TABLE" then
                rows, source_errors = table_source.collect(notes, query)
            else
                rows, source_errors = task_source.collect(notes, cfg, query.from)
            end

            local result, exec_errors = executor.execute(query, rows)

            local all_errors = {}
            for _, e in ipairs(source_errors or {}) do
                table.insert(all_errors, e)
            end
            for _, e in ipairs(exec_errors or {}) do
                table.insert(all_errors, e)
            end

            if #all_errors > 0 then
                render.render_block(bufnr, block, result, all_errors, cfg.dataview)
            else
                render.render_block(bufnr, block, result, nil, cfg.dataview)
            end
        end
    end
end

function M.setup_autocmds()
    local group = vim.api.nvim_create_augroup("NvimObsidianDataview", { clear = true })

    local cfg = config.get() or {}
    local dv = cfg.dataview or {}
    local render_cfg = dv.render or {}

    if dv.enabled == false then
        for _, bufnr in ipairs(markdown_loaded_buffers()) do
            render.clear_buffer(bufnr)
        end
        return
    end

    local events = {}
    local seen = {}
    for _, w in ipairs(render_cfg.when or {}) do
        local ev = WHEN_TO_EVENTS[w]
        if ev and not seen[ev] then
            seen[ev] = true
            table.insert(events, ev)
        end
    end

    if #events == 0 then
        return
    end

    vim.api.nvim_create_autocmd(events, {
        group = group,
        pattern = render_cfg.patterns or { "*.md" },
        callback = function(args)
            local buffers = target_buffers_for_scope(render_cfg.scope or "event", args.buf)
            local seen_bufs = {}
            for _, bufnr in ipairs(buffers) do
                if bufnr and not seen_bufs[bufnr] then
                    seen_bufs[bufnr] = true
                    M.refresh_buffer(bufnr)
                end
            end
        end,
    })
end

return M
