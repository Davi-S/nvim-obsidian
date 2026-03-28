local M = {}
local errors = require("nvim_obsidian.core.shared.errors")

local function adapter_error(code, message, meta)
    return errors.new(code, message, meta)
end

local function dirname(path)
    if type(path) ~= "string" then return nil end
    local normalized = path:gsub("\\", "/")
    local dir = normalized:match("^(.*)/[^/]*$")
    return dir
end

local function shell_escape_single_quotes(s)
    return tostring(s):gsub("'", "'\\''")
end

function M.read_file(path)
    if type(path) ~= "string" or path == "" then
        return nil, adapter_error(errors.codes.INVALID_INPUT, "path must be a non-empty string")
    end

    local file, open_err = io.open(path, "r")
    if not file then
        return nil, adapter_error(errors.codes.NOT_FOUND, "failed to open file for read", {
            path = path,
            reason = tostring(open_err or "failed-to-open"),
        })
    end

    local ok, content = pcall(file.read, file, "*a")
    file:close()
    if not ok then
        return nil, adapter_error(errors.codes.INTERNAL, "failed to read file contents", {
            path = path,
            reason = tostring(content),
        })
    end

    return content, nil
end

function M.write_file(path, content)
    if type(path) ~= "string" or path == "" then
        return false, adapter_error(errors.codes.INVALID_INPUT, "path must be a non-empty string")
    end

    local parent = dirname(path)
    if parent and parent ~= "" then
        local mkdir_ok = os.execute("mkdir -p '" .. shell_escape_single_quotes(parent) .. "'")
        if not mkdir_ok then
            return false, adapter_error(errors.codes.INTERNAL, "failed to create parent directory", {
                path = parent,
            })
        end
    end

    local file, open_err = io.open(path, "w")
    if not file then
        return false, adapter_error(errors.codes.INTERNAL, "failed to open file for write", {
            path = path,
            reason = tostring(open_err or "failed-to-open"),
        })
    end

    local ok, write_err = pcall(file.write, file, tostring(content or ""))
    file:close()
    if not ok then
        return false, adapter_error(errors.codes.INTERNAL, "failed to write file contents", {
            path = path,
            reason = tostring(write_err),
        })
    end

    return true, nil
end

function M.list_markdown_files(root)
    if type(root) ~= "string" or root == "" then
        return {}, adapter_error(errors.codes.INVALID_INPUT, "root must be a non-empty string")
    end

    local cmd = "find '" .. shell_escape_single_quotes(root) .. "' -type f -name '*.md' 2>/dev/null"
    local proc = io.popen(cmd)
    if not proc then
        return {}, adapter_error(errors.codes.INTERNAL, "failed to list markdown files", {
            root = root,
        })
    end

    local files = {}
    for line in proc:lines() do
        if line and line ~= "" then
            table.insert(files, line)
        end
    end
    proc:close()

    table.sort(files)
    return files, nil
end

return M
