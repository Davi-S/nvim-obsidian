local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

M.contract = {
    name = "follow_link",
    version = "phase3-contract",
    dependencies = {
        "wiki_link",
        "vault_catalog",
        "ensure_open_note",
        "picker.telescope",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        line = "string",
        col = "integer",
        buffer_path = "string",
    },
    output = {
        ok = "boolean",
        status = "opened|created|ambiguous|invalid|missing_anchor",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if type(_input) ~= "table" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local ctx = _ctx
    local input = _input

    if type(input.line) ~= "string" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "line must be a string"),
        }
    end

    if type(input.col) ~= "number" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "col must be a number"),
        }
    end

    if type(input.buffer_path) ~= "string" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "buffer_path must be a string"),
        }
    end

    local wiki_link = ctx.wiki_link
    local vault_catalog = ctx.vault_catalog
    local ensure_open_note = ctx.ensure_open_note
    local navigation = ctx.navigation

    if type(wiki_link) ~= "table" or type(wiki_link.parse_at_cursor) ~= "function" or type(wiki_link.resolve_target) ~= "function" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.wiki_link parse/resolve functions are required"),
        }
    end

    if type(vault_catalog) ~= "table" or type(vault_catalog.find_by_identity_token) ~= "function" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.vault_catalog.find_by_identity_token is required"),
        }
    end

    if type(ensure_open_note) ~= "table" or type(ensure_open_note.execute) ~= "function" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.ensure_open_note.execute is required"),
        }
    end

    if type(navigation) ~= "table" or type(navigation.open_path) ~= "function" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INVALID_INPUT, "ctx.navigation.open_path is required"),
        }
    end

    local parsed = wiki_link.parse_at_cursor(input.line, input.col)
    if parsed.error then
        return {
            ok = false,
            status = "invalid",
            error = parsed.error,
        }
    end

    local target = parsed.target
    if not target then
        return {
            ok = true,
            status = "invalid",
            error = nil,
        }
    end

    local function maybe_warn(msg)
        if type(ctx.notifications) == "table" and type(ctx.notifications.warn) == "function" then
            ctx.notifications.warn(msg)
        end
    end

    local function maybe_jump_to_target(path, target_spec)
        local anchor = target_spec and target_spec.anchor or nil
        local block_id = target_spec and target_spec.block_id or nil
        if not anchor and not block_id then
            return {
                ok = true,
                missing_anchor = false,
            }
        end

        local anchor_ok = true
        if type(ctx.anchor_exists) == "function" then
            anchor_ok = ctx.anchor_exists(path, {
                anchor = anchor,
                block_id = block_id,
            })
        end

        if not anchor_ok then
            maybe_warn("ObsidianFollow: heading or block target not found")
            return {
                ok = true,
                missing_anchor = true,
            }
        end

        if type(navigation.jump_to_anchor) == "function" then
            local jumped, jump_err = navigation.jump_to_anchor({
                path = path,
                anchor = anchor,
                block_id = block_id,
            })

            if jumped == false then
                local code = type(jump_err) == "table" and jump_err.code or nil
                if code == errors.codes.NOT_FOUND then
                    maybe_warn("ObsidianFollow: heading or block target not found")
                    return {
                        ok = true,
                        missing_anchor = true,
                    }
                end
                return {
                    ok = false,
                    error = errors.new(errors.codes.INTERNAL, "failed to jump to link anchor", {
                        path = path,
                        anchor = anchor,
                        block_id = block_id,
                        reason = jump_err,
                    }),
                }
            end
        end

        return {
            ok = true,
            missing_anchor = false,
        }
    end

    local token = tostring(target.note_ref or "")
    local resolved

    if token == "" then
        resolved = {
            status = "resolved",
            resolved_path = input.buffer_path,
            ambiguous_matches = nil,
        }
    else
        local candidate_notes = nil
        if type(vault_catalog.list_notes) == "function" then
            candidate_notes = vault_catalog.list_notes()
        else
            local lookup = vault_catalog.find_by_identity_token(token)
            if type(lookup) == "table" then
                candidate_notes = lookup.matches
            end
        end

        if type(candidate_notes) ~= "table" then
            return {
                ok = false,
                status = "invalid",
                error = errors.new(errors.codes.INTERNAL, "failed to gather candidate notes for target resolution"),
            }
        end

        resolved = wiki_link.resolve_target(target, candidate_notes)
    end

    if resolved.status == "ambiguous" then
        local pick_ambiguous = ctx.pick_ambiguous_target
        if type(pick_ambiguous) ~= "function" and type(ctx.open_disambiguation_picker) == "function" then
            pick_ambiguous = ctx.open_disambiguation_picker
        end
        if type(pick_ambiguous) ~= "function" and type(ctx.telescope) == "table" and type(ctx.telescope.open_disambiguation) == "function" then
            pick_ambiguous = ctx.telescope.open_disambiguation
        end

        if type(pick_ambiguous) ~= "function" then
            return {
                ok = false,
                status = "invalid",
                error = errors.new(errors.codes.INVALID_INPUT, "ambiguous target requires disambiguation picker"),
            }
        end

        local picked = pick_ambiguous({
            target = target,
            matches = type(resolved.ambiguous_matches) == "table" and resolved.ambiguous_matches or {},
            buffer_path = input.buffer_path,
        })

        local picked_path = nil
        if type(picked) == "string" then
            picked_path = picked
        elseif type(picked) == "table" then
            if picked.action == "cancel" then
                picked_path = nil
            else
                local from_path = type(picked.path) == "string" and picked.path or ""
                local item = type(picked.item) == "table" and picked.item or nil
                local from_item_path = item and type(item.path) == "string" and item.path or ""
                picked_path = tostring(from_path ~= "" and from_path or from_item_path)
                if picked_path == "" and type(item) == "table" and type(item.candidate) == "table" then
                    picked_path = tostring(item.candidate.path or "")
                end
                if picked_path == "" then
                    picked_path = nil
                end
            end
        end

        if not picked_path then
            maybe_warn("ObsidianFollow: ambiguous target")
            return {
                ok = true,
                status = "ambiguous",
                error = nil,
            }
        end

        local opened, open_err = navigation.open_path(picked_path)
        if not opened then
            return {
                ok = false,
                status = "invalid",
                error = errors.new(errors.codes.INTERNAL, "failed to open disambiguation target", {
                    path = picked_path,
                    reason = open_err,
                }),
            }
        end

        local jump_result = maybe_jump_to_target(picked_path, target)
        if not jump_result.ok then
            return {
                ok = false,
                status = "invalid",
                error = jump_result.error,
            }
        end

        if jump_result.missing_anchor then
            return {
                ok = true,
                status = "missing_anchor",
                error = nil,
            }
        end

        return {
            ok = true,
            status = "opened",
            error = nil,
        }
    end

    if resolved.status == "missing" then
        local ensured = ensure_open_note.execute(ctx, {
            title_or_token = token,
            create_if_missing = true,
            origin = "link",
        })

        if not ensured.ok then
            return {
                ok = false,
                status = "invalid",
                error = ensured.error,
            }
        end

        return {
            ok = true,
            status = "created",
            error = nil,
        }
    end

    local path = resolved.resolved_path
    if type(path) ~= "string" or path == "" then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INTERNAL, "resolved target is missing a valid path"),
        }
    end

    local opened, open_err = navigation.open_path(path)
    if not opened then
        return {
            ok = false,
            status = "invalid",
            error = errors.new(errors.codes.INTERNAL, "failed to open resolved target", {
                path = path,
                reason = open_err,
            }),
        }
    end

    local jump_result = maybe_jump_to_target(path, target)
    if not jump_result.ok then
        return {
            ok = false,
            status = "invalid",
            error = jump_result.error,
        }
    end

    if jump_result.missing_anchor then
        return {
            ok = true,
            status = "missing_anchor",
            error = nil,
        }
    end

    return {
        ok = true,
        status = "opened",
        error = nil,
    }
end

return M
