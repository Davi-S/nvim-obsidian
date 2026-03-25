local M = {
    placeholders = {},
}

function M.register_placeholder(name, resolver)
    if type(name) ~= "string" or vim.trim(name) == "" then
        error("placeholder name must be a non-empty string")
    end
    if type(resolver) ~= "function" then
        error("placeholder resolver must be a function")
    end
    M.placeholders[name] = resolver
end

function M.resolve(name, ctx)
    local resolver = M.placeholders[name]
    if not resolver then
        return nil, false
    end
    local ok, value = pcall(resolver, ctx)
    if not ok then
        error("placeholder resolver failed for '" .. name .. "': " .. tostring(value))
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
