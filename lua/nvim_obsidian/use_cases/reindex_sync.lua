local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "reindex_sync",
    version = "phase3-contract",
    dependencies = {
        "filesystem.io",
        "filesystem.watcher",
        "vault_catalog",
        "parser.frontmatter",
        "neovim.notifications",
    },
    input = {
        mode = "startup|manual|event",
        event = "table|nil",
    },
    output = {
        ok = "boolean",
        stats = "table|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    local ctx = _ctx or {}
    local input = _input or {}

    local mode = input.mode
    if mode ~= "startup" and mode ~= "manual" and mode ~= "event" then
        return {
            ok = false,
            stats = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "mode must be startup|manual|event"),
        }
    end

    local fs_io = ctx.fs_io
    local watcher = ctx.watcher
    local vault_catalog = ctx.vault_catalog
    local frontmatter = ctx.frontmatter

    if type(fs_io) ~= "table" or type(fs_io.read_file) ~= "function" then
        return {
            ok = false,
            stats = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.fs_io.read_file is required"),
        }
    end

    if type(vault_catalog) ~= "table" or type(vault_catalog.upsert_note) ~= "function" or type(vault_catalog.remove_note) ~= "function" then
        return {
            ok = false,
            stats = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog upsert/remove functions are required"),
        }
    end

    if type(frontmatter) ~= "table" or type(frontmatter.parse) ~= "function" then
        return {
            ok = false,
            stats = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.frontmatter.parse is required"),
        }
    end

    local function warn(msg)
        if type(ctx.notifications) == "table" and type(ctx.notifications.warn) == "function" then
            ctx.notifications.warn(msg)
        end
    end

    local function basename(path)
        local p = tostring(path or ""):gsub("\\", "/")
        return p:match("[^/]+$") or p
    end

    local function title_from_path(path)
        local name = basename(path)
        return (name:gsub("%.md$", ""))
    end

    local function normalize_aliases(value)
        if type(value) ~= "table" then
            return {}
        end
        local out = {}
        for _, alias in ipairs(value) do
            if type(alias) == "string" and alias ~= "" then
                table.insert(out, alias)
            end
        end
        return out
    end

    local function build_note(path)
        local markdown, read_err = fs_io.read_file(path)
        if markdown == nil then
            return nil, errors.new(errors.codes.INTERNAL, "failed to read markdown", {
                path = path,
                reason = read_err,
            })
        end

        local meta, parse_err = frontmatter.parse(markdown)
        if parse_err then
            warn("Reindex: frontmatter parse fallback for " .. tostring(path))
        end

        local metadata = type(meta) == "table" and meta or {}
        local title = tostring(metadata.title or "")
        if title == "" then
            title = title_from_path(path)
        end

        return {
            path = tostring(path),
            title = title,
            aliases = normalize_aliases(metadata.aliases),
        }, nil
    end

    local function full_rescan()
        local stats = {
            mode = mode,
            scanned = 0,
            upserted = 0,
            removed = 0,
            errors = 0,
        }

        local paths = nil
        if type(ctx.scan_markdown_files) == "function" then
            paths = ctx.scan_markdown_files()
        elseif type(fs_io.list_markdown_files) == "function" then
            paths = fs_io.list_markdown_files()
        end

        if type(paths) ~= "table" then
            return {
                ok = false,
                stats = nil,
                error = errors.new(errors.codes.INTERNAL, "failed to scan markdown files"),
            }
        end

        local rebuilt = {}
        for _, path in ipairs(paths) do
            if type(path) == "string" and path ~= "" then
                stats.scanned = stats.scanned + 1
                local note, note_err = build_note(path)
                if note then
                    table.insert(rebuilt, note)
                else
                    stats.errors = stats.errors + 1
                    warn("Reindex: " .. tostring(note_err.message))
                end
            end
        end

        if type(ctx.replace_catalog) ~= "function" then
            return {
                ok = false,
                stats = nil,
                error = errors.new(errors.codes.INTERNAL, "replace_catalog hook is required for atomic full reindex"),
            }
        end

        local ok, replace_err = ctx.replace_catalog(rebuilt)
        if not ok then
            return {
                ok = false,
                stats = nil,
                error = errors.new(errors.codes.INTERNAL, "failed to replace vault catalog", {
                    reason = replace_err,
                }),
            }
        end
        stats.upserted = #rebuilt

        if mode == "startup" and type(watcher) == "table" and type(watcher.start) == "function" then
            local started, start_err = watcher.start(ctx)
            if not started then
                return {
                    ok = false,
                    stats = nil,
                    error = errors.new(errors.codes.INTERNAL, "failed to start watcher", {
                        reason = start_err,
                    }),
                }
            end
        end

        return {
            ok = true,
            stats = stats,
            error = nil,
        }
    end

    local function event_sync(event)
        if type(event) ~= "table" then
            return {
                ok = false,
                stats = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "event table is required for event mode"),
            }
        end

        local stats = {
            mode = mode,
            scanned = 0,
            upserted = 0,
            removed = 0,
            errors = 0,
        }

        local kind = tostring(event.kind or "")
        local path = tostring(event.path or "")

        local function remove_path(p)
            if p == "" then
                return
            end
            local removed = vault_catalog.remove_note(p)
            if removed and removed.ok then
                stats.removed = stats.removed + 1
            elseif removed and removed.error and removed.error.code == errors.codes.NOT_FOUND then
                -- idempotent delete semantics
            else
                stats.errors = stats.errors + 1
            end
        end

        local function upsert_path(p)
            if p == "" then
                stats.errors = stats.errors + 1
                return
            end
            stats.scanned = stats.scanned + 1
            local note, note_err = build_note(p)
            if not note then
                stats.errors = stats.errors + 1
                warn("Sync event: " .. tostring(note_err.message))
                return
            end
            local upsert = vault_catalog.upsert_note(note)
            if upsert and upsert.ok then
                stats.upserted = stats.upserted + 1
            else
                stats.errors = stats.errors + 1
            end
        end

        if kind == "delete" then
            remove_path(path)
        elseif kind == "create" or kind == "modify" then
            upsert_path(path)
        elseif kind == "rename" then
            remove_path(tostring(event.old_path or ""))
            upsert_path(tostring(event.new_path or ""))
        else
            return {
                ok = false,
                stats = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "unsupported event kind", { kind = kind }),
            }
        end

        return {
            ok = true,
            stats = stats,
            error = nil,
        }
    end

    if mode == "event" then
        return event_sync(input.event)
    end

    return full_rescan()
end

return M
