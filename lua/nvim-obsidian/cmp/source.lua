local source = {}

local path = require("nvim-obsidian.path")
local vault = require("nvim-obsidian.model.vault")
local config = require("nvim-obsidian.config")

function source.new()
    return setmetatable({}, { __index = source })
end

function source:is_available()
    local cfg = config.get()
    if not cfg then
        return false
    end
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        return false
    end
    return vim.bo.filetype == "markdown" and path.is_inside(cfg.vault_root, file)
end

function source:get_trigger_characters()
    return { "[" }
end

function source:complete(params, callback)
    local line = params.context.cursor_before_line
    if not line:match("%[%[[^%]]*$") then
        callback({ items = {}, isIncomplete = false })
        return
    end

    local items = {}
    for _, note in ipairs(vault.all_notes()) do
        table.insert(items, {
            label = note.title,
            insertText = note.title .. "]]",
            kind = 1,
            documentation = note.relpath,
        })
        for _, alias in ipairs(note.aliases) do
            table.insert(items, {
                label = note.title .. " | " .. alias,
                insertText = note.title .. "|" .. alias .. "]]",
                kind = 1,
                documentation = note.relpath,
            })
        end
    end

    callback({ items = items, isIncomplete = false })
end

function source:resolve(completion_item, callback)
    callback(completion_item)
end

function source:execute(completion_item, callback)
    callback(completion_item)
end

return source
