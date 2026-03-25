--[[
Template command implementations.

Provides the insert_at_cursor function for the :ObsidianInsertTemplate command.

Usage:
  - :ObsidianInsertTemplate            -- auto-detect note type from current buffer
  - :ObsidianInsertTemplate standard   -- use 'standard' note template
  - :ObsidianInsertTemplate ./template -- load from file path
]]

local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local router = require("nvim-obsidian.journal.router")
local classifier = require("nvim-obsidian.journal.classifier")
local template = require("nvim-obsidian.template")

local M = {}

local function split_lines(text)
    if text == "" then
        return { "" }
    end
    return vim.split(text, "\n", { plain = true })
end

local function insert_text_at_cursor(text)
    if text == "" then
        return
    end
    local buf = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    local row = pos[1] - 1
    local col = pos[2]
    local lines = split_lines(text)
    vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
end

local function detect_note_type(file, cfg)
    if file == "" then
        return "standard"
    end
    return classifier.note_type_for_path(file, cfg)
end

local function is_file_path(str)
    -- Check if string looks like a file path (contains / or \ or is readable as file)
    -- This allows both relative and absolute paths
    return str:match("/") or str:match("\\") or vim.fn.filereadable(str) == 1
end

local function read_template_file(filepath)
    -- Read template content from a file
    -- Returns: (content, error) tuple
    -- Error is nil if successful, string if file not found
    if vim.fn.filereadable(filepath) == 0 then
        return nil, "template file not found: " .. filepath
    end
    local lines = vim.fn.readfile(filepath)
    return table.concat(lines, "\n")
end

function M.insert_at_cursor(arg)
    --[[
    Insert a rendered template at the current cursor position.
    
    Arguments:
      arg: string - can be empty, a note type name, or a file path
        - empty string: auto-detect note type from current buffer
        - "standard"/"daily"/"weekly"/"monthly"/"yearly": use configured template for that type
        - "./path/to/template.md" or "/abs/path": load template from file
    
    Behavior:
      - If arg contains "/" or "\" or is a readable file, treat as file path
      - Otherwise treat as note type (with auto-detection if empty)
      - Loads template from configured router or from file
      - Builds context with current note metadata
      - Renders template with registered placeholders
      - Inserts at cursor without modifying other buffer content
      - Shows user facing errors via vim.notify if issues occur
    ]]
    local cfg = config.get()
    if not cfg then
        return
    end

    local file = vim.api.nvim_buf_get_name(0)
    local title = file ~= "" and path.stem(file) or ""
    local tpl
    local note_type

    if arg ~= "" and is_file_path(arg) then
        -- Treat as file path
        tpl, err = read_template_file(arg)
        if not tpl then
            vim.notify("nvim-obsidian: " .. err, vim.log.levels.ERROR)
            return
        end
        note_type = detect_note_type(file, cfg)
    else
        -- Treat as note type or detect automatically
        note_type = arg ~= "" and arg or detect_note_type(file, cfg)
        tpl = router.template_for_type(note_type, cfg)
        if tpl == "" then
            vim.notify("nvim-obsidian: no template configured for type '" .. note_type .. "'", vim.log.levels.WARN)
            return
        end
    end

    local ctx = template.build_context({
        cfg = cfg,
        title = title,
        note_type = note_type,
        note_abs_path = file,
        input = title,
        timestamp = os.time(),
    })

    local rendered = template.render(tpl, ctx)
    insert_text_at_cursor(rendered)
end

return M
