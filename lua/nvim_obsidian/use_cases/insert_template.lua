local errors = require("nvim_obsidian.core.shared.errors")
local template_context = require("nvim_obsidian.app.template_context")

---Use-case: insert resolved template content at cursor.
---
---Supports explicit query path/template lookup and context-based placeholder
---rendering before insertion.
local M = {}

M.contract = {
    name = "insert_template",
    version = "phase3-contract",
    dependencies = {
        "filesystem.io",
        "template",
        "neovim.navigation",
    },
    input = {
        query = "string|nil",
        now = "integer|nil",
    },
    output = {
        ok = "boolean",
        inserted = "boolean|nil",
        error = "domain_error|nil",
    },
}

---@param s any
---@return string|nil
local function trim(s)
    if type(s) ~= "string" then return nil end
    local out = s:gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then return nil end
    return out
end

---Execute insert_template orchestration.
---@param _ctx table
---@param _input table|nil
---@return table
function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            inserted = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if _input ~= nil and type(_input) ~= "table" then
        return {
            ok = false,
            inserted = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table when provided"),
        }
    end

    local ctx = _ctx
    local input = _input or {}

    local navigation = ctx.navigation
    if type(navigation) ~= "table" or type(navigation.insert_text_at_cursor) ~= "function" then
        return {
            ok = false,
            inserted = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.navigation.insert_text_at_cursor is required"),
        }
    end

    local fs_io = ctx.fs_io
    local query = trim(input.query)

    local template_content = nil
    if query and type(ctx.resolve_template_content) == "function" then
        local resolved = ctx.resolve_template_content({
            query = query,
            command = "ObsidianInsertTemplate",
        })
        if type(resolved) == "string" and resolved ~= "" then
            template_content = resolved
        end
    end

    if not template_content and query and type(fs_io) == "table" and type(fs_io.read_file) == "function" then
        local content = fs_io.read_file(query)
        if type(content) == "string" and content ~= "" then
            template_content = content
        end
    end

    if not template_content then
        return {
            ok = false,
            inserted = nil,
            error = errors.new(errors.codes.NOT_FOUND, "template not found", {
                query = query,
            }),
        }
    end

    local rendered = template_content
    if type(ctx.template) == "table" and type(ctx.template.render) == "function" then
        local render_ctx = template_context.build({
            now = input.now,
            meta_origin = "insert_template_command",
            command = "ObsidianInsertTemplate",
            config_snapshot = ctx.config,
            note = nil,
        })

        local out = ctx.template.render(template_content, render_ctx)
        if type(out) == "table" and type(out.rendered) == "string" then
            rendered = out.rendered
        else
            return {
                ok = false,
                inserted = nil,
                error = errors.new(errors.codes.INTERNAL, "template.render returned invalid result"),
            }
        end
    end

    local inserted, insert_err = navigation.insert_text_at_cursor(rendered)
    if not inserted then
        return {
            ok = false,
            inserted = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to insert template", {
                reason = insert_err,
            }),
        }
    end

    return {
        ok = true,
        inserted = true,
        error = nil,
    }
end

return M
