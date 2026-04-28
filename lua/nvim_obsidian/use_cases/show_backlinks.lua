local errors = require("nvim_obsidian.core.shared.errors")

---Use-case: list and navigate backlinks to current note.
---
---Builds backlinks by scanning markdown references and routes selection through
---picker/navigation adapters.
local M = {}

M.contract = {
    name = "show_backlinks",
    version = "phase3-contract",
    dependencies = {
        "vault_catalog",
        "filesystem.io",
        "parser.markdown",
        "picker.telescope",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        buffer_path = "string",
    },
    output = {
        ok = "boolean",
        opened = "boolean|nil",
        match_count = "integer|nil",
        error = "domain_error|nil",
    },
}

---@param path any
---@return string
local function basename(path)
    local p = tostring(path or ""):gsub("\\", "/")
    return p:match("[^/]+$") or p
end

---Execute backlinks discovery and navigation flow.
---@param _ctx table
---@param _input table
---@return table
function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if type(_input) ~= "table" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local ctx = _ctx
    local input = _input

    if type(input.buffer_path) ~= "string" or input.buffer_path == "" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "buffer_path must be a non-empty string"),
        }
    end

    local vault_catalog = ctx.vault_catalog
    local fs_io = ctx.fs_io
    local markdown = ctx.markdown
    local telescope = ctx.telescope
    local navigation = ctx.navigation

    if type(vault_catalog) ~= "table" or type(vault_catalog.list_notes) ~= "function" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog.list_notes is required"),
        }
    end

    if type(fs_io) ~= "table" or type(fs_io.list_markdown_files) ~= "function" or type(fs_io.read_file) ~= "function" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.fs_io list/read functions are required"),
        }
    end

    if type(markdown) ~= "table" or type(markdown.extract_wikilinks) ~= "function" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.markdown.extract_wikilinks is required"),
        }
    end

    if type(telescope) ~= "table" or type(telescope.open_disambiguation) ~= "function" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.telescope.open_disambiguation is required"),
        }
    end

    if type(navigation) ~= "table" or type(navigation.open_path) ~= "function" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.navigation.open_path is required"),
        }
    end

    local notes = vault_catalog.list_notes()
    if type(notes) ~= "table" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INTERNAL, "vault_catalog.list_notes returned invalid result"),
        }
    end
    local by_path = {}
    local current_note = nil
    for _, note in ipairs(notes) do
        if type(note) == "table" and type(note.path) == "string" then
            by_path[note.path] = note
            if note.path == input.buffer_path then
                current_note = note
            end
        end
    end

    if not current_note then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.NOT_FOUND, "current note is not indexed", {
                path = input.buffer_path,
            }),
        }
    end

    local token_map = {}
    if type(current_note.title) ~= "string" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INTERNAL, "current indexed note has invalid title"),
        }
    end
    token_map[current_note.title] = true

    if current_note.aliases ~= nil and type(current_note.aliases) ~= "table" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INTERNAL, "current indexed note has invalid aliases"),
        }
    end

    for _, alias in ipairs(current_note.aliases or {}) do
        token_map[tostring(alias)] = true
    end

    local root = type(ctx.config) == "table" and ctx.config.vault_root or nil
    if type(root) ~= "string" or root == "" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.config.vault_root is required"),
        }
    end

    local files = fs_io.list_markdown_files(root)
    if type(files) ~= "table" then
        return {
            ok = false,
            opened = nil,
            match_count = nil,
            error = errors.new(errors.codes.INTERNAL, "fs_io.list_markdown_files returned invalid result"),
        }
    end
    local matches = {}
    local line_by_path = {}
    local seen = {}

    for _, path in ipairs(files) do
        if path ~= input.buffer_path then
            local content = fs_io.read_file(path)
            if type(content) == "string" then
                local line_no = 0
                for line in (content .. "\n"):gmatch("(.-)\n") do
                    line_no = line_no + 1
                    local links = markdown.extract_wikilinks(line)
                    if type(links) ~= "table" then
                        return {
                            ok = false,
                            opened = nil,
                            match_count = nil,
                            error = errors.new(errors.codes.INTERNAL,
                                "markdown.extract_wikilinks returned invalid result"),
                        }
                    end

                    for _, link in ipairs(links) do
                        local ref = type(link) == "table" and tostring(link.note_ref or "") or ""
                        if token_map[ref] and not seen[path] then
                            seen[path] = true
                            local indexed = by_path[path] or {}
                            local n = {
                                path = path,
                                title = indexed.title or basename(path):gsub("%.md$", ""),
                                aliases = indexed.aliases or {},
                                backlink_line = line_no,
                            }
                            table.insert(matches, n)
                            line_by_path[path] = line_no
                            break
                        end
                    end

                    if seen[path] then
                        break
                    end
                end
            end
        end
    end

    if #matches == 0 then
        return {
            ok = true,
            opened = false,
            match_count = 0,
            error = nil,
        }
    end

    local picked = telescope.open_disambiguation({
        target = { note_ref = current_note.title },
        matches = matches,
        buffer_path = input.buffer_path,
        open_path = function(path, item)
            local opened, _ = navigation.open_path(path)
            if not opened then
                return false
            end

            local line = tonumber((type(item) == "table" and item.backlink_line) or line_by_path[path])
            if line and line >= 1 and type(navigation.jump_to_line) == "function" then
                navigation.jump_to_line(line)
            end

            return true
        end,
    })

    if type(picked) ~= "table" or (picked.action ~= "open" and picked.action ~= "opened") or type(picked.path) ~= "string" then
        return {
            ok = true,
            opened = false,
            match_count = #matches,
            error = nil,
        }
    end

    if picked.action == "open" then
        local opened, open_err = navigation.open_path(picked.path)
        if not opened then
            return {
                ok = false,
                opened = nil,
                match_count = #matches,
                error = errors.new(errors.codes.INTERNAL, "failed to open selected backlink", {
                    path = picked.path,
                    reason = open_err,
                }),
            }
        end
        local picked_line = tonumber((picked.item and picked.item.backlink_line) or picked.backlink_line or
            line_by_path[picked.path])
        if picked_line and picked_line >= 1 and type(navigation.jump_to_line) == "function" then
            navigation.jump_to_line(picked_line)
        end
    end

    return {
        ok = true,
        opened = true,
        match_count = #matches,
        error = nil,
    }
end

return M
