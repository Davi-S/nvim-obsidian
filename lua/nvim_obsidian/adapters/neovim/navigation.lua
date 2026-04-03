local M = {}
local errors = require("nvim_obsidian.core.shared.errors")

local function adapter_error(code, message, meta)
    return errors.new(code, message, meta)
end

local function split_lines(text)
    local out = {}
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    if #out > 0 and out[#out] == "" then
        table.remove(out, #out)
    end
    return out
end

local function normalize_heading_token(value)
    local s = tostring(value or "")
    s = s:lower()
    s = s:gsub("[`*_~]", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function slugify_heading(value)
    local s = tostring(value or "")
    s = s:lower()
    s = s:gsub("[`*_~]", "")
    s = s:gsub("[^%w%s%-]", "")
    s = s:gsub("%s+", "-")
    s = s:gsub("%-+", "-")
    s = s:gsub("^%-+", ""):gsub("%-+$", "")
    return s
end

local function find_heading_line(lines, anchor)
    local anchor_norm = normalize_heading_token(anchor)
    local anchor_slug = slugify_heading(anchor)
    for i, line in ipairs(lines) do
        local heading = line:match("^%s*#+%s*(.-)%s*$")
        if heading then
            local heading_norm = normalize_heading_token(heading)
            local heading_slug = slugify_heading(heading)
            if heading_norm == anchor_norm or heading_slug == anchor_slug then
                return i
            end
        end
    end
    return nil
end

local function find_block_line(lines, block_id)
    local id = tostring(block_id or "")
    if id == "" then
        return nil
    end

    local escaped = id:gsub("([^%w])", "%%%1")
    for i, line in ipairs(lines) do
        local from = 1
        while true do
            local s, e = line:find("%^" .. escaped, from)
            if not s then
                break
            end

            local next_char = line:sub(e + 1, e + 1)
            if next_char == "" or not next_char:match("[%w_%-]") then
                return i
            end

            from = s + 1
        end
    end
    return nil
end

function M.open_path(path)
    if type(path) ~= "string" or path == "" then
        return false, adapter_error(errors.codes.INVALID_INPUT, "path must be a non-empty string")
    end

    if not vim or not vim.api or type(vim.api.nvim_command) ~= "function" then
        return false, adapter_error(errors.codes.INTERNAL, "nvim command API is unavailable")
    end

    local escaped = path
    if vim.fn and type(vim.fn.fnameescape) == "function" then
        escaped = vim.fn.fnameescape(path)
    end

    local ok, err = pcall(vim.api.nvim_command, "edit " .. escaped)
    if not ok then
        return false, adapter_error(errors.codes.INTERNAL, "failed to open path", {
            path = path,
            reason = tostring(err),
        })
    end

    return true, nil
end

function M.insert_text_at_cursor(text)
    if not vim or not vim.api or type(vim.api.nvim_put) ~= "function" then
        return false, adapter_error(errors.codes.INTERNAL, "nvim_put API is unavailable")
    end

    local lines = split_lines(text)
    local ok, err = pcall(vim.api.nvim_put, lines, "c", true, true)
    if not ok then
        return false, adapter_error(errors.codes.INTERNAL, "failed to insert text at cursor", {
            reason = tostring(err),
        })
    end

    return true, nil
end

function M.jump_to_line(line)
    local target_line = tonumber(line)
    if not target_line or target_line < 1 then
        return false, adapter_error(errors.codes.INVALID_INPUT, "line must be a positive integer")
    end

    if not vim or not vim.api or type(vim.api.nvim_win_set_cursor) ~= "function" or type(vim.api.nvim_get_current_win) ~= "function" then
        return false, adapter_error(errors.codes.INTERNAL, "nvim cursor API is unavailable")
    end

    local ok, err = pcall(vim.api.nvim_win_set_cursor, vim.api.nvim_get_current_win(), { target_line, 0 })
    if not ok then
        return false, adapter_error(errors.codes.INTERNAL, "failed to jump to line", {
            line = target_line,
            reason = tostring(err),
        })
    end

    return true, nil
end

function M.jump_to_anchor(target)
    if type(target) ~= "table" then
        return false, adapter_error(errors.codes.INVALID_INPUT, "target must be a table")
    end

    local anchor = target.anchor
    local block_id = target.block_id
    if (type(anchor) ~= "string" or anchor == "") and (type(block_id) ~= "string" or block_id == "") then
        return false, adapter_error(errors.codes.INVALID_INPUT, "anchor or block_id is required")
    end

    if not vim or not vim.api or type(vim.api.nvim_get_current_buf) ~= "function" or type(vim.api.nvim_buf_get_lines) ~= "function" then
        return false, adapter_error(errors.codes.INTERNAL, "nvim buffer API is unavailable")
    end

    local ok, lines = pcall(vim.api.nvim_buf_get_lines, vim.api.nvim_get_current_buf(), 0, -1, false)
    if not ok or type(lines) ~= "table" then
        return false, adapter_error(errors.codes.INTERNAL, "failed to read buffer lines")
    end

    local line_no = nil
    if type(block_id) == "string" and block_id ~= "" then
        line_no = find_block_line(lines, block_id)
    end
    if not line_no and type(anchor) == "string" and anchor ~= "" then
        line_no = find_heading_line(lines, anchor)
    end

    if not line_no then
        return false, adapter_error(errors.codes.NOT_FOUND, "anchor or block target not found", {
            anchor = anchor,
            block_id = block_id,
        })
    end

    return M.jump_to_line(line_no)
end

return M
