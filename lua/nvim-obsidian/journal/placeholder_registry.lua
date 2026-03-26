local M = {
    placeholders = {},
}

local function validate_name(name)
    return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

function M.register_placeholder(name, resolver, regex_fragment)
    if not validate_name(name) then
        error("journal placeholder name must match ^[%a_][%w_]*$")
    end
    if type(resolver) ~= "function" then
        error("journal placeholder resolver must be a function")
    end
    if type(regex_fragment) ~= "string" or vim.trim(regex_fragment) == "" then
        error("journal placeholder regex_fragment must be a non-empty string")
    end

    M.placeholders[name] = {
        resolver = resolver,
        regex_fragment = regex_fragment,
    }
end

function M.has(name)
    return M.placeholders[name] ~= nil
end

function M.get_regex_fragment(name)
    local entry = M.placeholders[name]
    if not entry then
        return nil
    end
    return entry.regex_fragment
end

function M.resolve(name, ctx)
    local entry = M.placeholders[name]
    if not entry then
        return nil, false
    end

    local ok, value = pcall(entry.resolver, ctx)
    if not ok then
        error("journal placeholder resolver failed for '" .. name .. "': " .. tostring(value))
    end

    if value == nil then
        return "", true
    end

    return tostring(value), true
end

function M.reset_for_tests()
    M.placeholders = {}
end

return M
