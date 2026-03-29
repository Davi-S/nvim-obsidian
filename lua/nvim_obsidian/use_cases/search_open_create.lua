local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

local function normalize_path(path)
    local p = tostring(path or "")
    p = p:gsub("\\", "/")
    p = p:gsub("//+", "/")
    return p
end

local function to_vault_relpath(path, vault_root)
    local normalized_path = normalize_path(path)
    local normalized_root = normalize_path(vault_root)

    if normalized_path == "" then
        return ""
    end

    if normalized_root == "" then
        return normalized_path
    end

    normalized_root = normalized_root:gsub("/+$", "")
    if normalized_root == "" then
        return normalized_path
    end

    if normalized_path == normalized_root then
        return ""
    end

    local prefix = normalized_root .. "/"
    if normalized_path:sub(1, #prefix) == prefix then
        return normalized_path:sub(#prefix + 1)
    end

    return normalized_path
end

M.contract = {
    name = "search_open_create",
    version = "phase3-contract",
    dependencies = {
        "search_ranking",
        "vault_catalog",
        "journal",
        "ensure_open_note",
        "picker.telescope",
    },
    input = {
        query = "string",
        allow_force_create = "boolean",
    },
    output = {
        ok = "boolean",
        action = "opened|created|cancelled",
        path = "string|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if type(_input) ~= "table" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local ctx = _ctx
    local input = _input

    if type(input.query) ~= "string" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "query must be a string"),
        }
    end

    if type(input.allow_force_create) ~= "boolean" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "allow_force_create must be a boolean"),
        }
    end

    local query = (input.query:gsub("^%s+", ""):gsub("%s+$", ""))

    local search_ranking = ctx.search_ranking
    local vault_catalog = ctx.vault_catalog
    local ensure_open_note = ctx.ensure_open_note

    if type(search_ranking) ~= "table" or type(search_ranking.score_candidates) ~= "function" or type(search_ranking.select_display) ~= "function" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.search_ranking score/select functions are required"),
        }
    end

    if type(vault_catalog) ~= "table" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog is required"),
        }
    end

    if type(ensure_open_note) ~= "table" or type(ensure_open_note.execute) ~= "function" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.ensure_open_note.execute is required"),
        }
    end

    local picker_open = nil
    if type(ctx.telescope) == "table" and type(ctx.telescope.open_omni) == "function" then
        picker_open = ctx.telescope.open_omni
    elseif type(ctx.open_omni_picker) == "function" then
        picker_open = ctx.open_omni_picker
    end

    if type(picker_open) ~= "function" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "omni picker opener is required"),
        }
    end

    if type(vault_catalog.list_notes) ~= "function" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog.list_notes is required"),
        }
    end

    local notes = vault_catalog.list_notes()
    if type(notes) ~= "table" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INTERNAL, "vault_catalog.list_notes returned invalid result"),
        }
    end

    local vault_root = nil
    if type(ctx.config) == "table" and type(ctx.config.vault_root) == "string" then
        vault_root = ctx.config.vault_root
    end

    local candidates = {}
    for _, note in ipairs(notes) do
        if type(note) == "table" then
            local note_path = tostring(note.path or "")
            local note_relpath = tostring(note.relpath or "")
            if note_relpath == "" then
                note_relpath = to_vault_relpath(note_path, vault_root)
            end

            table.insert(candidates, {
                title = tostring(note.title or ""),
                aliases = type(note.aliases) == "table" and note.aliases or {},
                relpath = note_relpath,
                path = note_path,
            })
        end
    end

    local scored = search_ranking.score_candidates(query, candidates)
    if type(scored) ~= "table" or type(scored.ranked) ~= "table" then
        return {
            ok = false,
            action = "cancelled",
            path = nil,
            error = errors.new(errors.codes.INTERNAL, "search_ranking.score_candidates returned invalid result"),
        }
    end

    local ranked = scored.ranked
    local display_separator = "->"
    if type(ctx.config) == "table" and type(ctx.config.omni) == "table" and type(ctx.config.omni.display_separator) == "string" then
        display_separator = ctx.config.omni.display_separator
    end

    local items = {}
    local has_exact_or_full_match = false
    for _, entry in ipairs(ranked) do
        if type(entry) ~= "table" or type(entry.candidate) ~= "table" then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INTERNAL, "ranked entry is invalid"),
            }
        end

        local candidate = entry.candidate
        local display = search_ranking.select_display(query, candidate, display_separator)
        if type(display) ~= "table" or type(display.label) ~= "string" then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INTERNAL, "search_ranking.select_display returned invalid result"),
            }
        end

        table.insert(items, {
            label = display.label,
            rank = entry.rank,
            candidate = candidate,
        })

        if type(entry.rank) == "number" and entry.rank <= 3 then
            has_exact_or_full_match = true
        end
    end

    local allow_create = not has_exact_or_full_match

    local function run_ensure(title_or_token, create_if_missing, origin)
        local out = ensure_open_note.execute(ctx, {
            title_or_token = title_or_token,
            create_if_missing = create_if_missing,
            origin = origin or "omni",
        })

        if not out.ok then
            return {
                ok = false,
                action = "cancelled",
                path = out.path,
                error = out.error,
            }
        end

        return {
            ok = true,
            action = out.created and "created" or "opened",
            path = out.path,
            error = nil,
        }
    end

    local function run_open_flow(selected)
        if type(selected) ~= "table" or type(selected.candidate) ~= "table" then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "picker returned invalid selection"),
            }
        end

        local token = tostring(selected.candidate.path or selected.candidate.title or "")
        if token == "" then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "selected candidate is missing path/title"),
            }
        end

        return run_ensure(token, false, "omni")
    end

    local function run_create_flow(raw_query)
        if not allow_create then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "create is not allowed when exact/full match exists"),
            }
        end

        local create_query = raw_query
        if create_query == nil then
            create_query = query
        end
        create_query = tostring(create_query)
        create_query = create_query:gsub("^%s+", ""):gsub("%s+$", "")
        if create_query == "" then
            return {
                ok = true,
                action = "cancelled",
                path = nil,
                error = nil,
            }
        end

        local create_origin = "omni"
        if type(ctx.journal) == "table" and type(ctx.journal.classify_input) == "function" then
            local classified = ctx.journal.classify_input(create_query, input.now)
            local kind = tostring((classified and classified.kind) or "none")
            if kind ~= "none" then
                create_origin = "journal"
            end
        end

        return run_ensure(create_query, true, create_origin)
    end

    local function notify_async_error(out, fallback)
        if out and out.ok then
            return
        end
        if type(ctx.notifications) ~= "table" or type(ctx.notifications.error) ~= "function" then
            return
        end
        local message = fallback
        if out and out.error and out.error.message then
            message = out.error.message
        end
        pcall(ctx.notifications.error, message)
    end

    local picker_result = picker_open({
        query = query,
        items = items,
        allow_create = allow_create,
        allow_force_create = input.allow_force_create and allow_create,
        on_open = function(selected)
            local out = run_open_flow(selected)
            notify_async_error(out, "ObsidianOmni open failed")
        end,
        on_create = function(create_query)
            local out = run_create_flow(create_query)
            notify_async_error(out, "ObsidianOmni create failed")
        end,
    })

    if type(picker_result) ~= "table" or picker_result.action == nil or picker_result.action == "cancel" then
        return {
            ok = true,
            action = "cancelled",
            path = nil,
            error = nil,
        }
    end

    if picker_result.action == "deferred" then
        return {
            ok = true,
            action = "cancelled",
            path = nil,
            error = nil,
        }
    end

    if picker_result.action == "open" then
        return run_open_flow(picker_result.item)
    end

    if picker_result.action == "create" then
        return run_create_flow(picker_result.query)
    end

    return {
        ok = true,
        action = "cancelled",
        path = nil,
        error = nil,
    }
end

return M
