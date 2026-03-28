local M = {}

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
        return nil, "invalid-path"
    end

    local file, open_err = io.open(path, "r")
    if not file then
        return nil, tostring(open_err or "failed-to-open")
    end

    local ok, content = pcall(file.read, file, "*a")
    file:close()
    if not ok then
        return nil, tostring(content)
    end

    return content, nil
end

function M.write_file(path, content)
    if type(path) ~= "string" or path == "" then
        return false, "invalid-path"
    end

    local parent = dirname(path)
    if parent and parent ~= "" then
        local mkdir_ok = os.execute("mkdir -p '" .. shell_escape_single_quotes(parent) .. "'")
        if not mkdir_ok then
            return false, "failed-to-create-parent-dir"
        end
    end

    local file, open_err = io.open(path, "w")
    if not file then
        return false, tostring(open_err or "failed-to-open")
    end

    local ok, write_err = pcall(file.write, file, tostring(content or ""))
    file:close()
    if not ok then
        return false, tostring(write_err)
    end

    return true, nil
end

function M.list_markdown_files(root)
    if type(root) ~= "string" or root == "" then
        return {}, "invalid-root"
    end

    local cmd = "find '" .. shell_escape_single_quotes(root) .. "' -type f -name '*.md' 2>/dev/null"
    local proc = io.popen(cmd)
    if not proc then
        return {}, "failed-to-list-files"
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
