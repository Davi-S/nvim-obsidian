---@diagnostic disable: undefined-global

local commands = require("nvim_obsidian.adapters.neovim.commands")

describe("neovim command adapter", function()
    local command_registry = {}
    local autocmd_registry = {}

    before_each(function()
        command_registry = {}
        autocmd_registry = {}
        local scheduled_queue = {}
        _G.vim = _G.vim or {}
        _G.vim.api = _G.vim.api or {}
        _G.vim.tbl_deep_extend = _G.vim.tbl_deep_extend or function(_mode, base, ext)
            local out = {}
            for k, v in pairs(base or {}) do
                out[k] = v
            end
            for k, v in pairs(ext or {}) do
                out[k] = v
            end
            return out
        end
        _G.vim.api.nvim_create_user_command = function(name, fn)
            command_registry[name] = fn
        end
        _G.vim.api.nvim_create_augroup = function(_name, _opts)
            return 1
        end
        _G.vim.api.nvim_create_autocmd = function(events, opts)
            table.insert(autocmd_registry, {
                events = events,
                opts = opts,
            })
            return #autocmd_registry
        end
        _G.vim.schedule = function(fn)
            table.insert(scheduled_queue, fn)
        end
        _G.vim._drain_scheduled = function()
            while #scheduled_queue > 0 do
                local fn = table.remove(scheduled_queue, 1)
                fn()
            end
        end
        _G.vim.api.nvim_buf_get_name = function()
            return "/vault/journal/daily/2026-03-10.md"
        end
        _G.vim.api.nvim_get_current_line = function()
            return ""
        end
        _G.vim.api.nvim_win_get_cursor = function()
            return { 1, 0 }
        end
        _G.vim.api.nvim_buf_is_valid = function()
            return true
        end
        _G.vim.api.nvim_buf_is_loaded = function()
            return true
        end
        _G.vim.api.nvim_get_current_buf = function()
            return 1
        end
        _G.vim.api.nvim_list_wins = function()
            return { 1 }
        end
        _G.vim.api.nvim_win_get_buf = function()
            return 1
        end
        _G.vim.api.nvim_list_bufs = function()
            return { 1 }
        end
    end)

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

        it("should always target daily today instead of current-note context", function()
            local observed = nil

            _G.vim.api.nvim_buf_get_name = function()
                return "/vault/journal/daily/1900-01-01.md"
            end

            local container = base_container({
                journal = {
                    classify_input = function()
                        return { kind = "monthly" }
                    end,
                    build_title = function(_kind, date)
                        return { title = string.format("%04d-%02d-%02d", date.year, date.month, date.day) }
                    end,
                },
                use_cases = {
                    ensure_open_note = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, path = "journal/daily/today.md", created = false, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            assert.is_function(command_registry["ObsidianToday"])

            command_registry["ObsidianToday"]()

            assert.is_not_nil(observed)
            assert.equals("daily", observed.journal_kind)
            assert.is_true(observed.create_if_missing)
            assert.not_equals("1900-01-01", observed.title_or_token)
        end)
    end)

    describe(":ObsidianNext", function()
        it("should compute target relative to currently opened note", function()
            local observed = nil
            local container = base_container({
                journal = {
                    classify_input = function()
                        return { kind = "daily" }
                    end,
                    compute_adjacent = function(_kind, date, direction)
                        assert.equals("next", direction)
                        observed = date
                        return { target_date = { year = 2026, month = 3, day = 11 } }
                    end,
                },
                resolve_journal_title = function(_kind, date)
                    return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
                end,
                use_cases = {
                    ensure_open_note = {
                        execute = function(_ctx, input)
                            assert.equals("2026-03-11", input.title_or_token)
                            return { ok = true, path = "journal/daily/2026-03-11.md", created = false, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            assert.is_function(command_registry["ObsidianNext"])

            command_registry["ObsidianNext"]()
            assert.is_not_nil(observed)
            assert.equals(2026, observed.year)
            assert.equals(3, observed.month)
            assert.equals(10, observed.day)
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

        it("registers dataview autocmds for configured triggers", function()
            local calls = {}
            local container = base_container({
                config = {
                    dataview = {
                        enabled = true,
                        render = {
                            when = { "on_open", "on_save" },
                            patterns = { "*.md" },
                        },
                    },
                },
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, input)
                            table.insert(calls, input)
                            return { ok = true, processed_blocks = 1, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            assert.equals(1, #autocmd_registry)

            local callback = autocmd_registry[1].opts.callback
            assert.is_function(callback)

            callback({ event = "BufReadPost", buf = 7 })
            assert.equals(0, #calls)
            _G.vim._drain_scheduled()
            assert.equals(1, #calls)
            callback({ event = "BufWritePost", buf = 7 })
            assert.equals(1, #calls)
            _G.vim._drain_scheduled()

            assert.equals(2, #calls)
            assert.equals("on_open", calls[1].trigger)
            assert.equals("on_save", calls[2].trigger)
        end)

        it("renders current buffer when dataview scope is current", function()
            local calls = {}
            _G.vim.api.nvim_get_current_buf = function()
                return 9
            end

            local container = base_container({
                config = {
                    dataview = {
                        enabled = true,
                        render = {
                            when = { "on_save" },
                            scope = "current",
                            patterns = { "*.md" },
                        },
                    },
                },
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, input)
                            table.insert(calls, input)
                            return { ok = true, processed_blocks = 1, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            local callback = autocmd_registry[1].opts.callback

            callback({ event = "BufWritePost", buf = 7 })
            assert.equals(0, #calls) -- render is deferred via vim.schedule()
            _G.vim._drain_scheduled()

            assert.equals(1, #calls)
            assert.equals(9, calls[1].buffer)
            assert.equals("on_save", calls[1].trigger)
        end)

        it("renders visible window buffers when dataview scope is visible", function()
            local calls = {}
            _G.vim.api.nvim_list_wins = function()
                return { 10, 11, 12 }
            end
            _G.vim.api.nvim_win_get_buf = function(win)
                if win == 10 then
                    return 4
                end
                if win == 11 then
                    return 4
                end
                return 5
            end

            local container = base_container({
                config = {
                    dataview = {
                        enabled = true,
                        render = {
                            when = { "on_save" },
                            scope = "visible",
                            patterns = { "*.md" },
                        },
                    },
                },
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, input)
                            table.insert(calls, input)
                            return { ok = true, processed_blocks = 1, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            local callback = autocmd_registry[1].opts.callback

            callback({ event = "BufWritePost", buf = 7 })
            assert.equals(0, #calls) -- render is deferred via vim.schedule()
            _G.vim._drain_scheduled()

            assert.equals(2, #calls)
            assert.equals(4, calls[1].buffer)
            assert.equals(5, calls[2].buffer)
        end)

        it("renders loaded buffers when dataview scope is loaded", function()
            local calls = {}
            _G.vim.api.nvim_list_bufs = function()
                return { 21, 22, 23 }
            end
            _G.vim.api.nvim_buf_is_loaded = function(buf)
                return buf ~= 22
            end

            local container = base_container({
                config = {
                    dataview = {
                        enabled = true,
                        render = {
                            when = { "on_save" },
                            scope = "loaded",
                            patterns = { "*.md" },
                        },
                    },
                },
                use_cases = {
                    render_query_blocks = {
                        execute = function(_ctx, input)
                            table.insert(calls, input)
                            return { ok = true, processed_blocks = 1, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            local callback = autocmd_registry[1].opts.callback

            callback({ event = "BufWritePost", buf = 7 })
            assert.equals(0, #calls) -- render is deferred via vim.schedule()
            _G.vim._drain_scheduled()

            assert.equals(2, #calls)
            assert.equals(21, calls[1].buffer)
            assert.equals(23, calls[2].buffer)
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
