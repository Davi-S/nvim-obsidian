local M = {}

local function make_readonly(value, seen)
    if type(value) ~= "table" then
        return value
    end

    if seen[value] then
        return seen[value]
    end

    local proxy = {}
    seen[value] = proxy

    local mt = {
        __index = function(_, key)
            return make_readonly(value[key], seen)
        end,
        __newindex = function()
            error("nvim-obsidian template ctx.config is read-only")
        end,
        __pairs = function()
            local function iter(_, key)
                local next_key, next_val = next(value, key)
                if next_key == nil then
                    return nil
                end
                return next_key, make_readonly(next_val, seen)
            end
            return iter, proxy, nil
        end,
        __len = function()
            return #value
        end,
    }

    return setmetatable(proxy, mt)
end

function M.wrap(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    return make_readonly(tbl, {})
end

return M
