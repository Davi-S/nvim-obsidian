---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.search_open_create")

describe("search_open_create use case", function()
    local function base_ctx(overrides)
        local picker_payload = nil
        local ensured = {}

        local ctx = {
            config = {
                omni = {
                    display_separator = "->",
                },
            },
            search_ranking = {
                score_candidates = function(query, candidates)
                    local ranked = {}
                    for i, candidate in ipairs(candidates) do
                        table.insert(ranked, {
                            candidate = candidate,
                            rank = i + 3,
                        })
                    end
                    return { ranked = ranked }
                end,
                select_display = function(_query, candidate, separator)
                    return { label = tostring(candidate.title) .. " " .. separator .. " " .. tostring(candidate.relpath) }
                end,
            },
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "notes/alpha.md", title = "Alpha", aliases = { "A" } },
                        { path = "notes/beta.md",  title = "Beta",  aliases = {} },
                    }
                end,
            },
            ensure_open_note = {
                execute = function(_ctx, input)
                    table.insert(ensured, input)
                    return {
                        ok = true,
                        path = input.title_or_token == "Gamma" and "notes/gamma.md" or input.title_or_token,
                        created = input.create_if_missing,
                        error = nil,
                    }
                end,
            },
            journal = {
                classify_input = function(_raw)
                    return { kind = "none" }
                end,
            },
            open_omni_picker = function(payload)
                picker_payload = payload
                return {
                    action = "cancel",
                }
            end,
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                ctx[key] = value
            end
        end

        ctx._picker_payload = function()
            return picker_payload
        end
        ctx._ensured = ensured
        return ctx
    end

    local function run(ctx, input)
        return use_case.execute(ctx, input or {
            query = "al",
            allow_force_create = true,
        })
    end

    it("returns cancelled when picker cancels", function()
        local ctx = base_ctx()

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("cancelled", out.action)

        local payload = ctx._picker_payload()
        assert.equals("al", payload.query)
        assert.equals(true, payload.allow_create)
        assert.equals(true, payload.allow_force_create)
        assert.equals(2, #payload.items)
    end)

    it("opens selected existing candidate through ensure_open_note", function()
        local ctx = base_ctx({
            open_omni_picker = function(_payload)
                return {
                    action = "open",
                    item = {
                        candidate = {
                            path = "notes/alpha.md",
                            title = "Alpha",
                        },
                    },
                }
            end,
        })

        local out = run(ctx)
        assert.is_true(out.ok)
        assert.equals("opened", out.action)
        assert.equals("notes/alpha.md", out.path)
        assert.equals(false, ctx._ensured[1].create_if_missing)
        assert.equals("omni", ctx._ensured[1].origin)
    end)

    it("creates when no exact/full match exists and picker requests create", function()
        local ctx = base_ctx({
            open_omni_picker = function(_payload)
                return {
                    action = "create",
                    query = "Gamma",
                }
            end,
        })

        local out = run(ctx, {
            query = "Gam",
            allow_force_create = true,
        })

        assert.is_true(out.ok)
        assert.equals("created", out.action)
        assert.equals("notes/gamma.md", out.path)
        assert.equals(true, ctx._ensured[1].create_if_missing)
        assert.equals("Gamma", ctx._ensured[1].title_or_token)
    end)

    it("routes omni create through journal origin when classifier matches", function()
        local ctx = base_ctx({
            journal = {
                classify_input = function(_raw)
                    return { kind = "daily" }
                end,
            },
            open_omni_picker = function(_payload)
                return {
                    action = "create",
                    query = "2026-03-28",
                }
            end,
        })

        local out = run(ctx, {
            query = "2026-03",
            allow_force_create = true,
        })

        assert.is_true(out.ok)
        assert.equals("created", out.action)
        assert.equals("journal", ctx._ensured[1].origin)
    end)

    it("forbids create when exact/full match exists", function()
        local ctx = base_ctx({
            search_ranking = {
                score_candidates = function(_query, candidates)
                    return {
                        ranked = {
                            { candidate = candidates[1], rank = 3 },
                        },
                    }
                end,
                select_display = function(_query, candidate)
                    return { label = candidate.title }
                end,
            },
            open_omni_picker = function(_payload)
                return { action = "create", query = "Alpha" }
            end,
        })

        local out = run(ctx, {
            query = "Alpha",
            allow_force_create = true,
        })

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("propagates ensure_open_note failure", function()
        local ctx = base_ctx({
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
            open_omni_picker = function(_payload)
                return {
                    action = "open",
                    item = {
                        candidate = {
                            path = "notes/alpha.md",
                            title = "Alpha",
                        },
                    },
                }
            end,
        })

        local out = run(ctx)
        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)

    it("disables force-create option in picker when allow_force_create is false", function()
        local ctx = base_ctx()

        local out = run(ctx, {
            query = "al",
            allow_force_create = false,
        })

        assert.is_true(out.ok)
        assert.equals("cancelled", out.action)
        assert.equals(false, ctx._picker_payload().allow_force_create)
    end)

    it("uses vault-relative relpath in picker candidates", function()
        local ctx = base_ctx({
            config = {
                vault_root = "/vault",
                omni = {
                    display_separator = "->",
                },
            },
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "/vault/notes/alpha.md", title = "Alpha", aliases = {} },
                    }
                end,
            },
        })

        local out = run(ctx, {
            query = "al",
            allow_force_create = true,
        })

        assert.is_true(out.ok)
        assert.equals("cancelled", out.action)

        local payload = ctx._picker_payload()
        assert.equals("notes/alpha.md", payload.items[1].candidate.relpath)
        assert.equals("/vault/notes/alpha.md", payload.items[1].candidate.path)
    end)

    it("prunes stale deleted notes from catalog before ranking", function()
        local path = "/tmp/nvim_obsidian_stale_omni_note.md"
        local wrote = io.open(path, "w")
        assert.is_not_nil(wrote)
        wrote:write("# temp")
        wrote:close()

        local removed = {}
        local picker_payload = nil
        local ctx = base_ctx({
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = path, title = "Temp", aliases = {} },
                    }
                end,
                remove_note = function(p)
                    table.insert(removed, p)
                    return { ok = true }
                end,
            },
            open_omni_picker = function(payload)
                picker_payload = payload
                return {
                    action = "cancel",
                }
            end,
        })

        os.remove(path)

        local out = run(ctx, {
            query = "Temp",
            allow_force_create = true,
        })

        assert.is_true(out.ok)
        assert.equals("cancelled", out.action)
        assert.equals(1, #removed)
        assert.equals(path, removed[1])
        assert.is_not_nil(picker_payload)
        assert.equals(0, #picker_payload.items)
    end)
end)
