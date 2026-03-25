local path = require("nvim-obsidian.path")
local router = require("nvim-obsidian.journal.router")
local template = require("nvim-obsidian.template")

local M = {}

local function write_content(filepath, content)
    if content == "" then
        vim.fn.writefile({}, filepath)
    else
        vim.fn.writefile(vim.split(content, "\n", { plain = true }), filepath)
    end
end

function M.ensure_note(filepath, title, note_type, cfg)
    if vim.fn.filereadable(filepath) == 1 then
        return
    end

    path.ensure_dir(path.parent(filepath))
    local tpl = router.template_for_type(note_type, cfg)
    local ctx = template.build_context({
        cfg = cfg,
        title = title,
        note_type = note_type,
        note_abs_path = filepath,
        input = title,
        timestamp = os.time(),
    })
    local rendered = template.render(tpl, ctx)
    write_content(filepath, rendered)
end

function M.open(filepath)
    vim.cmd.edit(vim.fn.fnameescape(filepath))
end

function M.ensure_and_open(filepath, title, note_type, cfg)
    M.ensure_note(filepath, title, note_type, cfg)
    M.open(filepath)
end

return M