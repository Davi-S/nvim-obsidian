---@diagnostic disable: undefined-global

local M = {}

local function create_user_command(name, fn, opts)
    if not vim or not vim.api or not vim.api.nvim_create_user_command then
        return
    end
    vim.api.nvim_create_user_command(name, fn, opts or {})
end

function M.register(container)
    create_user_command("ObsidianHealth", function()
        if container and container.adapters and container.adapters.notifications then
            container.adapters.notifications.info("nvim-obsidian skeleton loaded")
        end
    end, { desc = "nvim-obsidian Phase 2 health command" })
end

return M
