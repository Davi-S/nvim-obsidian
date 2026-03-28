local errors = require("nvim_obsidian.core.shared.errors")

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

local function basename(path)
    local p = tostring(path or ""):gsub("\\", "/")
    return p:match("[^/]+$") or p
end

function M.execute(_ctx, _input)
    local ctx = _ctx or {}
    local input = _input or {}

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

    local notes = vault_catalog.list_notes() or {}
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
    token_map[tostring(current_note.title or "")] = true
    for _, alias in ipairs(current_note.aliases or {}) do
        token_map[tostring(alias)] = true
    end

    local root = (ctx.config and ctx.config.vault_root) or (vim and vim.fn and vim.fn.getcwd and vim.fn.getcwd())
    local files = fs_io.list_markdown_files(root) or {}
    local matches = {}
    local seen = {}

    for _, path in ipairs(files) do
        if path ~= input.buffer_path then
            local content = fs_io.read_file(path)
            if type(content) == "string" then
                for _, link in ipairs(markdown.extract_wikilinks(content) or {}) do
                    local ref = tostring(link.note_ref or "")
                    if token_map[ref] and not seen[path] then
                        seen[path] = true
                        local n = by_path[path] or {
                            path = path,
                            title = basename(path):gsub("%.md$", ""),
                            aliases = {},
                        }
                        table.insert(matches, n)
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
    })

    if type(picked) ~= "table" or picked.action ~= "open" or type(picked.path) ~= "string" then
        return {
            ok = true,
            opened = false,
            match_count = #matches,
            error = nil,
        }
    end

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

    return {
        ok = true,
        opened = true,
        match_count = #matches,
        error = nil,
    }
end

return M
