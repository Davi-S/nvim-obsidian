local M = {}

local function normalize_list(value)
    if value == nil then
        return {}
    end
    if type(value) == "string" then
        return { value }
    end
    if type(value) == "table" then
        local out = {}
        for _, v in ipairs(value) do
            if type(v) == "string" then
                table.insert(out, v)
            end
        end
        return out
    end
    return {}
end

local function split_inline_array(value)
    local out = {}
    local inner = value:match("^%[(.*)%]$")
    if not inner then
        return out
    end

    for item in inner:gmatch("[^,]+") do
        local cleaned = vim.trim(item):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        if cleaned ~= "" then
            table.insert(out, cleaned)
        end
    end
    return out
end

local function parse_scalar(value)
    local s = vim.trim(value)
    if s == "" then
        return ""
    end

    if s == "true" then
        return true
    end
    if s == "false" then
        return false
    end
    if s == "null" or s == "~" then
        return vim.NIL
    end

    local num = tonumber(s)
    if num ~= nil then
        return num
    end

    local quoted = s:match('^"(.*)"$') or s:match("^'(.*)'$")
    if quoted then
        return quoted
    end

    if s:match("^%[.*%]$") then
        return split_inline_array(s)
    end

    return s
end

local function parse_yaml_fallback(yaml)
    local parsed = {}
    local lines = vim.split(yaml, "\n", { plain = true })
    local active_key = nil

    for _, raw_line in ipairs(lines) do
        local key, rhs = raw_line:match("^([%w_%-]+):%s*(.*)$")
        if key then
            active_key = nil
            if rhs == "" then
                parsed[key] = {}
                active_key = key
            else
                parsed[key] = parse_scalar(rhs)
            end
        else
            local list_item = raw_line:match("^%s+-%s*(.+)%s*$")
            if active_key and list_item then
                table.insert(parsed[active_key], parse_scalar(list_item))
            else
                local sub_key, sub_rhs = raw_line:match("^%s+([%w_%-]+):%s*(.*)$")
                if active_key and sub_key then
                    if vim.islist(parsed[active_key]) then
                        parsed[active_key] = {}
                    end
                    parsed[active_key][sub_key] = parse_scalar(sub_rhs)
                elseif raw_line:match("^%S") then
                    active_key = nil
                end
            end
        end
    end

    return parsed
end

local function strip_yaml_markers(block)
    local lines = vim.split(block, "\n", { plain = true })
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines, #lines)
    end

    if #lines < 2 then
        return nil
    end

    if lines[1] ~= "---" or lines[#lines] ~= "---" then
        return nil
    end

    table.remove(lines, 1)
    table.remove(lines, #lines)
    return table.concat(lines, "\n")
end

function M.extract_root_yaml(text)
    local ok, parser = pcall(vim.treesitter.get_string_parser, text, "markdown")
    if not ok or not parser then
        return nil
    end

    local trees = parser:parse()
    if not trees or not trees[1] then
        return nil
    end

    local root = trees[1]:root()
    local first = root:named_child(0)
    if not first then
        return nil
    end

    local sr, sc = first:range()
    if sr ~= 0 or sc ~= 0 or first:type() ~= "minus_metadata" then
        return nil
    end

    local meta_block = vim.treesitter.get_node_text(first, text)
    if type(meta_block) ~= "string" then
        return nil
    end

    return strip_yaml_markers(meta_block)
end

function M.parse(text)
    local yaml = M.extract_root_yaml(text)
    if not yaml then
        return { aliases = {}, tags = {} }
    end

    local ok, decoded = pcall(vim.fn.yaml_decode, yaml)
    if not ok or type(decoded) ~= "table" then
        decoded = parse_yaml_fallback(yaml)
    end

    local parsed = vim.deepcopy(decoded)
    parsed.aliases = normalize_list(parsed.aliases)
    parsed.tags = normalize_list(parsed.tags)
    return parsed
end

return M
