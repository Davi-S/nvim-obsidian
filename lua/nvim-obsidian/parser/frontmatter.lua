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
        return { aliases = {}, tags = {} }
    end

    return {
        aliases = normalize_list(decoded.aliases),
        tags = normalize_list(decoded.tags),
    }
end

return M
