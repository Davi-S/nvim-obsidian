-- Shared ranking and matching logic for note search (Omni picker, CMP, future extensions)
local M = {}

local SEARCH_POLICY = {
    order = { "title", "aliases", "relpath" },
    display = {
        default = "title",
        alias_override = true,
    },
}

--- Compute match context for a note against a query string
-- @param note table Note object with title, aliases, relpath
-- @param query string Search query (case-insensitive)
-- @return table Match context with match flags and matched_alias
function M.compute_match_context(note, query)
    local q = (query or ""):lower()
    local aliases = note.aliases or {}
    local relpath = note.relpath or ""

    if q == "" then
        return {
            title_exact = false,
            title_match = false,
            alias_exact = false,
            alias_match = false,
            path_match = false,
            matched_alias = nil,
        }
    end

    local title_lower = note.title:lower()
    local title_exact = title_lower == q
    local title_match = title_lower:find(q, 1, true) ~= nil

    local exact_alias = nil
    local matched_alias = nil
    for _, alias in ipairs(aliases) do
        local alias_lower = alias:lower()
        if alias_lower == q and not exact_alias then
            exact_alias = alias
        end
        if alias_lower:find(q, 1, true) and not matched_alias then
            matched_alias = alias
        end
    end

    matched_alias = exact_alias or matched_alias

    return {
        title_exact = title_exact,
        title_match = title_match,
        alias_exact = exact_alias ~= nil,
        alias_match = matched_alias ~= nil,
        path_match = relpath ~= "" and relpath:lower():find(q, 1, true) ~= nil,
        matched_alias = matched_alias,
    }
end

--- Compute numeric rank for a match (lower = better match)
-- Ranking: exact alias (1) > partial alias (2) > exact title (3) > partial title (4) > path match (5) > no match (99)
-- @param ctx table Match context from compute_match_context
-- @param query string Search query (for empty query handling)
-- @return number Rank score
function M.compute_rank(ctx, query)
    if (query or "") == "" then
        return 100
    end
    if ctx.alias_exact then
        return 1
    end
    if ctx.alias_match then
        return 2
    end
    if ctx.title_exact then
        return 3
    end
    if ctx.title_match then
        return 4
    end
    if ctx.path_match then
        return 5
    end
    return 99
end

--- Compute display label for a note (potentially overriding with matched alias)
-- @param note table Note object
-- @param ctx table Match context
-- @return string Display label
function M.compute_display_label(note, ctx)
    if SEARCH_POLICY.display.alias_override and ctx.alias_match and not ctx.title_match then
        return ctx.matched_alias
    end
    return note.title
end

--- Compute ordinal text for search ordering (combines title, aliases, relpath)
-- @param note table Note object
-- @return string Ordinal text (lowercase)
function M.compute_ordinal_text(note)
    local aliases = note.aliases or {}
    local relpath = note.relpath or ""

    local parts = {}
    for _, key in ipairs(SEARCH_POLICY.order) do
        if key == "title" then
            table.insert(parts, note.title)
        elseif key == "aliases" then
            table.insert(parts, table.concat(aliases, " "))
        elseif key == "relpath" and relpath ~= "" then
            table.insert(parts, relpath)
        end
    end

    return table.concat(parts, " "):lower()
end

--- Build a ranked entry for display and sorting
-- @param note table Note object
-- @param query string Search query
-- @return table Entry with display, ordinal, rank, and value
function M.build_entry(note, query)
    local rel = note.relpath and ("  ->  " .. note.relpath) or ""
    local ctx = M.compute_match_context(note, query)
    local label = M.compute_display_label(note, ctx)

    return {
        value = note,
        display = label .. rel,
        ordinal = M.compute_ordinal_text(note),
        rank = M.compute_rank(ctx, query),
    }
end

return M
