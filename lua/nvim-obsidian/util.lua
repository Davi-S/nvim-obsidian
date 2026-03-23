local M = {}

function M.err(msg)
    vim.notify("nvim-obsidian: " .. msg, vim.log.levels.ERROR)
end

function M.info(msg)
    vim.notify("nvim-obsidian: " .. msg, vim.log.levels.INFO)
end

function M.trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.lower(s)
    return vim.fn.tolower(s)
end

function M.split_lines(text)
    if text == "" then
        return {}
    end
    return vim.split(text, "\n", { plain = true })
end

function M.tbl_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function M.unique_list(items)
    local out = {}
    local seen = {}
    for _, item in ipairs(items) do
        if not seen[item] then
            seen[item] = true
            table.insert(out, item)
        end
    end
    return out
end

return M
