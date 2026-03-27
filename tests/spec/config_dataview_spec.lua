local config = require("nvim-obsidian.config")

describe("dataview config validation", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    it("uses first-wave defaults", function()
        local cfg = config.resolve({ vault_root = root })
        assert.is_true(cfg.dataview.enabled)
        assert.are.same({ "on_open", "on_save" }, cfg.dataview.render.when)
        assert.are.equal("event", cfg.dataview.render.scope)
        assert.are.same({ "*.md" }, cfg.dataview.render.patterns)
        assert.are.equal("below_block", cfg.dataview.placement)
        assert.is_true(cfg.dataview.messages.task_no_results.enabled)
    end)

    it("rejects invalid render.when options", function()
        local ok, err = pcall(function()
            config.resolve({
                vault_root = root,
                dataview = {
                    render = {
                        when = { "on_magic" },
                    },
                },
            })
        end)
        assert.is_false(ok)
        assert.is_true((err or ""):find("dataview.render.when", 1, true) ~= nil)
    end)

    it("rejects invalid render.scope", function()
        local ok, err = pcall(function()
            config.resolve({
                vault_root = root,
                dataview = {
                    render = {
                        scope = "all_windows",
                    },
                },
            })
        end)
        assert.is_false(ok)
        assert.is_true((err or ""):find("dataview.render.scope", 1, true) ~= nil)
    end)
end)
