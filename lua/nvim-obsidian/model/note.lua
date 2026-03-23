local path = require("nvim-obsidian.path")

local Note = {}
Note.__index = Note

function Note.new(filepath, data)
    local self = setmetatable({}, Note)
    self.filepath = filepath
    self.filename = path.basename(filepath)
    self.title = path.stem(filepath)
    self.aliases = data.aliases or {}
    self.tags = data.tags or {}
    self.frontmatter = data.frontmatter or {}
    self.note_type = data.note_type or "standard"
    self.relpath = data.relpath
    return self
end

function Note:matches(query)
    if query == "" then
        return true
    end
    local q = vim.fn.tolower(query)
    if vim.fn.tolower(self.title):find(q, 1, true) then
        return true
    end
    for _, alias in ipairs(self.aliases) do
        if vim.fn.tolower(alias):find(q, 1, true) then
            return true
        end
    end
    return false
end

return Note
