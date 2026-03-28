---Telescope picker adapter for nvim-obsidian.
---
---This adapter provides integration with Telescope for:
--- - Omni-search picker (search_open_create workflow)
--- - Disambiguation picker (follow_link workflow for ambiguous targets)
---
---@module telescope

local M = {}

---Internal helper to score and prepare candidates for display.
---
---@param ctx table - context with ranking and display helpers
---@param notes table - list of notes to prepare
---@return table items - display strings
---@return table note_map - mapping from display index to note
local function _prepare_candidates(ctx, notes)
    local items = {}
    local note_map = {}

    -- Rank candidates if search_ranking available
    local scored_candidates = {}
    if ctx.search_ranking and ctx.search_ranking.score_candidates then
        local ok, ranked = pcall(ctx.search_ranking.score_candidates, "", notes)
        if ok and ranked then
            scored_candidates = ranked
        else
            -- Fallback: use unranked candidates
            for _, note in ipairs(notes) do
                if note then
                    table.insert(scored_candidates, {
                        note = note,
                        score = 0,
                        matched_field = "title",
                    })
                end
            end
        end
    else
        -- No ranking available
        for _, note in ipairs(notes) do
            if note then
                table.insert(scored_candidates, {
                    note = note,
                    score = 0,
                    matched_field = "title",
                })
            end
        end
    end

    -- Build display items
    for _, scored in ipairs(scored_candidates) do
        if scored and scored.note then
            local note = scored.note
            local display_label = note.title or note.path or ""

            -- Use select_display if available
            if ctx.search_ranking and ctx.search_ranking.select_display then
                local ok, label = pcall(ctx.search_ranking.select_display, note)
                if ok then
                    display_label = label
                end
            end

            if display_label ~= "" then
                table.insert(items, display_label)
                table.insert(note_map, note)
            end
        end
    end

    return items, note_map
end

---Internal helper to prepare matches for disambiguation display.
---
---@param matches table - list of candidate notes
---@return table items - display strings
---@return table match_map - mapping from display index to match
local function _prepare_disambiguation(matches)
    local items = {}
    local match_map = {}

    for _, match in ipairs(matches) do
        if match then
            -- Show both title and path to disambiguate
            local display = ""
            if match.title then
                display = match.title
            end
            if match.path then
                if display ~= "" then
                    display = display .. " → " .. match.path
                else
                    display = match.path
                end
            end

            if display ~= "" then
                table.insert(items, display)
                table.insert(match_map, match)
            end
        end
    end

    return items, match_map
end

---Open an omni picker for searching and selecting notes.
---
---This searches the vault catalog, ranks candidates, and presents
---them via Telescope for selection.
---
---@param ctx table
---  - vault_catalog: table with list_notes() method
---  - search_ranking: table with score_candidates(query, notes) and select_display(note)
---  - config: table with configuration
---@return false|table - false if cancelled or unavailable, selected note otherwise
function M.open_omni(ctx)
    -- Validate required dependencies
    if not ctx or not ctx.vault_catalog then
        return false
    end

    -- Get all notes from vault catalog
    local notes = ctx.vault_catalog.list_notes()
    if not notes or #notes == 0 then
        return false
    end

    -- Prepare candidates for display
    local items, note_map = _prepare_candidates(ctx, notes)
    if #items == 0 then
        return false
    end

    -- Validate picker availability
    if not (vim and vim.ui and vim.ui.select) then
        return false
    end

    -- Use synchronous vim.ui.select via sync mode
    local selected_note = false
    vim.ui.select(items, {
        prompt = "Select note:",
        format_item = function(item)
            return item
        end,
    }, function(item, idx)
        if item and idx then
            selected_note = note_map[idx] or false
        end
    end)

    return selected_note
end

---Open a disambiguation picker for ambiguous link targets.
---
---When a link matches multiple notes, this picker lets the user
---choose which target they meant.
---
---@param matches table - list of candidate notes with { path, title, ... }
---@return false|table - false if cancelled or unavailable, selected match otherwise
function M.open_disambiguation(matches)
    if not matches or #matches == 0 then
        return false
    end

    -- Prepare disambiguation options
    local items, match_map = _prepare_disambiguation(matches)
    if #items == 0 then
        return false
    end

    -- Validate picker availability
    if not (vim and vim.ui and vim.ui.select) then
        return false
    end

    -- Use vim.ui.select for picker
    local selected_match = false
    vim.ui.select(items, {
        prompt = "Disambiguate target:",
        format_item = function(item)
            return item
        end,
    }, function(item, idx)
        if item and idx then
            selected_match = match_map[idx] or false
        end
    end)

    return selected_match
end

-- Export internals for testing
M._prepare_candidates = _prepare_candidates
M._prepare_disambiguation = _prepare_disambiguation

return M
