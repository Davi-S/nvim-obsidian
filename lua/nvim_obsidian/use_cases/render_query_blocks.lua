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
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if type(_input) ~= "table" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local ctx = _ctx
    local input = _input

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

    local function trigger_enabled(cfg_when)
        if trigger == "manual" then
            return true
        end

        if type(cfg_when) ~= "table" then
            return false
        end

        for _, configured in ipairs(cfg_when) do
            if configured == trigger then
                return true
            end
        end

        -- Backward-compatible explicit map shape: { open = true, save = false }
        local mapped = trigger:gsub("^on_", "")
        if cfg_when[mapped] ~= nil then
            return cfg_when[mapped] == true
        end

        return false
    end

    if type(ctx.config) ~= "table" or type(ctx.config.dataview) ~= "table" then
        return invalid("ctx.config.dataview is required")
    end

    local dataview_cfg = ctx.config.dataview
    if type(dataview_cfg.render) ~= "table" or type(dataview_cfg.render.when) ~= "table" then
        return invalid("ctx.config.dataview.render.when is required")
    end

    if not trigger_enabled(dataview_cfg.render.when) then
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
    local blocks = {}
    if type(parsed) == "table" and type(parsed.blocks) == "table" then
        blocks = parsed.blocks
    elseif parsed ~= nil then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "dataview.parse_blocks returned invalid result"),
        }
    end

    local function collect_notes()
        if type(vault_catalog.list_notes) ~= "function" then
            return nil, "ctx.vault_catalog.list_notes is required"
        end
        local notes = vault_catalog.list_notes()
        if type(notes) ~= "table" then
            return nil, "vault_catalog.list_notes returned invalid result"
        end
        return notes, nil
    end

    local notes, notes_err = collect_notes()
    if not notes then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, notes_err),
        }
    end

    local msg_holder = dataview_cfg.messages
    if type(msg_holder) ~= "table" and type(dataview_cfg.render) == "table" then
        msg_holder = dataview_cfg.render.messages
    end

    local no_results_cfg = type(msg_holder) == "table" and msg_holder.task_no_results or nil
    if type(no_results_cfg) ~= "table" then
        return invalid("ctx.config.dataview.messages.task_no_results is required")
    end
    if type(no_results_cfg.enabled) ~= "boolean" then
        return invalid("ctx.config.dataview.messages.task_no_results.enabled must be boolean")
    end
    if type(no_results_cfg.text) ~= "string" or no_results_cfg.text == "" then
        return invalid("ctx.config.dataview.messages.task_no_results.text must be non-empty string")
    end

    local no_results_enabled = no_results_cfg.enabled
    local no_results_text = no_results_cfg.text

    local patches = {}

    for _, block in ipairs(blocks) do
        local exec = dataview.execute_query(block, notes)
        local lines = {
            "<!-- nvim-obsidian:dataview:start -->",
        }

        if exec and exec.error then
            local message = type(exec.error.message) == "string" and exec.error.message or "query execution failed"
            table.insert(lines, "Dataview: " .. message)
        else
            local result = type(exec) == "table" and exec.result or nil
            if type(result) ~= "table" then
                return {
                    ok = false,
                    rendered_blocks = nil,
                    error = errors.new(errors.codes.INTERNAL, "dataview.execute_query returned invalid result"),
                }
            end

            local rendered = result.rendered_lines
            if type(rendered) ~= "table" then
                return {
                    ok = false,
                    rendered_blocks = nil,
                    error = errors.new(errors.codes.INTERNAL, "dataview query result missing rendered_lines table"),
                }
            end

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

    if type(parsed) == "table" and parsed.error and type(ctx.notifications) == "table" and type(ctx.notifications.warn) == "function" then
        local message = type(parsed.error.message) == "string" and parsed.error.message or "parse failed"
        ctx.notifications.warn("Dataview parse warning: " .. message)
    end

    return {
        ok = true,
        rendered_blocks = #patches,
        error = nil,
    }
end

return M
