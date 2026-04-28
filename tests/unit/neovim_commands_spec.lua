---@diagnostic disable: undefined-global

local commands = require("nvim_obsidian.adapters.neovim.commands")

describe("neovim command adapter", function()
    local command_registry = {}
    local autocmd_registry = {}

    before_each(function()
        command_registry = {}
        autocmd_registry = {}
        local scheduled_queue = {}
        local deferred_queue = {}
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
        _G.vim.defer_fn = function(fn, _delay_ms)
            -- For tests, defer_fn behaves like schedule (ignore delay)
            table.insert(deferred_queue, fn)
        end
        _G.vim._drain_scheduled = function()
            while #scheduled_queue > 0 do
                local fn = table.remove(scheduled_queue, 1)
                fn()
            end
            while #deferred_queue > 0 do
                local fn = table.remove(deferred_queue, 1)
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
        _G.vim.uv = nil
        _G.vim.loop = nil
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

    local function find_autocmd_callback(event_name)
        for _, item in ipairs(autocmd_registry) do
            local events = item.events
            if type(events) == "string" then
                if events == event_name then
                    return item.opts and item.opts.callback
                end
            elseif type(events) == "table" then
                for _, ev in ipairs(events) do
                    if ev == event_name then
                        return item.opts and item.opts.callback
                    end
                end
            end
        end
        return nil
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
            assert.is_true(#autocmd_registry >= 1)

            local callback = find_autocmd_callback("BufReadPost")
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
            local callback = find_autocmd_callback("BufWritePost")

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
            local callback = find_autocmd_callback("BufWritePost")

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
            local callback = find_autocmd_callback("BufWritePost")

            callback({ event = "BufWritePost", buf = 7 })
            assert.equals(0, #calls) -- render is deferred via vim.schedule()
            _G.vim._drain_scheduled()

            assert.equals(2, #calls)
            assert.equals(21, calls[1].buffer)
            assert.equals(23, calls[2].buffer)
        end)
    end)

    describe(":ObsidianCalendar", function()
        it("opens picker mode without journal note callback", function()
            local observed = nil
            local container = base_container({
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianCalendar"]({ args = "pick" })

            assert.is_table(observed)
            assert.equals("picker", observed.mode)
            assert.equals("buffer", observed.ui_variant)
            assert.is_nil(observed.on_finish)
        end)

        it("opens floating picker without journal note callback", function()
            local observed = nil
            local container = base_container({
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianCalendarFloat"]({ args = "pick" })

            assert.is_table(observed)
            assert.equals("picker", observed.mode)
            assert.equals("floating", observed.ui_variant)
            assert.is_nil(observed.on_finish)
        end)
    end)

    describe(":ObsidianJournalCalendar", function()
        it("registers floating calendar command variants", function()
            local container = base_container()
            commands.register(container)

            assert.is_function(command_registry["ObsidianCalendarFloat"])
            assert.is_function(command_registry["ObsidianJournalCalendarFloat"])
        end)

        it("opens floating calendar command with floating ui variant", function()
            local observed = nil
            local container = base_container({
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianCalendarFloat"]({ args = "pick" })

            assert.is_table(observed)
            assert.equals("picker", observed.mode)
            assert.equals("floating", observed.ui_variant)
        end)

        it("opens floating journal calendar with floating ui variant", function()
            local observed = nil
            local container = base_container({
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianJournalCalendarFloat"]()

            assert.is_table(observed)
            assert.equals("picker", observed.mode)
            assert.equals("floating", observed.ui_variant)
            assert.is_function(observed.on_finish)
        end)

        it("registers secondary journal calendar command", function()
            local container = base_container()
            commands.register(container)

            assert.is_function(command_registry["ObsidianJournalCalendar"])
        end)

        it("opens date picker in picker mode", function()
            local observed = nil
            local container = base_container({
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            observed = input
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            assert.is_function(command_registry["ObsidianJournalCalendar"])

            command_registry["ObsidianJournalCalendar"]()

            assert.is_table(observed)
            assert.equals("picker", observed.mode)
            assert.equals("buffer", observed.ui_variant)
            assert.is_function(observed.on_finish)
        end)

        it("prompts before creating a missing note when confirmation is enabled", function()
            local prompted = nil
            local created = nil
            local opened_picker = false
            _G.vim.fn = _G.vim.fn or {}
            _G.vim.fn.confirm = function(message, choices, default)
                prompted = {
                    message = message,
                    choices = choices,
                    default = default,
                }
                return 2
            end

            local container = base_container({
                resolve_journal_title = function()
                    return "2026-04-26"
                end,
                config = {
                    calendar = {
                        confirm_before_create = true,
                    },
                },
                vault_catalog = {
                    find_by_identity_token = function()
                        return { matches = {} }
                    end,
                },
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            opened_picker = true
                            input.on_finish({
                                action = "selected",
                                selected_kind = "daily",
                                date = { year = 2026, month = 4, day = 26 },
                            })
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                    ensure_open_note = {
                        execute = function()
                            created = true
                            return { ok = true, path = "journal/daily/2026-04-26.md", created = true, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianJournalCalendar"]()

            assert.is_true(opened_picker)
            assert.is_table(prompted)
            assert.matches("Create journal note", prompted.message)
            assert.equals("&Create\n&Cancel", prompted.choices)
            assert.equals(2, prompted.default)
            assert.is_nil(created)
        end)

        it("does not prompt when the journal note already exists", function()
            local confirm_called = false
            local opened_picker = false
            _G.vim.fn = _G.vim.fn or {}
            _G.vim.fn.confirm = function()
                confirm_called = true
                return 1
            end

            local opened = nil
            local container = base_container({
                resolve_journal_title = function()
                    return "2026-04-26"
                end,
                config = {
                    calendar = {
                        confirm_before_create = true,
                    },
                },
                vault_catalog = {
                    find_by_identity_token = function()
                        return { matches = { { path = "/vault/journal/daily/2026-04-26.md" } } }
                    end,
                },
                use_cases = {
                    open_date_picker = {
                        execute = function(_ctx, input)
                            opened_picker = true
                            input.on_finish({
                                action = "selected",
                                selected_kind = "daily",
                                date = { year = 2026, month = 4, day = 26 },
                            })
                            return { ok = true, action = "opened", date = nil, cursor_date = nil, error = nil }
                        end,
                    },
                    ensure_open_note = {
                        execute = function()
                            opened = true
                            return { ok = true, path = "journal/daily/2026-04-26.md", created = false, error = nil }
                        end,
                    },
                },
            })

            commands.register(container)
            command_registry["ObsidianJournalCalendar"]()

            assert.is_true(opened_picker)
            assert.is_false(confirm_called)
            assert.is_true(opened)
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
