---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.follow_link")

describe("follow_link use case", function()
    local function base_ctx(overrides)
        local opened = {}
        local jumped = {}
        local warned = {}

        local ctx = {
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Target]]",
                            note_ref = "Target",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function(_target, _candidate_notes)
                    return {
                        status = "resolved",
                        resolved_path = "notes/target.md",
                        ambiguous_matches = nil,
                    }
                end,
            },
            vault_catalog = {
                find_by_identity_token = function()
                    return {
                        matches = {
                            { path = "notes/target.md", title = "Target", aliases = {} },
                        },
                    }
                end,
            },
            ensure_open_note = {
                execute = function()
                    return { ok = true, path = "notes/target.md", created = true, error = nil }
                end,
            },
            navigation = {
                open_path = function(path)
                    table.insert(opened, path)
                    return true
                end,
                jump_to_anchor = function(target)
                    table.insert(jumped, target)
                    return true
                end,
            },
            notifications = {
                warn = function(msg)
                    table.insert(warned, msg)
                end,
            },
            open_disambiguation_picker = function()
                return { action = "cancel" }
            end,
            anchor_exists = function()
                return true
            end,
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                ctx[key] = value
            end
        end

        ctx._opened = opened
        ctx._jumped = jumped
        ctx._warned = warned
        return ctx
    end

    local function run(ctx, input)
        return use_case.execute(ctx, input or {
            line = "[[Target]]",
            col = 4,
            buffer_path = "notes/current.md",
        })
    end

    it("returns invalid no-op when cursor is not on wikilink", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return { target = nil, error = nil }
                end,
                resolve_target = function()
                    error("should not be called")
                end,
            },
        })

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("invalid", out.status)
        assert.equals(0, #ctx._opened)
    end)

    it("opens resolved link target", function()
        local ctx = base_ctx()

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("opened", out.status)
        assert.equals("notes/target.md", ctx._opened[1])
    end)

    it("creates missing target via ensure_open_note", function()
        local ensure_called = false
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Missing]]",
                            note_ref = "Missing",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return { status = "missing", resolved_path = nil, ambiguous_matches = nil }
                end,
            },
            ensure_open_note = {
                execute = function(_ctx, input)
                    ensure_called = true
                    assert.equals("Missing", input.title_or_token)
                    assert.is_true(input.create_if_missing)
                    assert.equals("link", input.origin)
                    return { ok = true, path = "notes/missing.md", created = true, error = nil }
                end,
            },
        })

        local out = run(ctx, {
            line = "[[Missing]]",
            col = 4,
            buffer_path = "notes/current.md",
        })

        assert.is_true(ensure_called)
        assert.is_true(out.ok)
        assert.equals("created", out.status)
    end)

    it("returns ambiguous status for ambiguous resolution", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Foo]]",
                            note_ref = "Foo",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return {
                        status = "ambiguous",
                        resolved_path = nil,
                        ambiguous_matches = {
                            { path = "a/foo.md" },
                            { path = "b/foo.md" },
                        },
                    }
                end,
            },
        })

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("ambiguous", out.status)
        assert.equals(1, #ctx._warned)
    end)

    it("opens selected target from disambiguation picker", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Foo]]",
                            note_ref = "Foo",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return {
                        status = "ambiguous",
                        resolved_path = nil,
                        ambiguous_matches = {
                            { path = "a/foo.md" },
                            { path = "b/foo.md" },
                        },
                    }
                end,
            },
            open_disambiguation_picker = function()
                return { path = "b/foo.md" }
            end,
        })

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("opened", out.status)
        assert.equals("b/foo.md", ctx._opened[1])
    end)

    it("returns invalid when ambiguous target has no disambiguation picker", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Foo]]",
                            note_ref = "Foo",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return {
                        status = "ambiguous",
                        resolved_path = nil,
                        ambiguous_matches = {
                            { path = "a/foo.md" },
                            { path = "b/foo.md" },
                        },
                    }
                end,
            },
            pick_ambiguous_target = false,
            open_disambiguation_picker = false,
            telescope = false,
        })

        local out = run(ctx)
        assert.is_false(out.ok)
        assert.equals("invalid", out.status)
        assert.equals("invalid_input", out.error.code)
    end)

    it("returns missing_anchor when heading or block target is absent", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Target#Heading]]",
                            note_ref = "Target",
                            anchor = "Heading",
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return {
                        status = "resolved",
                        resolved_path = "notes/target.md",
                        ambiguous_matches = nil,
                    }
                end,
            },
            anchor_exists = function()
                return false
            end,
        })

        local out = run(ctx, {
            line = "[[Target#Heading]]",
            col = 10,
            buffer_path = "notes/current.md",
        })

        assert.is_true(out.ok)
        assert.equals("missing_anchor", out.status)
        assert.equals("notes/target.md", ctx._opened[1])
        assert.equals(1, #ctx._warned)
    end)

    it("propagates ensure_open_note failure for missing target", function()
        local ctx = base_ctx({
            wiki_link = {
                parse_at_cursor = function()
                    return {
                        target = {
                            raw = "[[Missing]]",
                            note_ref = "Missing",
                            anchor = nil,
                            block_id = nil,
                            display_alias = nil,
                        },
                        error = nil,
                    }
                end,
                resolve_target = function()
                    return { status = "missing", resolved_path = nil, ambiguous_matches = nil }
                end,
            },
            ensure_open_note = {
                execute = function()
                    return {
                        ok = false,
                        path = nil,
                        created = nil,
                        error = { code = "internal", message = "failed" },
                    }
                end,
            },
        })

        local out = run(ctx)
        assert.is_false(out.ok)
        assert.equals("invalid", out.status)
        assert.equals("internal", out.error.code)
    end)
end)
