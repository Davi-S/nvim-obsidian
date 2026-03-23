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

local function parse_aliases_tags_yaml(yaml)
    local result = {
        aliases = {},
        tags = {},
    }

    local active_key = nil
    local function accept_key(key)
        return key == "aliases" or key == "tags"
    end

    for _, raw_line in ipairs(vim.split(yaml, "\n", { plain = true })) do
        local line = raw_line
        local key, rhs = line:match("^([%w_%-]+):%s*(.*)$")
        if key then
            if accept_key(key) then
                active_key = key
                if rhs ~= "" then
                    if rhs:match("^%[.*%]$") then
                        result[key] = split_inline_array(rhs)
                    else
                        result[key] = normalize_list(rhs)
                    end
                    active_key = nil
                else
                    result[key] = {}
                end
            else
                active_key = nil
            end
        else
            local item = line:match("^%s*-%s*(.+)%s*$")
            if active_key and item then
                local cleaned = vim.trim(item):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                if cleaned ~= "" then
                    table.insert(result[active_key], cleaned)
                end
            elseif line:match("^%S") then
                active_key = nil
            end
        end
    end

    return result
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

    return parse_aliases_tags_yaml(yaml)
end

return M
