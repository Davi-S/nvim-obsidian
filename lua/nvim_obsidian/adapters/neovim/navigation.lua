local M = {}

function M.open_path(path)
    if type(path) ~= "string" or path == "" then
        return false, "invalid-path"
    end

    if not vim or not vim.api or type(vim.api.nvim_command) ~= "function" then
        return false, "nvim-command-unavailable"
    end

    local escaped = path
    if vim.fn and type(vim.fn.fnameescape) == "function" then
        escaped = vim.fn.fnameescape(path)
    end

    local ok, err = pcall(vim.api.nvim_command, "edit " .. escaped)
    if not ok then
        return false, tostring(err)
    end

    return true, nil
end

return M
