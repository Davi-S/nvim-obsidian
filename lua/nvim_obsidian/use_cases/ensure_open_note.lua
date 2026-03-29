local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "ensure_open_note",
    version = "phase3-contract",
    dependencies = {
        "journal",
        "vault_catalog",
        "template",
        "filesystem.io",
        "neovim.navigation",
    },
    input = {
        title_or_token = "string",
        create_if_missing = "boolean",
        origin = "omni|journal|link",
    },
    output = {
        ok = "boolean",
        path = "string|nil",
        created = "boolean|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    local ctx = _ctx or {}
    local input = _input or {}

    if type(input.title_or_token) ~= "string" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "title_or_token must be a string"),
        }
    end

    if type(input.create_if_missing) ~= "boolean" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "create_if_missing must be a boolean"),
        }
    end

    if type(input.origin) ~= "string" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "origin must be a string"),
        }
    end

    local token = (input.title_or_token:gsub("^%s+", ""):gsub("%s+$", ""))
    if token == "" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "title_or_token cannot be empty"),
        }
    end

    local vault_catalog = ctx.vault_catalog
    local navigation = ctx.navigation
    local fs_io = ctx.fs_io

    if type(vault_catalog) ~= "table" or type(vault_catalog.find_by_title_or_alias) ~= "function" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog.find_by_title_or_alias is required"),
        }
    end

    if type(navigation) ~= "table" or type(navigation.open_path) ~= "function" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.navigation.open_path is required"),
        }
    end

    if type(fs_io) ~= "table" or type(fs_io.write_file) ~= "function" then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.fs_io.write_file is required"),
        }
    end

    local lookup = vault_catalog.find_by_title_or_alias(token) or { matches = {} }
    local matches = lookup.matches or {}

    if #matches > 1 then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.AMBIGUOUS_TARGET, "multiple notes match token", {
                token = token,
                count = #matches,
            }),
        }
    end

    if #matches == 1 then
        local existing_path = tostring(matches[1].path or "")
        local opened, open_err = navigation.open_path(existing_path)
        if not opened then
            return {
                ok = false,
                path = existing_path,
                created = nil,
                error = errors.new(errors.codes.INTERNAL, "failed to open existing note", {
                    path = existing_path,
                    reason = open_err,
                }),
            }
        end

        return {
            ok = true,
            path = existing_path,
            created = false,
            error = nil,
        }
    end

    if not input.create_if_missing then
        return {
            ok = false,
            path = nil,
            created = nil,
            error = errors.new(errors.codes.NOT_FOUND, "note not found and creation disabled", {
                token = token,
            }),
        }
    end

    local note_kind = "none"
    local journal = ctx.journal
    if type(journal) == "table" and type(journal.classify_input) == "function" then
        local classified = journal.classify_input(token, input.now)
        note_kind = tostring((classified and classified.kind) or "none")
    end

    local function join_path(base, leaf)
        local b = tostring(base or ""):gsub("\\", "/"):gsub("//+", "/")
        local l = tostring(leaf or ""):gsub("\\", "/"):gsub("^/+", "")
        if b == "" then
            return l
        end
        if b:sub(-1) == "/" then
            return b .. l
        end
        return b .. "/" .. l
    end

    local function slugify_title(title)
        local s = tostring(title or "")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        s = s:gsub("%s+", "-")
        s = s:gsub("[\\/:*?\"<>|]", "-")
        s = s:gsub("%-+", "-")
        s = s:gsub("^%-+", ""):gsub("%-+$", "")
        if s == "" then
            s = "untitled"
        end
        return s
    end

    local cfg = ctx.config or {}
    local note_title = token
    local base_subdir = tostring(cfg.new_notes_subdir or "")

    if input.origin == "journal" and note_kind ~= "none" then
        local journal_cfg = (((cfg.journal or {})[note_kind]) or {})
        if type(ctx.resolve_journal_title) == "function" then
            local resolved_title = ctx.resolve_journal_title(note_kind, input.now or os.time())
            if type(resolved_title) == "string" and resolved_title ~= "" then
                note_title = resolved_title
            end
        end
        if type(journal_cfg.subdir) == "string" and journal_cfg.subdir ~= "" then
            base_subdir = journal_cfg.subdir
        end
    end

    local filename = slugify_title(note_title) .. ".md"
    local path = join_path(base_subdir, filename)

    local content = ""
    if type(ctx.resolve_template_content) == "function" and type(ctx.template) == "table" and type(ctx.template.render) == "function" then
        local template_content = ctx.resolve_template_content({
            origin = input.origin,
            kind = note_kind,
            title = note_title,
            token = token,
        })
        if type(template_content) == "string" and template_content ~= "" then
            local rendered = ctx.template.render(template_content, {
                title = note_title,
                origin = input.origin,
                kind = note_kind,
            })
            content = tostring((rendered and rendered.rendered) or "")
        end
    end

    local wrote, write_err = fs_io.write_file(path, content)
    if not wrote then
        return {
            ok = false,
            path = path,
            created = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to create note", {
                path = path,
                reason = write_err,
            }),
        }
    end

    if type(vault_catalog.upsert_note) == "function" then
        vault_catalog.upsert_note({
            path = path,
            title = note_title,
            aliases = {},
        })
    end

    local opened, open_err = navigation.open_path(path)
    if not opened then
        return {
            ok = false,
            path = path,
            created = true,
            error = errors.new(errors.codes.INTERNAL, "note created but failed to open", {
                path = path,
                reason = open_err,
            }),
        }
    end

    return {
        ok = true,
        path = path,
        created = true,
        error = nil,
    }
end

return M
