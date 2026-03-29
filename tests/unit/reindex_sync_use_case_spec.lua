---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.reindex_sync")

describe("reindex_sync use case", function()
    local function base_ctx(overrides)
        local upserts = {}
        local removes = {}
        local warns = {}
        local replaced = nil
        local watcher_starts = 0

        local files = {
            ["vault/a.md"] = "---\ntitle: Alpha\naliases:\n  - A\n---\n# Alpha",
            ["vault/b.md"] = "# Beta",
            ["vault/new.md"] = "---\ntitle: New\n---\nbody",
        }

        local ctx = {
            scan_markdown_files = function()
                return { "vault/a.md", "vault/b.md" }
            end,
            fs_io = {
                read_file = function(path)
                    local value = files[path]
                    if value == nil then
                        return nil, "missing"
                    end
                    return value
                end,
            },
            frontmatter = {
                parse = function(markdown)
                    if markdown:find("title: Alpha", 1, true) then
                        return { title = "Alpha", aliases = { "A" } }, nil
                    end
                    if markdown:find("title: New", 1, true) then
                        return { title = "New", aliases = {} }, nil
                    end
                    return {}, nil
                end,
            },
            vault_catalog = {
                upsert_note = function(note)
                    table.insert(upserts, note)
                    return { ok = true, error = nil }
                end,
                remove_note = function(path)
                    table.insert(removes, path)
                    return { ok = true, error = nil }
                end,
            },
            watcher = {
                start = function()
                    watcher_starts = watcher_starts + 1
                    return true
                end,
            },
            notifications = {
                warn = function(msg)
                    table.insert(warns, msg)
                end,
            },
            replace_catalog = function(notes)
                replaced = notes
                return true
            end,
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                ctx[key] = value
            end
        end

        ctx._upserts = upserts
        ctx._removes = removes
        ctx._warns = warns
        ctx._replaced = function()
            return replaced
        end
        ctx._watcher_starts = function()
            return watcher_starts
        end
        return ctx
    end

    it("runs manual full rescan and atomically replaces catalog when replace hook is present", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, { mode = "manual", event = nil })

        assert.is_true(out.ok)
        assert.equals("manual", out.stats.mode)
        assert.equals(2, out.stats.scanned)
        assert.equals(2, out.stats.upserted)
        assert.equals(0, out.stats.errors)

        local replaced = ctx._replaced()
        assert.is_not_nil(replaced)
        assert.equals(2, #replaced)
        assert.equals("Alpha", replaced[1].title)
        assert.equals("b", replaced[2].title)
    end)

    it("starts watcher in startup mode", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, { mode = "startup", event = nil })
        assert.is_true(out.ok)
        assert.equals(1, ctx._watcher_starts())
    end)

    it("continues startup reindex when watcher fails to start", function()
        local ctx = base_ctx({
            watcher = {
                start = function()
                    return false, "boom"
                end,
            },
        })

        local out = use_case.execute(ctx, { mode = "startup", event = nil })
        assert.is_true(out.ok)
        assert.equals("startup", out.stats.mode)
    end)

    it("handles delete event by removing note", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, {
            mode = "event",
            event = { kind = "delete", path = "vault/a.md" },
        })

        assert.is_true(out.ok)
        assert.equals(1, out.stats.removed)
        assert.equals("vault/a.md", ctx._removes[1])
    end)

    it("handles rename event by removing old and upserting new", function()
        local ctx = base_ctx({
            replace_catalog = nil,
            scan_markdown_files = nil,
        })

        local out = use_case.execute(ctx, {
            mode = "event",
            event = {
                kind = "rename",
                old_path = "vault/old.md",
                new_path = "vault/new.md",
            },
        })

        assert.is_true(out.ok)
        assert.equals(1, out.stats.removed)
        assert.equals(1, out.stats.upserted)
        assert.equals("vault/old.md", ctx._removes[1])
        assert.equals("vault/new.md", ctx._upserts[1].path)
        assert.equals("New", ctx._upserts[1].title)
    end)

    it("returns invalid_input for unsupported event kind", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, {
            mode = "event",
            event = { kind = "noop", path = "vault/a.md" },
        })

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("returns internal when full scan source is unavailable", function()
        local ctx = base_ctx({
            scan_markdown_files = false,
            fs_io = {
                read_file = function()
                    return ""
                end,
                list_markdown_files = function()
                    return nil
                end,
            },
        })

        local out = use_case.execute(ctx, { mode = "manual", event = nil })
        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)

    it("returns internal when atomic replace hook is missing for full reindex", function()
        local ctx = base_ctx({
            replace_catalog = false,
        })

        local out = use_case.execute(ctx, { mode = "manual", event = nil })
        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)

    it("invalidates render task cache on full reindex", function()
        local invalidation_calls = 0
        local invalidation_arg = "unset"
        local ctx = base_ctx({
            render_query_blocks = {
                invalidate_task_cache = function(paths)
                    invalidation_calls = invalidation_calls + 1
                    invalidation_arg = paths
                end,
            },
        })

        local out = use_case.execute(ctx, { mode = "manual", event = nil })
        assert.is_true(out.ok)
        assert.equals(1, invalidation_calls)
        assert.is_nil(invalidation_arg)
    end)

    it("invalidates render task cache for changed paths on event sync", function()
        local invalidations = {}
        local ctx = base_ctx({
            replace_catalog = nil,
            scan_markdown_files = nil,
            render_query_blocks = {
                invalidate_task_cache = function(paths)
                    table.insert(invalidations, paths)
                end,
            },
        })

        local out = use_case.execute(ctx, {
            mode = "event",
            event = {
                kind = "rename",
                old_path = "vault/old.md",
                new_path = "vault/new.md",
            },
        })

        assert.is_true(out.ok)
        assert.equals(2, #invalidations)
        assert.equals("vault/old.md", invalidations[1])
        assert.equals("vault/new.md", invalidations[2])
    end)

    it("preserves frontmatter metadata and tags on full reindex", function()
        local replaced = nil
        local ctx = base_ctx({
            scan_markdown_files = function()
                return { "vault/pessoa.md" }
            end,
            fs_io = {
                read_file = function(path)
                    if path ~= "vault/pessoa.md" then
                        return nil, "missing"
                    end
                    return table.concat({
                        "---",
                        "title: Pessoa",
                        "tags: [pessoa]",
                        "nascimento:",
                        "  day: 4",
                        "  month: 3",
                        "  year: 2005",
                        "óbito: false",
                        "---",
                        "# pessoa",
                    }, "\n")
                end,
            },
            frontmatter = require("nvim_obsidian.adapters.parser.frontmatter"),
            replace_catalog = function(notes)
                replaced = notes
                return true
            end,
        })

        local out = use_case.execute(ctx, { mode = "manual", event = nil })
        assert.is_true(out.ok)
        assert.is_not_nil(replaced)
        assert.equals(1, #replaced)
        assert.equals("Pessoa", replaced[1].title)
        assert.same({ "#pessoa" }, replaced[1].tags)
        assert.is_table(replaced[1].nascimento)
        assert.equals(3, replaced[1].nascimento.month)
        assert.is_false(replaced[1]["óbito"])
    end)
end)
