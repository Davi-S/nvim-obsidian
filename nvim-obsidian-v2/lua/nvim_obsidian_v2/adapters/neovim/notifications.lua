---@diagnostic disable: undefined-global

local M = {}

local function notify(msg, level)
    if vim and vim.notify then
        vim.notify(msg, level)
    end
end

function M.info(msg)
    notify(msg, vim and vim.log and vim.log.levels.INFO or nil)
end

function M.warn(msg)
    notify(msg, vim and vim.log and vim.log.levels.WARN or nil)
end

function M.error(msg)
    notify(msg, vim and vim.log and vim.log.levels.ERROR or nil)
end

return M
