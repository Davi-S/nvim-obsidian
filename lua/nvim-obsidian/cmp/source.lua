local source = {}

local path = require("nvim-obsidian.path")
local vault = require("nvim-obsidian.model.vault")
local config = require("nvim-obsidian.config")
local link_parser = require("nvim-obsidian.link.parser")

-- Dependency injection: store references to dependencies (default to real modules)
local _vault = vault
local _config = config

function source.new()
    return setmetatable({}, { __index = source })
end

function source:is_available()
    local cfg = _config.get()
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

    local inner = line:match("%[%[([^%]]*)$") or ""
    local parsed = link_parser.parse_wikilink(inner)
    if inner:find("#", 1, true) and parsed.note_ref and parsed.note_ref ~= "" then
        local items = {}
        local cfg = _config.get()
        local matches = _vault.resolve_by_title_or_alias(parsed.note_ref, cfg)
        for _, note in ipairs(matches) do
            if parsed.anchor_kind == "block" then
                for _, b in ipairs(note.blocks or {}) do
                    table.insert(items, {
                        label = note.title .. "#^" .. b.id,
                        insertText = note.title .. "#^" .. b.id .. "]]",
                        kind = 1,
                        documentation = note.relpath,
                    })
                end
            else
                for _, h in ipairs(note.headings or {}) do
                    table.insert(items, {
                        label = note.title .. "#" .. h.text,
                        insertText = note.title .. "#" .. h.text .. "]]",
                        kind = 1,
                        documentation = note.relpath,
                    })
                end
            end
        end

        callback({ items = items, isIncomplete = false })
        return
    end

    local items = {}
    for _, note in ipairs(_vault.all_notes()) do
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

--- Initialize source with optional dependency injection (for testing)
--- @param opts table Optional: { vault = ..., config = ... }
function source.init(opts)
    opts = opts or {}
    if opts.vault then _vault = opts.vault end
    if opts.config then _config = opts.config end
end

return source
