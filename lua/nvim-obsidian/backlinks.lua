local path = require("nvim-obsidian.path")

local M = {}

-- Dependency injection: store references to dependencies (default to real modules)
local _config = require("nvim-obsidian.config")

function M.search_current()
    local cfg = _config.get()
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
    local cfg = _config.get()
    require("telescope.builtin").live_grep({ cwd = cfg.vault_root })
end

--- Initialize backlinks module with optional dependency injection (for testing)
--- @param opts table Optional: { config = ... }
function M.init(opts)
    opts = opts or {}
    if opts.config then _config = opts.config end
end

return M
