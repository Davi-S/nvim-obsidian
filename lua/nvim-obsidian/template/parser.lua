local M = {}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_valid_placeholder(name)
    return name:match("^[%a_][%w_]*$") ~= nil
end

function M.parse(template)
    local src = template or ""
    local tokens = {}
    local i = 1

    while i <= #src do
        local open_start, open_end = src:find("{{", i, true)
        if not open_start then
            table.insert(tokens, { type = "text", value = src:sub(i) })
            break
        end

        if open_start > i then
            table.insert(tokens, { type = "text", value = src:sub(i, open_start - 1) })
        end

        local close_start, close_end = src:find("}}", open_end + 1, true)
        if not close_start then
            table.insert(tokens, { type = "text", value = src:sub(open_start) })
            break
        end

        local inner = trim(src:sub(open_end + 1, close_start - 1))
        if is_valid_placeholder(inner) then
            table.insert(tokens, { type = "placeholder", name = inner, raw = src:sub(open_start, close_end) })
        else
            table.insert(tokens, { type = "text", value = src:sub(open_start, close_end) })
        end

        i = close_end + 1
    end

    return tokens
end

return M
