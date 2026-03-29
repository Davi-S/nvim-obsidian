local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "vault_search",
    version = "phase3-contract",
    dependencies = {
        "picker.telescope",
        "neovim.navigation",
    },
    input = {
        query = "string|nil",
    },
    output = {
        ok = "boolean",
        selected = "boolean|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            selected = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if _input ~= nil and type(_input) ~= "table" then
        return {
            ok = false,
            selected = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table when provided"),
        }
    end

    local ctx = _ctx
    local input = _input or {}

    local telescope = ctx.telescope
    local navigation = ctx.navigation
    if type(telescope) ~= "table" or type(telescope.open_search) ~= "function" then
        return {
            ok = false,
            selected = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.telescope.open_search is required"),
        }
    end

    local root = type(ctx.config) == "table" and ctx.config.vault_root or nil
    if type(root) ~= "string" or root == "" then
        return {
            ok = false,
            selected = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.config.vault_root is required"),
        }
    end
    local selected = telescope.open_search({
        root = root,
        query = input.query,
        navigation = navigation,
    })

    return {
        ok = true,
        selected = selected == true,
        error = nil,
    }
end

return M
