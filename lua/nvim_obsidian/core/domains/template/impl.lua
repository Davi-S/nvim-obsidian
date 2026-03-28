local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

local state = {
    resolvers = {},
}

local function is_valid_name(name)
    return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

local function to_string(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

function M.register_placeholders(registry)
    if type(registry) ~= "table" then
        return {
            ok = false,
            error = errors.new(errors.codes.INVALID_INPUT, "registry must be a table"),
        }
    end

    for name, resolver in pairs(registry) do
        if not is_valid_name(name) then
            return {
                ok = false,
                error = errors.new(errors.codes.INVALID_INPUT, "invalid placeholder name", {
                    name = name,
                }),
            }
        end

        if type(resolver) ~= "function" then
            return {
                ok = false,
                error = errors.new(errors.codes.INVALID_INPUT, "placeholder resolver must be a function", {
                    name = name,
                }),
            }
        end
    end

    for name, resolver in pairs(registry) do
        state.resolvers[name] = resolver
    end

    return { ok = true, error = nil }
end

function M.render(content, context)
    local src = content
    if src == nil then
        src = ""
    end
    src = tostring(src)

    local unresolved = {}
    local seen_unresolved = {}

    local rendered = src:gsub("{{([%a_][%w_]*)}}", function(name)
        local resolver = state.resolvers[name]
        if not resolver then
            if not seen_unresolved[name] then
                seen_unresolved[name] = true
                table.insert(unresolved, name)
            end
            return "{{" .. name .. "}}"
        end

        local ok, value = pcall(resolver, context or {})
        if not ok then
            if not seen_unresolved[name] then
                seen_unresolved[name] = true
                table.insert(unresolved, name)
            end
            return "{{" .. name .. "}}"
        end

        return to_string(value)
    end)

    return {
        rendered = rendered,
        unresolved = unresolved,
    }
end

function M._reset_for_tests()
    state.resolvers = {}
end

return M
