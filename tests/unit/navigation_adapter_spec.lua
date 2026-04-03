---@diagnostic disable: undefined-global

local navigation = require("nvim_obsidian.adapters.neovim.navigation")

describe("neovim navigation adapter", function()
    local original_api = {}

    local function patch_api(overrides)
        _G.vim = _G.vim or {}
        _G.vim.api = _G.vim.api or {}

        local names = {
            "nvim_get_current_buf",
            "nvim_buf_get_lines",
            "nvim_get_current_win",
            "nvim_win_set_cursor",
        }

        for _, name in ipairs(names) do
            original_api[name] = _G.vim.api[name]
        end

        for name, fn in pairs(overrides or {}) do
            _G.vim.api[name] = fn
        end
    end

    local function restore_api()
        if not _G.vim or not _G.vim.api then
            return
        end
        for name, fn in pairs(original_api) do
            _G.vim.api[name] = fn
        end
    end

    after_each(function()
        restore_api()
    end)

    it("jumps to block id line when exact block exists", function()
        local cursor = nil
        patch_api({
            nvim_get_current_buf = function()
                return 11
            end,
            nvim_buf_get_lines = function()
                return {
                    "- [ ] done ^cafde5",
                    "- [ ] another ^cafde5-extra",
                }
            end,
            nvim_get_current_win = function()
                return 22
            end,
            nvim_win_set_cursor = function(_, pos)
                cursor = pos
            end,
        })

        local ok, err = navigation.jump_to_anchor({ block_id = "cafde5" })
        assert.is_true(ok)
        assert.is_nil(err)
        assert.same({ 1, 0 }, cursor)
    end)

    it("does not match block id prefixes", function()
        patch_api({
            nvim_get_current_buf = function()
                return 11
            end,
            nvim_buf_get_lines = function()
                return {
                    "- [ ] done ^cafde5x",
                    "- [ ] done ^cafde5_extra",
                    "- [ ] done ^cafde5-extra",
                }
            end,
            nvim_get_current_win = function()
                return 22
            end,
            nvim_win_set_cursor = function()
                error("should not move cursor when block is not found")
            end,
        })

        local ok, err = navigation.jump_to_anchor({ block_id = "cafde5" })
        assert.is_false(ok)
        assert.is_table(err)
        assert.equals("not_found", err.code)
    end)
end)
