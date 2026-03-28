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

return M
