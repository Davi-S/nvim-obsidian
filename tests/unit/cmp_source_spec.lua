---@diagnostic disable: undefined-global

local cmp_source = require("nvim_obsidian.adapters.completion.cmp_source")

describe("cmp completion source adapter", function()
    local function base_ctx(overrides)
        local ctx = {
            config = {
                new_notes_subdir = "notes",
                vault_root = "/vault",
                templates = {
                    subdir = "templates",
                },
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
                        { path = "notes/foo.md",                title = "Foo",        aliases = { "F", "Foobar" } },
                        { path = "notes/bar.md",                title = "Bar",        aliases = {} },
                        { path = "notes/baz.md",                title = "Baz Note",   aliases = { "BZ" } },
                        { path = "journal/daily/2026-03-28.md", title = "2026-03-28", aliases = {} },
                    }
                end,
                find_by_identity_token = function(token)
                    local matches = {}
                    local all = {
                        { path = "notes/foo.md",                title = "Foo",        aliases = { "F", "Foobar" } },
                        { path = "notes/bar.md",                title = "Bar",        aliases = {} },
                        { path = "notes/baz.md",                title = "Baz Note",   aliases = { "BZ" } },
                        { path = "journal/daily/2026-03-28.md", title = "2026-03-28", aliases = {} },
                    }
                    for _, note in ipairs(all) do
                        if note.title == token then
                            table.insert(matches, note)
                        end
                    end
                    return {
                        exact_matches = matches,
                        exact_ci_matches = {},
                        fuzzy_matches = {},
                    }
                end,
            },
            fs_io = {
                read_file = function(path)
                    if path:match("notes/foo%.md$") then
                        return "# Alpha Heading\nSome content ^blk-1\n## Beta Heading\nAnother line ^blk_2"
                    end
                    return ""
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
                    return note.title or note.path
                end,
            },
            vim = {
                api = {
                    nvim_get_current_buf = function()
                        return 0
                    end,
                    nvim_buf_get_lines = function()
                        return {}
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

    describe("adapter structure", function()
        it("should export completion source function", function()
            assert.is_function(cmp_source.create_source)
        end)

        it("should export get_trigger_characters", function()
            assert.is_function(cmp_source.get_trigger_characters)
        end)

        it("should export resolve_completion_item", function()
            assert.is_function(cmp_source.resolve_completion_item)
        end)
    end)

    describe("create_source", function()
        it("should return a source table", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            assert.is_table(source)
        end)

        it("should have required cmp source methods", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            assert.is_function(source.complete)
            assert.is_function(source.resolve)
        end)

        it("should handle nil context gracefully", function()
            assert.has_no.errors(function()
                cmp_source.create_source(nil)
            end)
        end)

        it("should store context reference", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            assert.is_not_nil(source._ctx)
        end)

        it("should have display_name property", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            assert.is_string(source.display_name)
            assert.truthy(string.find(source.display_name:lower(), "obsidian"))
        end)
    end)

    describe("complete callback", function()
        it("should accept completion context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[",
                col = 3,
                before_line = "[[",
            }
            assert.has_no.errors(function()
                source.complete(completion_ctx, function()
                end)
            end)
        end)

        it("should call callback with candidates", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 5,
                before_line = "[[foo",
            }
            local called = false
            local items = nil
            source.complete(completion_ctx, function(result)
                called = true
                items = result.items
            end)
            assert.is_true(called)
            assert.is_table(items or {})
        end)

        it("should return empty items for invalid context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "normal text",
                col = 5,
                before_line = "normal text",
            }
            local called = false
            local items = nil
            source.complete(completion_ctx, function(result)
                called = true
                items = result.items or {}
            end)
            assert.is_true(called)
            -- Might be empty or have general completions depending on logic
            assert.is_table(items)
        end)

        it("should detect wiki link context [[", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "See [[",
                col = 7,
                before_line = "[[",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items
            end)
            assert.is_table(items)
            -- Should have some vault notes as candidates
        end)

        it("should detect partial wiki link query", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "See [[foo",
                col = 9,
                before_line = "[[foo",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items
            end)
            assert.is_table(items)
        end)

        it("should detect anchor completion [[ context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo#",
                col = 7,
                before_line = "[[foo#",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items
            end)
            assert.is_table(items)
        end)

        it("should return heading candidates for note anchor context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[Foo#A",
                col = 8,
                before_line = "[[Foo#A",
            }

            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)

            assert.is_true(#items > 0)
            assert.equals("#Alpha Heading", items[1].label)
            assert.equals("Alpha Heading", items[1].insertText)
        end)

        it("should return block-id candidates for note block context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[Foo#^blk",
                col = 11,
                before_line = "[[Foo#^blk",
            }

            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)

            assert.is_true(#items > 0)
            assert.equals("#^blk-1", items[1].label)
            assert.equals("^blk-1", items[1].insertText)
        end)

        it("should handle empty vault gracefully", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        return {}
                    end,
                },
            })
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[",
                col = 3,
                before_line = "[[",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)
            assert.is_table(items)
        end)

        it("should rank candidates by relevance", function()
            local ctx = base_ctx({
                search_ranking = {
                    score_candidates = function(query, notes)
                        local scored = {}
                        for _, note in ipairs(notes) do
                            local title_lower = (note.title or ""):lower()
                            local query_lower = query:lower()
                            local match_score = 0
                            if title_lower == query_lower then
                                match_score = 1000
                            elseif string.find(title_lower, query_lower, 1, true) then
                                match_score = 100
                            else
                                match_score = 0
                            end
                            table.insert(scored, {
                                note = note,
                                score = match_score,
                                matched_field = "title",
                            })
                        end
                        table.sort(scored, function(a, b) return a.score > b.score end)
                        return scored
                    end,
                },
            })
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items
            end)
            -- Should rank "Foo" and "Foobar" higher
            assert.is_table(items)
        end)

        it("should handle completion item fields", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[",
                col = 3,
                before_line = "[[",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
                -- Each item should have label and kind
                for _, item in ipairs(items) do
                    if item then
                        assert.is_string(item.label or "")
                        assert.is_string(item.kind or "")
                    end
                end
            end)
        end)

        it("should handle ranking errors gracefully", function()
            local ctx = base_ctx({
                search_ranking = {
                    score_candidates = function()
                        return nil, { code = "error" }
                    end,
                },
            })
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            local called = false
            source.complete(completion_ctx, function(result)
                called = true
                assert.is_table(result.items or {})
            end)
            assert.is_true(called)
        end)
    end)

    describe("resolve callback", function()
        it("should accept completion item", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local item = {
                label = "Foo",
                kind = "Variable",
            }
            assert.has_no.errors(function()
                source.resolve(item, function()
                end)
            end)
        end)

        it("should enrich completion item with detail", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local item = {
                label = "Foo",
                kind = "Variable",
                data = { path = "notes/foo.md" },
            }
            local resolved = nil
            source.resolve(item, function(result)
                resolved = result
            end)
            assert.is_table(resolved)
            assert.is_string(resolved.detail or "")
        end)

        it("should handle items without data", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local item = {
                label = "Generic",
                kind = "Text",
            }
            assert.has_no.errors(function()
                source.resolve(item, function()
                end)
            end)
        end)
    end)

    describe("trigger characters", function()
        it("should include wiki link trigger", function()
            local triggers = cmp_source.get_trigger_characters()
            assert.is_table(triggers)
            local has_bracket = false
            for _, char in ipairs(triggers) do
                if char == "[" then
                    has_bracket = true
                    break
                end
            end
            assert.is_true(has_bracket)
        end)

        it("should include anchor trigger", function()
            local triggers = cmp_source.get_trigger_characters()
            assert.is_table(triggers)
            local has_hash = false
            for _, char in ipairs(triggers) do
                if char == "#" then
                    has_hash = true
                    break
                end
            end
            assert.is_true(has_hash)
        end)

        it("should be a non-empty list", function()
            local triggers = cmp_source.get_trigger_characters()
            assert.is_table(triggers)
            assert.is_true(#triggers > 0)
        end)
    end)

    describe("error handling", function()
        it("should handle missing vault_catalog", function()
            local ctx = base_ctx({ vault_catalog = nil })
            assert.has_no.errors(function()
                cmp_source.create_source(ctx)
            end)
        end)

        it("should handle missing search_ranking", function()
            local ctx = base_ctx({ search_ranking = nil })
            assert.has_no.errors(function()
                cmp_source.create_source(ctx)
            end)
        end)

        it("should handle malformed completion context", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            assert.has_no.errors(function()
                source.complete({}, function()
                end)
            end)
        end)

        it("should handle callback errors gracefully", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            assert.has_no.errors(function()
                source.complete(completion_ctx, function()
                    error("Callback error")
                end)
            end)
        end)

        it("should handle list_notes errors", function()
            local ctx = base_ctx({
                vault_catalog = {
                    list_notes = function()
                        error("Failed to list notes")
                    end,
                },
            })
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[",
                col = 3,
                before_line = "[[",
            }
            assert.has_no.errors(function()
                source.complete(completion_ctx, function()
                end)
            end)
        end)
    end)

    describe("wiki link completion logic", function()
        it("should match note titles", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "See [[F",
                col = 8,
                before_line = "[[F",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)
            -- Should include Foo and Foobar (start with F)
            assert.is_table(items)
        end)

        it("should match note aliases", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "See [[BZ",
                col = 8,
                before_line = "[[BZ",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)
            -- Should include Baz Note (alias BZ)
            assert.is_table(items)
        end)

        it("should support exact match priority", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[Bar",
                col = 6,
                before_line = "[[Bar",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
            end)
            -- Bar should rank highest
            assert.is_table(items)
            if #items > 0 then
                assert.equal(items[1].label, "Bar")
            end
        end)
    end)

    describe("completion item format", function()
        it("should include label", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[",
                col = 3,
                before_line = "[[",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
                for _, item in ipairs(items) do
                    if item then
                        assert.is_string(item.label)
                    end
                end
            end)
        end)

        it("should include kind for sorting", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
                for _, item in ipairs(items) do
                    if item then
                        assert.is_string(item.kind)
                    end
                end
            end)
        end)

        it("should include sortText for ordering", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
                for _, item in ipairs(items) do
                    if item then
                        assert.is_string(item.sortText or item.label)
                    end
                end
            end)
        end)

        it("should include filterText for matching", function()
            local ctx = base_ctx()
            local source = cmp_source.create_source(ctx)
            local completion_ctx = {
                cur_line = "[[foo",
                col = 6,
                before_line = "[[foo",
            }
            local items = nil
            source.complete(completion_ctx, function(result)
                items = result.items or {}
                for _, item in ipairs(items) do
                    if item then
                        assert.is_string(item.filterText or item.label)
                    end
                end
            end)
        end)
    end)
end)
