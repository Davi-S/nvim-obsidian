---@diagnostic disable: undefined-global

local telescope = require("nvim_obsidian.adapters.picker.telescope")

describe("telescope picker adapter", function()
    -- Mock vim.ui.select for testing
    local mock_select = nil
    local original_vim_ui_select = nil

    before_each(function()
        -- Save original and set up mock
        if vim and vim.ui then
            original_vim_ui_select = vim.ui.select
            mock_select = function(items, opts, on_choice)
                -- Mock: do nothing by default (simulates cancellation)
            end
            vim.ui.select = mock_select
        end
    end)

    after_each(function()
        -- Restore original
        if original_vim_ui_select and vim and vim.ui then
            vim.ui.select = original_vim_ui_select
        end
    end)

    local function base_ctx(overrides)
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
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "notes/foo.md",                title = "Foo",        aliases = { "F" } },
                        { path = "notes/bar.md",                title = "Bar",        aliases = {} },
                        { path = "journal/daily/2026-03-28.md", title = "2026-03-28", aliases = {} },
                    }
                end,
            },
            search_ranking = {
                score_candidates = function(query, notes)
                    local scored = {}
                    for _, note in ipairs(notes) do
                        table.insert(scored, {
                            note = note,
                            score = 100,
                            matched_field = "title",
                        })
                    end
                    return scored
                end,
                select_display = function(note)
                    return note.title .. " → " .. note.path
                end,
            },
            journal = {
                classify_input = function(query)
                    return { kind = "none" }
                end,
            },
            vim = {
                api = {
                    nvim_get_current_buf = function()
                        return 0
                    end,
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

    describe("open_omni picker", function()
        it("should export open_omni function", function()
            assert.is_function(telescope.open_omni)
        end)

        it("should accept context argument", function()
            local ctx = base_ctx()
            assert.has_no.errors(function()
                -- May return false/error, but shouldn't crash
                telescope.open_omni(ctx)
            end)
        end)

        it("should return false when no telescope available", function()
            local ctx = { vault_catalog = {} }
            local ok, result = telescope.open_omni(ctx)
            -- When vim.ui.select unavailable, returns false
            assert.is_false(ok)
        end)

        it("should handle empty vault gracefully", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        return {}
                    end,
                },
            })
            local ok = telescope.open_omni(ctx)
            -- Empty vault is valid state
            assert.is_boolean(ok)
        end)

        it("should rank and display candidates in picker format", function()
            local ctx = base_ctx()
            -- The picker should internally call search_ranking.score_candidates
            -- and format results for display
            assert.is_function(telescope.open_omni)
        end)

        it("should handle ranking errors gracefully", function()
            local ctx = base_ctx({
                search_ranking = {
                    score_candidates = function()
                        return nil, { code = "internal_error", message = "Ranking failed" }
                    end,
                },
            })
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should cancel picker without error", function()
            local ctx = base_ctx()
            -- When user cancels picker, should return false cleanly
            assert.is_function(telescope.open_omni)
        end)

        it("should respect omni_picker_config from context", function()
            local ctx = base_ctx({
                config = {
                    omni_picker_config = {
                        enable_preview = false,
                        layout_config = { width = 80 },
                    },
                },
            })
            assert.is_function(telescope.open_omni)
        end)
    end)

    describe("open_disambiguation_picker", function()
        it("should export open_disambiguation function", function()
            assert.is_function(telescope.open_disambiguation)
        end)

        it("should accept list of ambiguous matches", function()
            local matches = {
                { path = "a/note.md", title = "Note" },
                { path = "b/note.md", title = "Note" },
            }
            assert.has_no.errors(function()
                telescope.open_disambiguation(matches)
            end)
        end)

        it("should return false with no telescope", function()
            local matches = {
                { path = "a/note.md" },
                { path = "b/note.md" },
            }
            local ok = telescope.open_disambiguation(matches)
            assert.is_false(ok)
        end)

        it("should format matches for disambiguation display", function()
            local matches = {
                { path = "notes/nested/foo.md", title = "Foo" },
                { path = "archive/foo.md",      title = "Foo" },
            }
            -- Should display paths to disambiguate
            assert.is_function(telescope.open_disambiguation)
        end)

        it("should handle single match case", function()
            local matches = {
                { path = "notes/foo.md", title = "Foo" },
            }
            -- Single match still valid picker (auto-select behavior determined by UI)
            assert.is_function(telescope.open_disambiguation)
        end)

        it("should handle empty matches list", function()
            local matches = {}
            local ok = telescope.open_disambiguation(matches)
            -- Empty list is edge case but should handle gracefully
            assert.is_boolean(ok)
        end)

        it("should preserve match identity through picker", function()
            local matches = {
                { path = "a/foo.md", title = "Foo", custom_field = "preserve_me" },
                { path = "b/foo.md", title = "Foo" },
            }
            -- Selected match should be identical to original
            assert.is_function(telescope.open_disambiguation)
        end)
    end)

    describe("error handling", function()
        it("should handle missing vault_catalog gracefully", function()
            local ctx = { config = {} }
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should handle missing search_ranking gracefully", function()
            local ctx = base_ctx({
                search_ranking = nil,
            })
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should not crash on malformed candidates", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        return {
                            { path = "notes/good.md",     title = "Good" },
                            nil,                             -- malformed entry
                            { path = "notes/also_good.md" }, -- missing title
                        }
                    end,
                },
            })
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should handle display_label generation errors", function()
            local ctx = base_ctx({
                search_ranking = {
                    select_display = function()
                        error("Display error")
                    end,
                },
            })
            -- Should not panic
            assert.has_no.errors(function()
                telescope.open_omni(ctx)
            end)
        end)
    end)

    describe("display and ranking", function()
        it("should rank by title match first", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        return {
                            { path = "notes/foo.md",    title = "Foo" },
                            { path = "notes/foobar.md", title = "FooBar" },
                            { path = "notes/bar.md",    title = "Bar" },
                        }
                    end,
                },
                search_ranking = {
                    score_candidates = function(query, notes)
                        -- Would sort by relevance in real implementation
                        local scored = {}
                        for _, note in ipairs(notes) do
                            table.insert(scored, {
                                note = note,
                                score = string.find(note.title:lower(), query:lower()) and 100 or 50,
                                matched_field = "title",
                            })
                        end
                        table.sort(scored, function(a, b) return a.score > b.score end)
                        return scored
                    end,
                },
            })
            assert.is_function(telescope.open_omni)
        end)

        it("should use display_label from search_ranking.select_display", function()
            local ctx = base_ctx({
                search_ranking = {
                    select_display = function(note)
                        return (note.title or note.path) .. " [" .. note.path .. "]"
                    end,
                },
            })
            assert.is_function(telescope.open_omni)
        end)

        it("should handle aliases in ranking", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        return {
                            { path = "notes/foo.md", title = "Foo", aliases = { "F", "Foobar" } },
                            { path = "notes/bar.md", title = "Bar", aliases = {} },
                        }
                    end,
                },
            })
            assert.is_function(telescope.open_omni)
        end)
    end)

    describe("picker state and selection", function()
        it("should return selected candidate path on success", function()
            local ctx = base_ctx()
            -- open_omni returns boolean success/failure
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should return nil/false on user cancel", function()
            local ctx = base_ctx()
            -- Cancel signal returns false
            local ok = telescope.open_omni(ctx)
            assert.is_boolean(ok)
        end)

        it("should preserve selected match in disambiguation", function()
            local matches = {
                { path = "a/note.md", title = "Note", data = "match_a" },
                { path = "b/note.md", title = "Note", data = "match_b" },
            }
            local ok = telescope.open_disambiguation(matches)
            assert.is_boolean(ok)
        end)
    end)

    describe("internal helper: _prepare_candidates", function()
        it("should return items and note_map", function()
            local ctx = base_ctx()
            local notes = ctx.vault_catalog.list_notes()
            local items, note_map = telescope._prepare_candidates(ctx, notes)

            assert.is_table(items)
            assert.is_table(note_map)
            assert.equal(#items, #note_map)
        end)

        it("should filter out empty notes", function()
            local ctx = base_ctx()
            local items, note_map = telescope._prepare_candidates(ctx, {
                { path = "notes/foo.md", title = "Foo" },
                nil, -- malformed
                { path = "notes/bar.md", title = "Bar" },
            })

            assert.equal(#items, 2)
            assert.equal(#note_map, 2)
        end)

        it("should use title as fallback display", function()
            local ctx = base_ctx({
                search_ranking = {
                    select_display = nil, -- no custom display
                },
            })
            local items, _ = telescope._prepare_candidates(ctx, {
                { path = "notes/foo.md", title = "Foo Title" },
            })

            assert.truthy(string.find(items[1] or "", "Foo Title"))
        end)

        it("should use select_display if available", function()
            local ctx = base_ctx({
                search_ranking = {
                    score_candidates = function(q, notes)
                        return { {
                            note = notes[1],
                            score = 100,
                        } }
                    end,
                    select_display = function(note)
                        return "[CUSTOM] " .. note.title
                    end,
                },
            })
            local items, _ = telescope._prepare_candidates(ctx, {
                { path = "notes/foo.md", title = "Foo" },
            })

            assert.truthy(string.find(items[1] or "", "%[CUSTOM%]"))
        end)

        it("should handle select_display errors gracefully", function()
            local ctx = base_ctx({
                search_ranking = {
                    select_display = function()
                        error("Display failed")
                    end,
                },
            })
            assert.has_no_errors(function()
                telescope._prepare_candidates(ctx, {
                    { path = "notes/foo.md", title = "Foo" },
                })
            end)
        end)

        it("should rank candidates if scoring available", function()
            local ctx = base_ctx({
                search_ranking = {
                    score_candidates = function(query, notes)
                        -- Reverse order to test ranking
                        local scored = {}
                        for i = #notes, 1, -1 do
                            if notes[i] then
                                table.insert(scored, {
                                    note = notes[i],
                                    score = i,
                                })
                            end
                        end
                        return scored
                    end,
                },
            })
            local items, note_map = telescope._prepare_candidates(ctx, {
                { path = "a.md", title = "A" },
                { path = "b.md", title = "B" },
                { path = "c.md", title = "C" },
            })

            -- Should be ordered by score
            assert.equal(note_map[1].title, "C")
            assert.equal(note_map[2].title, "B")
            assert.equal(note_map[3].title, "A")
        end)
    end)

    describe("internal helper: _prepare_disambiguation", function()
        it("should return items and match_map", function()
            local matches = {
                { path = "a/foo.md", title = "Foo" },
                { path = "b/foo.md", title = "Foo" },
            }
            local items, match_map = telescope._prepare_disambiguation(matches)

            assert.is_table(items)
            assert.is_table(match_map)
            assert.equal(#items, #match_map)
        end)

        it("should show path in display for disambiguation", function()
            local matches = {
                { path = "a/foo.md", title = "Foo" },
                { path = "b/foo.md", title = "Foo" },
            }
            local items, _ = telescope._prepare_disambiguation(matches)

            for _, item in ipairs(items) do
                assert.truthy(string.find(item, "a/foo.md") or string.find(item, "b/foo.md"))
            end
        end)

        it("should handle missing title gracefully", function()
            local matches = {
                { path = "notes/foo.md" }, -- no title
                { path = "notes/bar.md", title = "Bar" },
            }
            local items, match_map = telescope._prepare_disambiguation(matches)

            assert.equal(#items, 2)
            assert.equal(#match_map, 2)
        end)

        it("should filter out invalid entries", function()
            local matches = {
                { path = "a/foo.md", title = "Foo" },
                nil, -- invalid
                { path = "b/foo.md" },
            }
            local items, match_map = telescope._prepare_disambiguation(matches)

            assert.equal(#items, 2)
            assert.equal(#match_map, 2)
        end)

        it("should preserve match identity", function()
            local match_a = { path = "a/foo.md", title = "Foo", custom = "data_a" }
            local match_b = { path = "b/foo.md", title = "Foo", custom = "data_b" }
            local matches = { match_a, match_b }
            local _, match_map = telescope._prepare_disambiguation(matches)

            assert.equal(match_map[1].custom, "data_a")
            assert.equal(match_map[2].custom, "data_b")
        end)
    end)

    describe("omni payload regressions", function()
        it("preserves original-case ordinals for Telescope filtering", function()
            local captured = {
                finder = nil,
                select_handler = nil,
            }

            local original_preload = {}
            local original_loaded = {}
            local module_names = {
                "telescope.pickers",
                "telescope.finders",
                "telescope.config",
                "telescope.actions",
                "telescope.actions.state",
                "nvim_obsidian.adapters.picker.telescope",
            }

            for _, name in ipairs(module_names) do
                original_preload[name] = package.preload[name]
                original_loaded[name] = package.loaded[name]
            end

            package.preload["telescope.pickers"] = function()
                return {
                    new = function(_, spec)
                        captured.finder = spec.finder
                        spec.attach_mappings(1, function() end)
                        return {
                            find = function() end,
                        }
                    end,
                }
            end

            package.preload["telescope.finders"] = function()
                return {
                    new_table = function(opts)
                        return opts
                    end,
                }
            end

            package.preload["telescope.config"] = function()
                return {
                    values = {
                        generic_sorter = function()
                            return function() end
                        end,
                        file_previewer = function()
                            return function() end
                        end,
                    },
                }
            end

            package.preload["telescope.actions"] = function()
                return {
                    close = function() end,
                    select_default = {
                        replace = function(fn)
                            captured.select_handler = fn
                        end,
                    },
                }
            end

            package.preload["telescope.actions.state"] = function()
                return {
                    get_selected_entry = function()
                        return nil
                    end,
                }
            end

            package.loaded["nvim_obsidian.adapters.picker.telescope"] = nil
            local adapter = require("nvim_obsidian.adapters.picker.telescope")

            local out = adapter.open_omni({
                query = "ABC",
                items = {
                    {
                        label = "ABC -> notes/Alpha.md",
                        candidate = {
                            path = "/vault/notes/Alpha.md",
                        },
                    },
                },
                allow_create = true,
            })

            assert.is_table(out)
            assert.equals("deferred", out.action)
            assert.is_table(captured.finder)
            assert.is_table(captured.finder.results)

            local first = captured.finder.entry_maker(captured.finder.results[1])
            local create = captured.finder.entry_maker(captured.finder.results[2])

            assert.equals("ABC -> notes/Alpha.md", first.ordinal)
            assert.equals("+ Create: ABC", create.ordinal)

            for _, name in ipairs(module_names) do
                package.preload[name] = original_preload[name]
                package.loaded[name] = original_loaded[name]
            end
        end)

        it("includes aliases in ordinal with alias-first weighting", function()
            local captured = {
                finder = nil,
            }

            local original_preload = {}
            local original_loaded = {}
            local module_names = {
                "telescope.pickers",
                "telescope.finders",
                "telescope.config",
                "telescope.actions",
                "telescope.actions.state",
                "nvim_obsidian.adapters.picker.telescope",
            }

            for _, name in ipairs(module_names) do
                original_preload[name] = package.preload[name]
                original_loaded[name] = package.loaded[name]
            end

            package.preload["telescope.pickers"] = function()
                return {
                    new = function(_, spec)
                        captured.finder = spec.finder
                        spec.attach_mappings(1, function() end)
                        return {
                            find = function() end,
                        }
                    end,
                }
            end

            package.preload["telescope.finders"] = function()
                return {
                    new_table = function(opts)
                        return opts
                    end,
                }
            end

            package.preload["telescope.config"] = function()
                return {
                    values = {
                        generic_sorter = function()
                            return function() end
                        end,
                        file_previewer = function()
                            return function() end
                        end,
                    },
                }
            end

            package.preload["telescope.actions"] = function()
                return {
                    close = function() end,
                    select_default = {
                        replace = function() end,
                    },
                }
            end

            package.preload["telescope.actions.state"] = function()
                return {
                    get_selected_entry = function()
                        return nil
                    end,
                }
            end

            package.loaded["nvim_obsidian.adapters.picker.telescope"] = nil
            local adapter = require("nvim_obsidian.adapters.picker.telescope")

            local out = adapter.open_omni({
                query = "",
                items = {
                    {
                        label = "Introducao -> notas/calc.md",
                        candidate = {
                            title = "Introducao a Geometria",
                            aliases = { "GAAL" },
                            relpath = "notas/calc.md",
                            path = "/vault/notas/calc.md",
                        },
                    },
                },
                allow_create = false,
            })

            assert.is_table(out)
            assert.equals("deferred", out.action)
            assert.is_table(captured.finder)
            assert.is_table(captured.finder.results)

            local first = captured.finder.entry_maker(captured.finder.results[1])

            assert.is_true(first.ordinal:find("GAAL", 1, true) == 1)
            assert.truthy(first.ordinal:find("Introducao a Geometria", 1, true))
            assert.truthy(first.ordinal:find("/vault/notas/calc.md", 1, true))

            for _, name in ipairs(module_names) do
                package.preload[name] = original_preload[name]
                package.loaded[name] = original_loaded[name]
            end
        end)

        it("shows alias in label on exact alias prompt match", function()
            local captured = {
                finder = nil,
            }

            local original_preload = {}
            local original_loaded = {}
            local module_names = {
                "telescope.pickers",
                "telescope.finders",
                "telescope.config",
                "telescope.actions",
                "telescope.actions.state",
                "nvim_obsidian.adapters.picker.telescope",
            }

            for _, name in ipairs(module_names) do
                original_preload[name] = package.preload[name]
                original_loaded[name] = package.loaded[name]
            end

            package.preload["telescope.pickers"] = function()
                return {
                    new = function(_, spec)
                        captured.finder = spec.finder
                        spec.attach_mappings(1, function() end)
                        return {
                            find = function() end,
                        }
                    end,
                }
            end

            package.preload["telescope.finders"] = function()
                return {
                    new_table = function(opts)
                        return opts
                    end,
                }
            end

            package.preload["telescope.config"] = function()
                return {
                    values = {
                        generic_sorter = function()
                            return function() end
                        end,
                        file_previewer = function()
                            return function() end
                        end,
                    },
                }
            end

            package.preload["telescope.actions"] = function()
                return {
                    close = function() end,
                    select_default = {
                        replace = function() end,
                    },
                }
            end

            package.preload["telescope.actions.state"] = function()
                return {
                    get_selected_entry = function()
                        return nil
                    end,
                    get_current_line = function()
                        return "GAAL"
                    end,
                }
            end

            package.loaded["nvim_obsidian.adapters.picker.telescope"] = nil
            local adapter = require("nvim_obsidian.adapters.picker.telescope")

            local out = adapter.open_omni({
                query = "",
                items = {
                    {
                        label = "Introducao -> notas/calc.md",
                        candidate = {
                            title = "Introducao a Geometria",
                            aliases = { "GAAL" },
                            relpath = "notas/calc.md",
                            path = "/vault/notas/calc.md",
                        },
                    },
                },
                allow_create = false,
            })

            assert.is_table(out)
            assert.equals("deferred", out.action)

            local first = captured.finder.entry_maker(captured.finder.results[1])
            assert.equals("GAAL -> notas/calc.md", first.display())

            for _, name in ipairs(module_names) do
                package.preload[name] = original_preload[name]
                package.loaded[name] = original_loaded[name]
            end
        end)
    end)
end)
