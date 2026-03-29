local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

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

    local candidates = {}
    for _, note in ipairs(notes) do
        if type(note) == "table" then
            table.insert(candidates, {
                title = tostring(note.title or ""),
                aliases = type(note.aliases) == "table" and note.aliases or {},
                relpath = tostring(note.path or ""),
                path = tostring(note.path or ""),
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
        local label = display.label
        table.insert(items, {
            label = label,
            rank = entry.rank,
            candidate = candidate,
        })

        if type(entry.rank) == "number" and entry.rank <= 3 then
            has_exact_or_full_match = true
        end
    end

    local allow_create = not has_exact_or_full_match

    local picker_result = picker_open({
        query = query,
        items = items,
        allow_create = allow_create,
        allow_force_create = input.allow_force_create and allow_create,
    })

    if type(picker_result) ~= "table" or picker_result.action == nil or picker_result.action == "cancel" then
        return {
            ok = true,
            action = "cancelled",
            path = nil,
            error = nil,
        }
    end

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

    if picker_result.action == "open" then
        local selected = picker_result.item
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

    if picker_result.action == "create" then
        if not allow_create then
            return {
                ok = false,
                action = "cancelled",
                path = nil,
                error = errors.new(errors.codes.INVALID_INPUT, "create is not allowed when exact/full match exists"),
            }
        end

        local create_query = picker_result.query
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

    return {
        ok = true,
        action = "cancelled",
        path = nil,
        error = nil,
    }
end

return M
