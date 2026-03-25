local parser = require("nvim-obsidian.template.parser")
local registry = require("nvim-obsidian.template.registry")

local M = {
    _warned_unknown = {},
    _cache = {},
}

local function warn_unknown_once(name)
    if M._warned_unknown[name] then
        return
    end
    M._warned_unknown[name] = true
    vim.notify("nvim-obsidian: unknown template placeholder '{{" .. name .. "}}'", vim.log.levels.WARN)
end

function M.render(template, ctx)
    local src = template or ""
    if src == "" then
        return ""
    end

    local tokens = M._cache[src]
    if not tokens then
        tokens = parser.parse(src)
        M._cache[src] = tokens
    end

    local out = {}
    for _, token in ipairs(tokens) do
        if token.type == "text" then
            table.insert(out, token.value)
        elseif token.type == "placeholder" then
            local value, ok = registry.resolve(token.name, ctx)
            if ok then
                table.insert(out, value)
            else
                warn_unknown_once(token.name)
                table.insert(out, token.raw)
            end
        end
    end

    return table.concat(out)
end

function M.reset_for_tests()
    M._warned_unknown = {}
    M._cache = {}
end

return M
