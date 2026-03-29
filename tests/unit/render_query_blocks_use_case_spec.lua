---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.render_query_blocks")

describe("render_query_blocks use case", function()
    local function base_ctx(overrides)
        local applied = nil
        local warned = {}

        local ctx = {
            config = {
                dataview = {
                    placement = "below_block",
                    render = {
                        when = {
                            open = true,
                            save = true,
                        },
                        messages = {
                            task_no_results = {
                                enabled = true,
                                text = "Dataview: No results to show for task query.",
                            },
                        },
                    },
                },
            },
            get_buffer_markdown = function(_buffer)
                return "# note\n```dataview\nTASK\nFROM \"notes\"\n```"
            end,
            apply_rendered_blocks = function(_buffer, overlays)
                applied = overlays
                return true
            end,
            dataview = {
                parse_blocks = function(_markdown)
                    return {
                        blocks = {
                            {
                                start_line = 2,
                                end_line = 5,
                                body_lines = { "TASK", "FROM \"notes\"" },
                                query = { kind = "task", from_kind = "path", from_value = "notes" },
                            },
                        },
                        error = nil,
                    }
                end,
                execute_query = function(_block, _notes)
                    return {
                        result = {
                            kind = "task",
                            rows = { { file = { path = "notes/a.md", title = "A" } } },
                            rendered_lines = { "- [ ] [[A]]" },
                        },
                        error = nil,
                    }
                end,
            },
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "notes/a.md", title = "A", aliases = {} },
                    }
                end,
            },
            notifications = {
                warn = function(msg)
                    table.insert(warned, msg)
                end,
            },
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                ctx[key] = value
            end
        end

        ctx._applied = function()
            return applied
        end
        ctx._warned = warned
        return ctx
    end

    local function run(ctx, input)
        return use_case.execute(ctx, input or {
            buffer = 1,
            trigger = "manual",
        })
    end

    it("renders parsed blocks and applies virtual overlays", function()
        local ctx = base_ctx()

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals(1, out.rendered_blocks)

        local overlays = ctx._applied()
        assert.equals(1, #overlays)
        assert.equals(5, overlays[1].anchor_line)
        assert.equals("below_block", overlays[1].placement)
        assert.equals("- [ ] [[A]]", overlays[1].lines[1])
    end)

    it("returns zero rendered blocks when trigger is disabled by config", function()
        local ctx = base_ctx({
            config = {
                dataview = {
                    placement = "below_block",
                    render = {
                        when = {
                            open = false,
                            save = true,
                        },
                    },
                },
            },
        })

        local out = run(ctx, {
            buffer = 1,
            trigger = "on_open",
        })

        assert.is_true(out.ok)
        assert.equals(0, out.rendered_blocks)
        assert.is_nil(ctx._applied())
    end)

    it("renders no-results message for empty TASK result when enabled", function()
        local ctx = base_ctx({
            dataview = {
                parse_blocks = function()
                    return {
                        blocks = {
                            {
                                start_line = 3,
                                end_line = 6,
                                query = { kind = "task" },
                            },
                        },
                        error = nil,
                    }
                end,
                execute_query = function()
                    return {
                        result = {
                            kind = "task",
                            rows = {},
                            rendered_lines = {},
                        },
                        error = nil,
                    }
                end,
            },
        })

        local out = run(ctx)
        assert.is_true(out.ok)

        local lines = ctx._applied()[1].lines
        assert.equals("Dataview: No results to show for task query.", lines[1])
    end)

    it("renders execution errors inside block output without failing whole operation", function()
        local ctx = base_ctx({
            dataview = {
                parse_blocks = function()
                    return {
                        blocks = {
                            {
                                start_line = 2,
                                end_line = 5,
                                query = { kind = "task" },
                            },
                        },
                        error = nil,
                    }
                end,
                execute_query = function()
                    return {
                        result = nil,
                        error = { message = "invalid dataview clause" },
                    }
                end,
            },
        })

        local out = run(ctx)
        assert.is_true(out.ok)

        local lines = ctx._applied()[1].lines
        assert.equals("Dataview: invalid dataview clause", lines[1])
    end)

    it("returns internal when patch application fails", function()
        local ctx = base_ctx({
            apply_rendered_blocks = function()
                return false, "buffer read-only"
            end,
        })

        local out = run(ctx)
        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)

    it("returns invalid_input for bad trigger", function()
        local ctx = base_ctx()
        local out = run(ctx, {
            buffer = 1,
            trigger = "on_write",
        })

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("warns on parse warning while still applying available blocks", function()
        local ctx = base_ctx({
            dataview = {
                parse_blocks = function()
                    return {
                        blocks = {
                            {
                                start_line = 2,
                                end_line = 5,
                                query = { kind = "task" },
                            },
                        },
                        error = { message = "unclosed dataview block" },
                    }
                end,
                execute_query = function()
                    return {
                        result = {
                            kind = "task",
                            rows = {},
                            rendered_lines = { "- [ ] [[A]]" },
                        },
                        error = nil,
                    }
                end,
            },
        })

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals(1, #ctx._warned)
    end)
end)
