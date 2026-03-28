---@diagnostic disable: undefined-global

local notifications = require("nvim_obsidian.adapters.neovim.notifications")

describe("notification adapter", function()
    local original_vim

    before_each(function()
        original_vim = _G.vim
    end)

    after_each(function()
        _G.vim = original_vim
    end)

    local function build_vim_mock(calls)
        return {
            notify = function(message, level, opts)
                table.insert(calls, {
                    message = message,
                    level = level,
                    opts = opts,
                })
            end,
            log = {
                levels = {
                    ERROR = 1,
                    WARN = 2,
                    INFO = 3,
                },
            },
        }
    end

    it("should export create_notifier", function()
        assert.is_function(notifications.create_notifier)
    end)

    it("should create notifier with expected shape", function()
        local notifier = notifications.create_notifier({})

        assert.equals("neovim_notifications", notifier.display_name)
        assert.is_function(notifier.notify)
        assert.is_function(notifier.info)
        assert.is_function(notifier.warn)
        assert.is_function(notifier.error)
    end)

    it("should emit info notifications", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "info" },
        })

        notifier.info("hello")

        assert.equals(1, #calls)
        assert.equals("hello", calls[1].message)
        assert.equals(3, calls[1].level)
    end)

    it("should emit warning notifications", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "warn" },
        })

        notifier.warn("careful")

        assert.equals(1, #calls)
        assert.equals("careful", calls[1].message)
        assert.equals(2, calls[1].level)
    end)

    it("should emit error notifications", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "error" },
        })

        notifier.error("boom")

        assert.equals(1, #calls)
        assert.equals("boom", calls[1].message)
        assert.equals(1, calls[1].level)
    end)

    it("should include title option by default", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "info" },
        })

        notifier.info("msg")

        assert.equals("nvim-obsidian", calls[1].opts.title)
    end)

    it("should suppress info when log_level is warn", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "warn" },
        })

        notifier.info("hidden")

        assert.equals(0, #calls)
    end)

    it("should allow warn when log_level is warn", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "warn" },
        })

        notifier.warn("visible")

        assert.equals(1, #calls)
        assert.equals("visible", calls[1].message)
    end)

    it("should format structured notification payload", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "info" },
        })

        notifier.warn({
            command = "ObsidianFollow",
            message = "Anchor not found",
            target = "notes/target.md#missing",
            next_step = "Check heading and retry",
        })

        assert.equals(1, #calls)
        assert.equals(
            "[ObsidianFollow] Anchor not found | target: notes/target.md#missing | next: Check heading and retry",
            calls[1].message
        )
    end)

    it("should ignore blank notification messages", function()
        local calls = {}
        local notifier = notifications.create_notifier({
            vim = build_vim_mock(calls),
            config = { log_level = "info" },
        })

        notifier.warn("")
        notifier.warn({ command = "ObsidianReindex" })

        assert.equals(0, #calls)
    end)

    it("should be safe when vim.notify is missing", function()
        local notifier = notifications.create_notifier({
            vim = {
                log = {
                    levels = {
                        ERROR = 1,
                        WARN = 2,
                        INFO = 3,
                    },
                },
            },
            config = { log_level = "info" },
        })

        assert.has_no.errors(function()
            notifier.error("still safe")
        end)
    end)

    it("should expose compatibility helpers at module root", function()
        local calls = {}
        _G.vim = build_vim_mock(calls)

        notifications.info("root info")
        notifications.warn("root warn")
        notifications.error("root error")

        assert.equals(3, #calls)
        assert.equals("root info", calls[1].message)
        assert.equals("root warn", calls[2].message)
        assert.equals("root error", calls[3].message)
    end)
end)
