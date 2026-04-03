---@diagnostic disable: undefined-global

local use_case = require("nvim_obsidian.use_cases.show_backlinks")

describe("show_backlinks use case", function()
    local function base_ctx(overrides)
        local opened = {}
        local disambiguation_payload = nil

        local contents = {
            ["vault/notes/other.md"] = "See [[Current Note]]",
            ["vault/notes/skip.md"] = "No backlinks here",
        }

        local ctx = {
            config = { vault_root = "vault" },
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "vault/notes/current.md", title = "Current Note", aliases = { "CN" } },
                        { path = "vault/notes/other.md",   title = "Other",        aliases = {} },
                    }
                end,
            },
            fs_io = {
                list_markdown_files = function()
                    return {
                        "vault/notes/current.md",
                        "vault/notes/other.md",
                        "vault/notes/skip.md",
                    }
                end,
                read_file = function(path)
                    return contents[path]
                end,
            },
            markdown = {
                extract_wikilinks = function(content)
                    if content == "See [[Current Note]]" then
                        return { { note_ref = "Current Note" } }
                    end
                    return {}
                end,
            },
            telescope = {
                open_disambiguation = function(payload)
                    disambiguation_payload = payload
                    return { action = "open", path = "vault/notes/other.md" }
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
            for k, v in pairs(overrides) do
                ctx[k] = v
            end
        end

        ctx._opened = opened
        ctx._payload = function()
            return disambiguation_payload
        end

        return ctx
    end

    it("returns invalid_input when buffer_path is missing", function()
        local out = use_case.execute(base_ctx(), {})

        assert.is_false(out.ok)
        assert.equals("invalid_input", out.error.code)
    end)

    it("returns not_found when current note is not indexed", function()
        local ctx = base_ctx({
            vault_catalog = {
                list_notes = function()
                    return {
                        { path = "vault/notes/other.md", title = "Other", aliases = {} },
                    }
                end,
            },
        })

        local out = use_case.execute(ctx, { buffer_path = "vault/notes/current.md" })

        assert.is_false(out.ok)
        assert.equals("not_found", out.error.code)
    end)

    it("returns zero matches when backlinks do not exist", function()
        local ctx = base_ctx({
            markdown = {
                extract_wikilinks = function()
                    return {}
                end,
            },
        })

        local out = use_case.execute(ctx, { buffer_path = "vault/notes/current.md" })

        assert.is_true(out.ok)
        assert.is_false(out.opened)
        assert.equals(0, out.match_count)
    end)

    it("opens selected backlink when picker returns open action", function()
        local ctx = base_ctx()

        local out = use_case.execute(ctx, { buffer_path = "vault/notes/current.md" })

        assert.is_true(out.ok)
        assert.is_true(out.opened)
        assert.equals(1, out.match_count)
        assert.equals("vault/notes/other.md", ctx._opened[1])

        local payload = ctx._payload()
        assert.equals("vault/notes/current.md", payload.buffer_path)
        assert.equals("Current Note", payload.target.note_ref)
    end)

    it("accepts direct-open disambiguation results from the picker", function()
        local ctx = base_ctx({
            telescope = {
                open_disambiguation = function(payload)
                    disambiguation_payload = payload
                    return { action = "opened", path = "vault/notes/other.md" }
                end,
            },
        })

        local out = use_case.execute(ctx, { buffer_path = "vault/notes/current.md" })

        assert.is_true(out.ok)
        assert.is_true(out.opened)
        assert.equals(1, out.match_count)
        assert.is_nil(ctx._opened[1])
    end)

    it("returns internal when selected backlink fails to open", function()
        local ctx = base_ctx({
            navigation = {
                open_path = function()
                    return false, "cannot-open"
                end,
            },
        })

        local out = use_case.execute(ctx, { buffer_path = "vault/notes/current.md" })

        assert.is_false(out.ok)
        assert.equals("internal", out.error.code)
    end)
end)
