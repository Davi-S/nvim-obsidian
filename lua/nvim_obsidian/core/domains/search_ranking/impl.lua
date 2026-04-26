---Domain implementation: ranking and display label selection for notes.
---
---Used by omni-search and completion to produce stable ranking scores and
---human-readable labels.
local M = {}

local function lower(s)
    return string.lower(s or "")
end

local function trim(s)
    local text = tostring(s or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function contains_ci(haystack, needle)
    local h = lower(haystack)
    local n = lower(needle)
    if n == "" then
        return true
    end
    return h:find(n, 1, true) ~= nil
end

local function normalize_candidate(candidate)
    local c = candidate or {}
    local aliases = {}
    if type(c.aliases) == "table" then
        for _, a in ipairs(c.aliases) do
            if type(a) == "string" then
                table.insert(aliases, a)
            end
        end
    end

    return {
        title = tostring(c.title or ""),
        aliases = aliases,
        relpath = tostring(c.relpath or ""),
        _original = c,
    }
end

local function best_alias_match(aliases, query)
    local exact = nil
    local partial = nil
    for _, alias in ipairs(aliases) do
        local a = lower(alias)
        local q = lower(query)
        if a == q and not exact then
            exact = alias
        end
        if a:find(q, 1, true) and not partial then
            partial = alias
        end
    end
    return exact, partial
end

local function rank_candidate(candidate, query)
    local q = trim(query)
    if q == "" then
        return 100, nil
    end

    local title = candidate.title
    local relpath = candidate.relpath
    local title_l = lower(title)
    local q_l = lower(q)

    local alias_exact, alias_partial = best_alias_match(candidate.aliases, q)

    if alias_exact then
        return 1, alias_exact
    end
    if alias_partial then
        return 2, alias_partial
    end
    if title_l == q_l then
        return 3, nil
    end
    if contains_ci(title, q) then
        return 4, nil
    end
    if relpath ~= "" and contains_ci(relpath, q) then
        return 5, nil
    end

    return 99, nil
end

---Score and sort candidate notes against a query.
---@param query string
---@param candidates table[]
---@return table[]
function M.score_candidates(query, candidates)
    local input = candidates
    if type(input) ~= "table" then
        input = {}
    end

    local ranked = {}
    for _, raw in ipairs(input) do
        local candidate = normalize_candidate(raw)
        local rank, matched_alias = rank_candidate(candidate, query)
        table.insert(ranked, {
            candidate = candidate._original,
            rank = rank,
            matched_alias = matched_alias,
            title = candidate.title,
            aliases = candidate.aliases,
            relpath = candidate.relpath,
        })
    end

    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end

        local at = lower(a.title)
        local bt = lower(b.title)
        if at ~= bt then
            return at < bt
        end

        return lower(a.relpath) < lower(b.relpath)
    end)

    return { ranked = ranked }
end

---Select display label for a ranked candidate.
---@param query string
---@param candidate table
---@param separator string|nil
---@return string
function M.select_display(query, candidate, separator)
    local c = normalize_candidate(candidate)
    local sep = separator
    if type(sep) ~= "string" or sep == "" then
        sep = "->"
    end

    local rank, matched_alias = rank_candidate(c, query)
    local show_alias = (rank == 1 or rank == 2) and not contains_ci(c.title, query)

    local left = c.title
    if show_alias and matched_alias then
        left = matched_alias
    end

    if c.relpath ~= "" then
        return { label = left .. " " .. sep .. " " .. c.relpath }
    end

    return { label = left }
end

return M
