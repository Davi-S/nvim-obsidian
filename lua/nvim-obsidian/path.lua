local M = {}

local sep = "/"

local function strip_trailing_slash(p)
    return (p:gsub("/+$", ""))
end

function M.join(...)
    local parts = { ... }
    return table.concat(parts, sep):gsub("//+", "/")
end

function M.is_absolute(path)
    return vim.startswith(path, "/")
end

function M.normalize(path)
    local rp = vim.uv.fs_realpath(path)
    if rp then
        return strip_trailing_slash(rp)
    end
    return strip_trailing_slash(path)
end

function M.ensure_dir(path)
    vim.fn.mkdir(path, "p")
end

function M.parent(path)
    return vim.fs.dirname(path)
end

function M.basename(path)
    return vim.fs.basename(path)
end

function M.stem(path)
    return vim.fn.fnamemodify(path, ":t:r")
end

function M.rel_to_root(root, abs)
    local nroot = strip_trailing_slash(M.normalize(root))
    local nabs = M.normalize(abs)
    if not vim.startswith(nabs, nroot .. "/") then
        return nil
    end
    return nabs:sub(#nroot + 2)
end

function M.is_inside(root, abs)
    return M.rel_to_root(root, abs) ~= nil or M.normalize(root) == M.normalize(abs)
end

return M
