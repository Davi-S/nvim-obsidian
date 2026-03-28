local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "render_query_blocks",
    version = "phase3-contract",
    dependencies = {
        "dataview",
        "vault_catalog",
        "parser.markdown",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        buffer = "integer",
        trigger = "on_open|on_save|manual",
    },
    output = {
        ok = "boolean",
        rendered_blocks = "integer|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    local ctx = _ctx or {}
    local input = _input or {}

    local function invalid(message)
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, message),
        }
    end

    if type(input.buffer) ~= "number" then
        return invalid("buffer must be an integer")
    end

    local trigger = input.trigger
    if trigger ~= "on_open" and trigger ~= "on_save" and trigger ~= "manual" then
        return invalid("trigger must be on_open|on_save|manual")
    end

    local dataview = ctx.dataview
    local vault_catalog = ctx.vault_catalog

    if type(dataview) ~= "table" or type(dataview.parse_blocks) ~= "function" or type(dataview.execute_query) ~= "function" then
        return invalid("ctx.dataview parse/execute functions are required")
    end

    if type(vault_catalog) ~= "table" then
        return invalid("ctx.vault_catalog is required")
    end

    local get_buffer_markdown = ctx.get_buffer_markdown
    if type(get_buffer_markdown) ~= "function" and type(ctx.navigation) == "table" then
        get_buffer_markdown = ctx.navigation.get_buffer_markdown
    end

    if type(get_buffer_markdown) ~= "function" then
        return invalid("buffer markdown reader is required")
    end

    local apply_rendered_blocks = ctx.apply_rendered_blocks
    if type(apply_rendered_blocks) ~= "function" and type(ctx.navigation) == "table" then
        apply_rendered_blocks = ctx.navigation.apply_rendered_blocks
    end

    if type(apply_rendered_blocks) ~= "function" then
        return invalid("render patch applier is required")
    end

    local function trigger_enabled(cfg_trigger)
        if trigger == "manual" then
            return true
        end

        if type(cfg_trigger) ~= "table" then
            return true
        end

        local key = trigger:gsub("^on_", "")
        local value = cfg_trigger[key]
        if value == nil then
            return true
        end
        return value == true
    end

    local dataview_cfg = (((ctx.config or {}).dataview or {}).render or {})
    if not trigger_enabled(dataview_cfg.when) then
        return {
            ok = true,
            rendered_blocks = 0,
            error = nil,
        }
    end

    local markdown = get_buffer_markdown(input.buffer)
    if type(markdown) ~= "string" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to read current buffer markdown"),
        }
    end

    local parsed = dataview.parse_blocks(markdown)
    local blocks = (parsed and parsed.blocks) or {}

    local function collect_notes()
        if type(vault_catalog.list_notes) == "function" then
            local notes = vault_catalog.list_notes()
            if type(notes) == "table" then
                return notes
            end
        end
        if type(vault_catalog._all_notes_for_tests) == "function" then
            local notes = vault_catalog._all_notes_for_tests()
            if type(notes) == "table" then
                return notes
            end
        end
        return {}
    end

    local notes = collect_notes()

    local no_results_cfg = (((dataview_cfg.messages or {}).task_no_results) or {})
    local no_results_enabled = no_results_cfg.enabled ~= false
    local no_results_text = tostring(no_results_cfg.text or "Dataview: No results to show for task query.")

    local patches = {}

    for _, block in ipairs(blocks) do
        local exec = dataview.execute_query(block, notes)
        local lines = {
            "<!-- nvim-obsidian:dataview:start -->",
        }

        if exec and exec.error then
            table.insert(lines, "Dataview: " .. tostring(exec.error.message or "query execution failed"))
        else
            local result = (exec and exec.result) or {}
            local rendered = type(result.rendered_lines) == "table" and result.rendered_lines or {}

            if result.kind == "task" and #rendered == 0 and no_results_enabled then
                table.insert(lines, no_results_text)
            else
                for _, line in ipairs(rendered) do
                    table.insert(lines, tostring(line))
                end
            end
        end

        table.insert(lines, "<!-- nvim-obsidian:dataview:end -->")

        table.insert(patches, {
            start_line = block.start_line,
            end_line = block.end_line,
            lines = lines,
        })
    end

    local applied, apply_err = apply_rendered_blocks(input.buffer, patches)
    if not applied then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to apply dataview render patches", {
                reason = apply_err,
            }),
        }
    end

    if parsed and parsed.error and type(ctx.notifications) == "table" and type(ctx.notifications.warn) == "function" then
        ctx.notifications.warn("Dataview parse warning: " .. tostring(parsed.error.message or "parse failed"))
    end

    return {
        ok = true,
        rendered_blocks = #patches,
        error = nil,
    }
end

return M
