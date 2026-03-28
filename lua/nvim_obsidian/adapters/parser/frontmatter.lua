local M = {}

local function trim(s)
    if type(s) ~= "string" then return nil end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function parse_inline_list(val)
    local inner = val:match("^%[(.*)%]$")
    if not inner then
        return nil
    end

    local out = {}
    for token in inner:gmatch("([^,]+)") do
        local item = trim(token)
        if item and item ~= "" then
            item = item:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
            table.insert(out, item)
        end
    end
    return out
end

function M.parse(markdown)
    if type(markdown) ~= "string" then
        return {}, "parse_failure: invalid_input"
    end

    local lines = split_lines(markdown)
    if lines[1] ~= "---" then
        return {}, nil
    end

    local close_idx = nil
    for i = 2, #lines do
        if lines[i] == "---" then
            close_idx = i
            break
        end
    end

    if not close_idx then
        return {}, "parse_failure: unclosed_frontmatter"
    end

    local meta = {}
    local i = 2
    while i < close_idx do
        local line = lines[i]
        local key, raw_val = line:match("^([%w_%-%.]+):%s*(.*)$")
        if key then
            local val = trim(raw_val or "")
            if val == "" then
                local list = {}
                local j = i + 1
                while j < close_idx do
                    local item = lines[j]:match("^%s*%-%s*(.+)$")
                    if not item then
                        break
                    end
                    table.insert(list, trim(item))
                    j = j + 1
                end

                if #list > 0 then
                    meta[key] = list
                    i = j - 1
                else
                    meta[key] = ""
                end
            else
                local inline_list = parse_inline_list(val)
                if inline_list then
                    meta[key] = inline_list
                else
                    local scalar = val:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                    meta[key] = scalar
                end
            end
        end
        i = i + 1
    end

    if type(meta.aliases) ~= "table" then
        meta.aliases = nil
    end

    return meta, nil
end

return M
