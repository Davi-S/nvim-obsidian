---@diagnostic disable: undefined-global

describe("public setup api", function()
    local saved_bootstrap
    local saved_init
    local saved_vim

    before_each(function()
        saved_bootstrap = package.loaded["nvim_obsidian.app.bootstrap"]
        saved_init = package.loaded["nvim_obsidian"]
        saved_vim = _G.vim
    end)

    after_each(function()
        package.loaded["nvim_obsidian.app.bootstrap"] = saved_bootstrap
        package.loaded["nvim_obsidian"] = saved_init
        _G.vim = saved_vim
    end)

    it("returns cached container for repeated equal setup calls", function()
        local calls = 0
        local first_container = { id = "first" }

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                calls = calls + 1
                return first_container
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local one = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })
        local two = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })

        assert.equals(1, calls)
        assert.equals(one, two)
        assert.equals(first_container, one)
    end)

    it("restarts wiring when setup options change", function()
        local calls = 0

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                calls = calls + 1
                return { id = calls }
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local one = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault_a" })
        local two = api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault_b" })

        assert.equals(2, calls)
        assert.not_equals(one.id, two.id)
    end)

    it("errors when wiki_link_under_cursor is called before setup", function()
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local ok, err = pcall(function()
            api.wiki_link_under_cursor("[[Note]]", 2)
        end)

        assert.is_false(ok)
        assert.truthy(tostring(err):find("nvim-obsidian not initialized; call setup%(%) first"))
    end)

    it("delegates wiki_link_under_cursor to wiki_link parser with explicit args", function()
        local calls = {}

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                return {
                    wiki_link = {
                        parse_at_cursor = function(line, col)
                            table.insert(calls, { line = line, col = col })
                            return {
                                target = { note_ref = "Note" },
                                error = nil,
                            }
                        end,
                    },
                }
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })

        local result = api.wiki_link_under_cursor("hello [[Note]] world", 9)

        assert.equals(1, #calls)
        assert.equals("hello [[Note]] world", calls[1].line)
        assert.equals(9, calls[1].col)
        assert.equals("Note", result.target.note_ref)
    end)

    it("uses current cursor context when wiki_link_under_cursor args are omitted", function()
        local calls = {}

        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                return {
                    wiki_link = {
                        parse_at_cursor = function(line, col)
                            table.insert(calls, { line = line, col = col })
                            return { target = nil, error = nil }
                        end,
                    },
                }
            end,
        }

        _G.vim = _G.vim or {}
        _G.vim.api = _G.vim.api or {}
        rawset(_G.vim.api, "nvim_get_current_line", function()
            return "prefix [[FromCursor]] suffix"
        end)
        rawset(_G.vim.api, "nvim_win_get_cursor", function(_)
            return { 1, 10 }
        end)

        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        api.setup({ vault_root = "/tmp/nvim_obsidian_api_vault" })
        api.wiki_link_under_cursor()

        assert.equals(1, #calls)
        assert.equals("prefix [[FromCursor]] suffix", calls[1].line)
        assert.equals(11, calls[1].col)
    end)

    it("errors when is_inside_vault is called before setup", function()
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local ok, err = pcall(function()
            api.is_inside_vault("/tmp/some/path")
        end)

        assert.is_false(ok)
        assert.truthy(tostring(err):find("nvim-obsidian not initialized; call setup%(%) first"))
    end)

    it("returns true only when explicit path is inside configured vault", function()
        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                return {
                    config = {
                        vault_root = "/vault",
                    },
                }
            end,
        }
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        api.setup({ vault_root = "/vault" })

        assert.is_true(api.is_inside_vault("/vault/notes/a.md"))
        assert.is_true(api.is_inside_vault("/vault"))
        assert.is_false(api.is_inside_vault("/outside/notes/a.md"))
    end)

    it("falls back to current buffer path, then cwd, when is_inside_vault path is omitted", function()
        package.loaded["nvim_obsidian.app.bootstrap"] = {
            start = function()
                return {
                    config = {
                        vault_root = "/vault",
                    },
                }
            end,
        }

        _G.vim = _G.vim or {}
        _G.vim.fn = _G.vim.fn or {}
        rawset(_G.vim.fn, "expand", function(_)
            return "/vault/current.md"
        end)
        rawset(_G.vim.fn, "getcwd", function()
            return "/outside"
        end)

        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        api.setup({ vault_root = "/vault" })
        assert.is_true(api.is_inside_vault())

        rawset(_G.vim.fn, "expand", function(_)
            return ""
        end)
        rawset(_G.vim.fn, "getcwd", function()
            return "/outside"
        end)
        assert.is_false(api.is_inside_vault())
    end)

    it("exposes journal.month_name and journal.weekday_name helpers", function()
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")

        assert.equals("March", api.journal.month_name(3, "en-US"))
        assert.equals("março", api.journal.month_name(3, "pt-BR"))
        assert.equals("Friday", api.journal.weekday_name(6, "en-US"))
        assert.equals("sexta-feira", api.journal.weekday_name(6, "pt-BR"))
    end)

    it("exposes journal.parse_month_token helper", function()
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")

        assert.equals(3, api.journal.parse_month_token("março", "pt-BR"))
        assert.equals(3, api.journal.parse_month_token("marco", "pt-BR"))
        assert.equals(3, api.journal.parse_month_token("March", "en-US"))
        assert.equals(10, api.journal.parse_month_token("10", "en-US"))
        assert.is_nil(api.journal.parse_month_token("not-a-month", "en-US"))
    end)

    it("exposes journal.render_title helper", function()
        package.loaded["nvim_obsidian"] = nil

        local api = require("nvim_obsidian")
        local rendered = api.journal.render_title("{{year}} {{month_name}} {{day2}}", {
            year = 2026,
            month = 3,
            day = 28,
        }, "pt-BR")

        assert.equals("2026 março 28", rendered)
    end)
end)
