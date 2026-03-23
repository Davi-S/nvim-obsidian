local path = require("nvim-obsidian.path")

local M = {}

function M.search_current()
    local cfg = require("nvim-obsidian.config").get()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("nvim-obsidian: buffer has no file", vim.log.levels.WARN)
        return
    end
    local title = path.stem(file)
    local p1 = "\\[\\[" .. vim.fn.escape(title, "\\") .. "\\]\\]"
    local p2 = "\\[\\[" .. vim.fn.escape(title, "\\") .. "\\|"

    require("telescope.builtin").live_grep({
        cwd = cfg.vault_root,
        default_text = p1 .. "|" .. p2,
        additional_args = function()
            return { "--pcre2" }
        end,
    })
end

function M.global_search()
    local cfg = require("nvim-obsidian.config").get()
    require("telescope.builtin").live_grep({ cwd = cfg.vault_root })
end

return M
