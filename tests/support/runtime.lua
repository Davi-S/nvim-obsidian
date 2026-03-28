---@diagnostic disable: undefined-global

local M = {}

function M.append_rtp(path)
    if vim.fn.isdirectory(path) == 1 then
        vim.opt.rtp:append(path)
    end
end

function M.setup_runtime_paths()
    local cwd = vim.fn.getcwd()
    M.append_rtp(cwd)
    M.append_rtp("/home/davi/.local/share/nvim/lazy/plenary.nvim")
end

return M
