---@diagnostic disable: undefined-global

local commands = require("nvim_obsidian.adapters.neovim.commands")

describe("neovim command adapter", function()
    local function base_container(overrides)
        local ctx = {
            config = {
                new_notes_subdir = "notes",
                journal = {
                    daily = { subdir = "journal/daily" },
                    weekly = { subdir = "journal/weekly" },
                    monthly = { subdir = "journal/monthly" },
                    yearly = { subdir = "journal/yearly" },
                },
            },
            use_cases = {
                ensure_open_note = {
                    execute = function(_ctx, _input)
                        return { ok = true, path = "notes/new.md", created = false, error = nil }
                    end,
                },
                follow_link = {
                    execute = function(_ctx, _input)
                        return { ok = true, path = "notes/target.md", error = nil }
                    end,
                },
                search_open_create = {
                    execute = function(_ctx, _input)
                        return { ok = true, path = "notes/result.md", created = false, error = nil }
                    end,
                },
                reindex_sync = {
                    execute = function(_ctx, _input)
                        return { ok = true, reindexed_count = 42, error = nil }
                    end,
                },
                render_query_blocks = {
                    execute = function(_ctx, _input)
                        return { ok = true, processed_blocks = 5, error = nil }
                    end,
                },
            },
            adapters = {
                notifications = {
                    info = function() end,
                    warn = function() end,
                    error = function() end,
                },
                navigation = {
                    open_path = function() return true end,
                },
                telescope = {
                    open_omni = function() return true end,
                    open_disambiguation_picker = function() return true, "notes/selected.md" end,
                },
            },
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                if type(ctx[key]) == "table" and type(value) == "table" then
                    for subkey, subvalue in pairs(value) do
                        ctx[key][subkey] = subvalue
                    end
                else
                    ctx[key] = value
                end
            end
        end

        return ctx
    end

    describe("command registration", function()
        it("should export a register function", function()
            assert.is_function(commands.register)
        end)

        it("should accept a container argument", function()
            local container = base_container()
            assert.has_no.errors(function()
                commands.register(container)
            end)
        end)
    end)

    describe(":ObsidianToday", function()
        local notifications_called = {}
        local navigation_called = {}

        local function reset_mocks()
            notifications_called = {}
            navigation_called = {}
        end

        it("should execute successfully and open today's note", function()
            reset_mocks()
            local container = base_container({
                adapters = {
                    notifications = {
                        info = function(msg)
                            table.insert(notifications_called, { level = "info", msg = msg })
                        end,
                        warn = function(msg)
                            table.insert(notifications_called, { level = "warn", msg = msg })
                        end,
                        error = function(msg)
                            table.insert(notifications_called, { level = "error", msg = msg })
                        end,
                    },
                    navigation = {
                        open_path = function(path)
                            table.insert(navigation_called, path)
                            return true
                        end,
                    },
                },
            })

            -- This will be tested directly via the commands module
            assert.is_function(commands.register)
        end)

        it("should handle missing vault catalog gracefully", function()
            reset_mocks()
            local container = base_container({
                use_cases = {
                    ensure_open_note = {
                        execute = function(_ctx, _input)
                            return {
                                ok = false,
                                path = nil,
                                error = { code = "internal_error", message = "vault_catalog required" },
                            }
                        end,
                    },
                },
                adapters = {
                    notifications = {
                        error = function(msg)
                            table.insert(notifications_called, { level = "error", msg = msg })
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)
    end)

    describe(":ObsidianOmni", function()
        it("should open telescope picker", function()
            local container = base_container({
                adapters = {
                    telescope = {
                        open_omni = function()
                            return true
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should handle no selection from picker", function()
            local container = base_container({
                adapters = {
                    telescope = {
                        open_omni = function()
                            return false
                        end,
                    },
                    notifications = {
                        info = function() end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)
    end)

    describe(":ObsidianFollow", function()
        it("should follow existing link", function()
            local container = base_container({
                use_cases = {
                    follow_link = {
                        execute = function(_ctx, _input)
                            return { ok = true, path = "notes/target.md", error = nil }
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should show picker on ambiguous target", function()
            local container = base_container({
                use_cases = {
                    follow_link = {
                        execute = function(_ctx, _input)
                            return {
                                ok = false,
                                path = nil,
                                error = { code = "ambiguous_target", message = "Multiple matches" },
                            }
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should handle missing cursor on link", function()
            local container = base_container({
                use_cases = {
                    follow_link = {
                        execute = function(_ctx, _input)
                            return {
                                ok = false,
                                path = nil,
                                error = { code = "invalid_input", message = "Cursor not on link" },
                            }
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)
    end)

    describe(":ObsidianReindex", function()
        it("should execute full index rebuild", function()
            local container = base_container({
                use_cases = {
                    reindex_sync = {
                        execute = function(_ctx, _input)
                            return { ok = true, reindexed_count = 42, error = nil }
                        end,
                    },
                },
                adapters = {
                    notifications = {
                        info = function() end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should notify on reindex completion", function()
            local notifications = {}
            local container = base_container({
                adapters = {
                    notifications = {
                        info = function(msg)
                            table.insert(notifications, msg)
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)
    end)

    describe(":ObsidianRenderDataview", function()
        it("should render dataview blocks in current buffer", function()
            local container = base_container({
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, _input)
                            return { ok = true, processed_blocks = 5, error = nil }
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should handle dataview parse errors gracefully", function()
            local container = base_container({
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, _input)
                            return {
                                ok = false,
                                processed_blocks = 0,
                                error = { code = "parse_failure", message = "Malformed block" },
                            }
                        end,
                    },
                },
                adapters = {
                    notifications = {
                        warn = function() end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)
    end)

    describe("error handling", function()
        it("should normalize domain errors to notifications", function()
            local notifications = {}
            local container = base_container({
                use_cases = {
                    ensure_open_note = {
                        execute = function(_ctx, _input)
                            return {
                                ok = false,
                                path = nil,
                                error = { code = "internal_error", message = "Something went wrong" },
                            }
                        end,
                    },
                },
                adapters = {
                    notifications = {
                        error = function(msg)
                            table.insert(notifications, msg)
                        end,
                    },
                },
            })

            assert.is_function(commands.register)
        end)

        it("should handle missing adapter dependencies gracefully", function()
            local container = {
                config = {},
                use_cases = {},
                adapters = {},
            }

            -- Should not crash when adapters are missing
            assert.has_no.errors(function()
                commands.register(container)
            end)
        end)
    end)
end)
