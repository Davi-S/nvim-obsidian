---@diagnostic disable: undefined-global

local config = require("nvim_obsidian.app.config")

describe("app config schema", function()
    it("requires vault_root", function()
        local ok, err = pcall(config.normalize, {})
        assert.is_false(ok)
        assert.matches("vault_root is required", tostring(err))
    end)

    it("requires absolute vault_root", function()
        local ok, err = pcall(config.normalize, {
            vault_root = "relative/path",
        })
        assert.is_false(ok)
        assert.matches("vault_root must be an absolute path", tostring(err))
    end)

    it("applies phase-8 defaults deterministically", function()
        local opts = config.normalize({
            vault_root = "/tmp/nvim_obsidian_vault",
        })

        assert.equals("warn", opts.log_level)
        assert.equals("en-US", opts.locale)
        assert.equals("<S-CR>", opts.force_create_key)
        assert.equals("/tmp/nvim_obsidian_vault", opts.new_notes_subdir)
        assert.equals(true, opts.dataview.enabled)
        assert.same({ "on_open", "on_save" }, opts.dataview.render.when)
        assert.equals("event", opts.dataview.render.scope)
        assert.same({ "*.md" }, opts.dataview.render.patterns)
        assert.equals("below_block", opts.dataview.placement)
        assert.equals(true, opts.dataview.messages.task_no_results.enabled)
        assert.equals("Dataview: No results to show for task query.", opts.dataview.messages.task_no_results.text)
    end)

    it("does not mutate caller input tables", function()
        local user = {
            vault_root = "/tmp/nvim_obsidian_vault",
            dataview = {
                render = {
                    when = { "on_save" },
                },
            },
        }

        local before = vim.deepcopy(user)
        local _ = config.normalize(user)
        assert.same(before, user)
    end)
end)
