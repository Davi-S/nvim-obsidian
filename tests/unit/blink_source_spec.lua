---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local blink_source = require("nvim_obsidian.adapters.completion.blink_source")

local function with_stubbed_container(container, fn)
    local original = package.loaded["nvim_obsidian"]
    package.loaded["nvim_obsidian"] = {
        get_container = function()
            return container
        end,
    }

    local ok, err = pcall(fn)
    package.loaded["nvim_obsidian"] = original
    if not ok then
        error(err)
    end
end

local function with_vim_api(overrides, fn)
    local original = {}
    for name, replacement in pairs(overrides) do
        original[name] = vim.api[name]
        vim.api[name] = replacement
    end

    local ok, err = pcall(fn)

    for name, replacement in pairs(original) do
        vim.api[name] = replacement
    end

    if not ok then
        error(err)
    end
end

local function base_container(overrides)
    local container = {
        config = {
            vault_root = "/vault",
        },
        vault_catalog = {
            list_notes = function()
                return {
                    { path = "notes/foo.md", title = "Foo",      aliases = { "F", "Foobar" } },
                    { path = "notes/bar.md", title = "Bar",      aliases = {} },
                    { path = "notes/baz.md", title = "Baz Note", aliases = { "BZ" } },
                }
            end,
            find_by_identity_token = function(token)
                local matches = {}
                for _, note in ipairs({
                    { path = "notes/foo.md", title = "Foo",      aliases = { "F", "Foobar" } },
                    { path = "notes/bar.md", title = "Bar",      aliases = {} },
                    { path = "notes/baz.md", title = "Baz Note", aliases = { "BZ" } },
                }) do
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
            score_candidates = function(_, notes)
                local scored = {}
                for _, note in ipairs(notes) do
                    table.insert(scored, {
                        note = note,
                        score = 100,
                    })
                end
                return scored
            end,
        },
    }

    if type(overrides) == "table" then
        for key, value in pairs(overrides) do
            if type(container[key]) == "table" and type(value) == "table" then
                for subkey, subvalue in pairs(value) do
                    container[key][subkey] = subvalue
                end
            else
                container[key] = value
            end
        end
    end

    return container
end

describe("blink completion source adapter", function()
    describe("module surface", function()
        it("exports source helpers", function()
            assert.is_function(blink_source.new)
            assert.is_function(blink_source.get_trigger_characters)
            assert.is_function(blink_source.resolve_completion_item)
        end)
    end)

    describe("source creation", function()
        it("returns a source table", function()
            local source = blink_source.new({})
            assert.is_table(source)
            assert.is_function(source.enabled)
            assert.is_function(source.get_completions)
            assert.is_function(source.resolve)
        end)

        it("reports disabled when the plugin is not initialized", function()
            local source = blink_source.new({})
            assert.is_false(source:enabled())
        end)
    end)

    describe("trigger characters", function()
        it("includes wiki-link and anchor triggers", function()
            local triggers = blink_source.get_trigger_characters()
            assert.is_table(triggers)
            assert.is_true(vim.tbl_contains(triggers, "["))
            assert.is_true(vim.tbl_contains(triggers, "#"))
        end)
    end)

    describe("note completions", function()
        it("returns note items with text edits", function()
            with_stubbed_container(base_container(), function()
                local source = blink_source.new({})
                local items = nil
                source:get_completions({
                    before_line = "See [[Fo",
                    col = 8,
                    row = 1,
                }, function(result)
                    items = result.items
                end)

                assert.is_table(items)
                assert.is_true(#items > 0)
                assert.equals("Foo", items[1].label)
                assert.is_table(items[1].textEdit)
                assert.equals("Foo", items[1].textEdit.newText)
            end)
        end)

        it("handles an empty vault gracefully", function()
            with_stubbed_container(base_container({
                vault_catalog = {
                    list_notes = function()
                        return {}
                    end,
                },
            }), function()
                local source = blink_source.new({})
                local items = nil
                source:get_completions({
                    before_line = "[[",
                    col = 2,
                    row = 1,
                }, function(result)
                    items = result.items
                end)

                assert.is_table(items)
                assert.equals(0, #items)
            end)
        end)
    end)

    describe("anchor completions", function()
        it("returns heading anchors", function()
            with_stubbed_container(base_container(), function()
                local source = blink_source.new({})
                local items = nil
                source:get_completions({
                    before_line = "[[Foo#A",
                    col = 7,
                    row = 1,
                }, function(result)
                    items = result.items
                end)

                assert.is_table(items)
                assert.is_true(#items > 0)
                assert.equals("#Alpha Heading", items[1].label)
                assert.equals("Alpha Heading", items[1].textEdit.newText)
            end)
        end)

        it("returns block anchors", function()
            with_stubbed_container(base_container(), function()
                local source = blink_source.new({})
                local items = nil
                source:get_completions({
                    before_line = "[[Foo#^blk",
                    col = 10,
                    row = 1,
                }, function(result)
                    items = result.items
                end)

                assert.is_table(items)
                assert.is_true(#items > 0)
                assert.equals("#^blk-1", items[1].label)
                assert.equals("^blk-1", items[1].textEdit.newText)
            end)
        end)
    end)

    describe("resolve", function()
        it("fills detail from the item path", function()
            local resolved = nil
            blink_source.resolve_completion_item({
                label = "Foo",
                data = { path = "notes/foo.md" },
            }, function(item)
                resolved = item
            end)

            assert.is_table(resolved)
            assert.equals("notes/foo.md", resolved.detail)
        end)
    end)

    describe("error handling", function()
        it("does not error without a container", function()
            local source = blink_source.new({})
            assert.has_no.errors(function()
                source:get_completions({
                    before_line = "[[Foo",
                    col = 5,
                    row = 1,
                }, function()
                end)
            end)
        end)
    end)
end)
