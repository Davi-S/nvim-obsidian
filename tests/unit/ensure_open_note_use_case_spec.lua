---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.ensure_open_note")

describe("ensure_open_note use case", function()
    local function base_ctx(overrides)
        local opened = {}
        local writes = {}

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
            journal = {
                classify_input = function(_raw)
                    return { kind = "none" }
                end,
            },
            template = {
                render = function(content)
                    return { rendered = content, unresolved = {} }
                end,
            },
            resolve_template_content = function()
                return nil
            end,
            vault_catalog = {
                find_by_identity_token = function(_token)
                    return { matches = {} }
                end,
                upsert_note = function(_note)
                    return { ok = true, error = nil }
                end,
            },
            fs_io = {
                write_file = function(path, content)
                    table.insert(writes, { path = path, content = content })
                    return true
                end,
            },
            navigation = {
                open_path = function(path)
                    table.insert(opened, path)
                    return true
                end,
            },
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                ctx[key] = value
            end
        end

        ctx._opened = opened
        ctx._writes = writes
        return ctx
    end

    it("opens existing note when single match is found", function()
        local ctx = base_ctx({
            vault_catalog = {
                find_by_identity_token = function()
                    return {
                        matches = {
                            { path = "notes/existing.md", title = "existing", aliases = {} },
                        },
                    }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "existing",
            create_if_missing = true,
            origin = "omni",
        })

        assert.is_true(out.ok)
        assert.is_false(out.created)
        assert.equals("notes/existing.md", out.path)
        assert.equals(1, #ctx._opened)
        assert.equals(0, #ctx._writes)
    end)

    it("returns ambiguous_target when multiple matches are found", function()
        local ctx = base_ctx({
            vault_catalog = {
                find_by_identity_token = function()
                    return {
                        matches = {
                            { path = "a/foo.md" },
                            { path = "b/foo.md" },
                        },
                    }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "foo",
            create_if_missing = true,
            origin = "link",
        })

        assert.is_false(out.ok)
        assert.is_not_nil(out.error)
        assert.equals("ambiguous_target", out.error.code)
    end)

    it("returns not_found when creation is disabled", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, {
            title_or_token = "missing",
            create_if_missing = false,
            origin = "omni",
        })

        assert.is_false(out.ok)
        assert.equals("not_found", out.error.code)
    end)

    it("creates in journal subdir for journal origin", function()
        local ctx = base_ctx({
            journal = {
                classify_input = function()
                    return { kind = "daily" }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "2026-03-28",
            create_if_missing = true,
            origin = "journal",
        })

        assert.is_true(out.ok)
        assert.is_true(out.created)
        assert.equals("journal/daily/2026-03-28.md", out.path)
        assert.equals("journal/daily/2026-03-28.md", ctx._writes[1].path)
        assert.equals("journal/daily/2026-03-28.md", ctx._opened[1])
    end)

    it("uses explicit journal_kind when localized title cannot be classified", function()
        local ctx = base_ctx({
            journal = {
                classify_input = function()
                    return { kind = "none" }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "2026 março 29, domingo",
            create_if_missing = true,
            origin = "journal",
            journal_kind = "daily",
        })

        assert.is_true(out.ok)
        assert.is_true(out.created)
        assert.equals("journal/daily/2026 março 29, domingo.md", out.path)
        assert.equals("journal/daily/2026 março 29, domingo.md", ctx._writes[1].path)
        assert.equals("journal/daily/2026 março 29, domingo.md", ctx._opened[1])
    end)

    it("preserves provided journal token for adjacent navigation targets", function()
        local ctx = base_ctx({
            journal = {
                classify_input = function()
                    return { kind = "none" }
                end,
            },
            resolve_journal_title = function()
                return "today-title"
            end,
        })

        local out = use_case.execute(ctx, {
            title_or_token = "tomorrow-title",
            create_if_missing = true,
            origin = "journal",
            journal_kind = "daily",
            now = os.time(),
        })

        assert.is_true(out.ok)
        assert.is_true(out.created)
        assert.equals("journal/daily/tomorrow-title.md", out.path)
        assert.equals("journal/daily/tomorrow-title.md", ctx._writes[1].path)
        assert.equals("journal/daily/tomorrow-title.md", ctx._opened[1])
    end)

    it("creates in default subdir for non-journal origin", function()
        local ctx = base_ctx({
            journal = {
                classify_input = function()
                    return { kind = "daily" }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "my note",
            create_if_missing = true,
            origin = "omni",
        })

        assert.is_true(out.ok)
        assert.equals("notes/my-note.md", out.path)
    end)

    it("renders configured template content before write", function()
        local ctx = base_ctx({
            resolve_template_content = function()
                return "# {{title}}"
            end,
            template = {
                render = function(_content, context)
                    return {
                        rendered = "# " .. context.note.title,
                        unresolved = {},
                    }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "Alpha",
            create_if_missing = true,
            origin = "omni",
        })

        assert.is_true(out.ok)
        assert.equals("# Alpha", ctx._writes[1].content)
    end)

    it("returns internal when write fails", function()
        local ctx = base_ctx({
            fs_io = {
                write_file = function()
                    return false, "disk-full"
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "Alpha",
            create_if_missing = true,
            origin = "omni",
        })

        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)

    it("passes canonical nested template context when creating notes", function()
        local captured_ctx = nil
        local ctx = base_ctx({
            config = {
                vault_root = "/vault",
                locale = "pt-BR",
                new_notes_subdir = "notes",
                journal = {
                    daily = { subdir = "journal/daily" },
                },
            },
            resolve_template_content = function()
                return "# {{title}}"
            end,
            template = {
                render = function(_content, context)
                    captured_ctx = context
                    return { rendered = "# ok", unresolved = {} }
                end,
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "Alpha",
            create_if_missing = true,
            origin = "omni",
            now = 1700000000,
        })

        assert.is_true(out.ok)
        assert.is_table(captured_ctx)

        assert.is_table(captured_ctx.meta)
        assert.equals("omni_create", captured_ctx.meta.origin)

        assert.is_table(captured_ctx.time)
        assert.equals(1700000000, captured_ctx.time.now_ts)
        assert.is_truthy(captured_ctx.time.iso_week)

        assert.is_table(captured_ctx.note)
        assert.equals("note", captured_ctx.note.kind)
        assert.equals("Alpha", captured_ctx.note.title)
        assert.equals("/vault/notes/Alpha.md", captured_ctx.note.path)
        assert.is_table(captured_ctx.note.yaml)

        assert.is_table(captured_ctx.config)
        assert.equals("/vault", captured_ctx.config.vault_root)
    end)

    it("anchors relative new_notes_subdir to vault_root", function()
        local ctx = base_ctx({
            config = {
                vault_root = "/vault",
                new_notes_subdir = "notes",
                journal = {
                    daily = { subdir = "journal/daily" },
                },
            },
        })

        local out = use_case.execute(ctx, {
            title_or_token = "outside routing test",
            create_if_missing = true,
            origin = "omni",
        })

        assert.is_true(out.ok)
        assert.equals("/vault/notes/outside-routing-test.md", out.path)
        assert.equals("/vault/notes/outside-routing-test.md", ctx._writes[1].path)
    end)
end)
