local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")

local config = require("nvim-obsidian.config")
local router = require("nvim-obsidian.journal.router")
local vault = require("nvim-obsidian.model.vault")
local writer = require("nvim-obsidian.note.writer")
local ranker = require("nvim-obsidian.ranker")
local async_constants = require("nvim-obsidian.async.constants")

local M = {}

local function submit(prompt, force_create)
    local cfg = config.get()
    local input = vim.trim(prompt)
    if input == "" then
        return
    end

    if not force_create then
        local matches = vault.resolve_by_title_or_alias(input, cfg)
        local preferred = vault.preferred_match(input, matches, cfg)
        if preferred then
            writer.open(preferred.filepath)
            return
        end
        if #matches > 1 then
            vim.notify("nvim-obsidian: multiple matches; type vault-relative path to disambiguate", vim.log.levels.WARN)
            return
        end
    end

    local note_type, title = router.classify_input(input, cfg)
    local filepath = router.path_for_type(note_type, title, cfg)
    writer.ensure_and_open(filepath, title, note_type, cfg)
end

local function compute_match_context(note, query)
    return ranker.compute_match_context(note, query)
end

local function compute_rank(ctx, query)
    return ranker.compute_rank(ctx, query)
end

local function compute_display_label(note, ctx)
    return ranker.compute_display_label(note, ctx)
end

local function compute_ordinal_text(note)
    return ranker.compute_ordinal_text(note)
end

local function build_entry(note, query)
    return ranker.build_entry(note, query)
end

local function entries_from_cache(query)
    local entries = {}
    local q = (query or ""):lower()
    for _, note in ipairs(vault.all_notes()) do
        local entry = build_entry(note, q)
        if q == "" or entry.rank < 99 then
            table.insert(entries, entry)
        end
    end

    table.sort(entries, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.value.title:lower() < b.value.title:lower()
    end)

    return entries
end

local function ranked_passthrough_sorter()
    local function highlight_prompt(prompt, display)
        local highlights = {}
        local p = (prompt or ""):lower()
        local d = (display or ""):lower()

        for word in p:gmatch("%S+") do
            local start_pos, end_pos = d:find(word, 1, true)
            if start_pos then
                table.insert(highlights, { start = start_pos, finish = end_pos })
            end
        end

        return highlights
    end

    return sorters.Sorter:new({
        discard = true,
        scoring_function = function(_, _, _, entry)
            return entry.index
        end,
        highlighter = function(_, prompt, display)
            return highlight_prompt(prompt, display)
        end,
    })
end

local function make_finder(query)
    return finders.new_table({
        results = entries_from_cache(query),
        entry_maker = function(item)
            return {
                value = item.value,
                display = item.display,
                ordinal = item.ordinal,
                path = item.value.filepath,
                filename = item.value.filepath,
            }
        end,
    })
end

function M.open()
    local cfg = config.get()
    pickers.new({}, {
        prompt_title = "Obsidian Omni",
        finder = make_finder(""),
        sorter = ranked_passthrough_sorter(),
        previewer = conf.file_previewer({}),
        attach_mappings = function(prompt_bufnr, map)
            local refresh_timer = vim.uv.new_timer()

            local function cleanup_refresh_state()
                if refresh_timer and not refresh_timer:is_closing() then
                    refresh_timer:stop()
                    refresh_timer:close()
                end
            end

            local refresh_autocmd_id = vim.api.nvim_create_autocmd("TextChangedI", {
                buffer = prompt_bufnr,
                callback = function()
                    if refresh_timer and not refresh_timer:is_closing() then
                        refresh_timer:stop()
                    end

                    refresh_timer:start(async_constants.OMNI_QUERY_THROTTLE_MS, 0, vim.schedule_wrap(function()
                        if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
                            return
                        end

                        local picker = action_state.get_current_picker(prompt_bufnr)
                        if not picker then
                            return
                        end

                        local query = action_state.get_current_line()
                        picker:refresh(make_finder(query), { reset_prompt = false })
                    end))
                end,
            })

            vim.api.nvim_create_autocmd("BufWipeout", {
                buffer = prompt_bufnr,
                callback = function()
                    cleanup_refresh_state()
                    pcall(vim.api.nvim_del_autocmd, refresh_autocmd_id)
                end,
            })

            actions.select_default:replace(function()
                local line = action_state.get_current_line()
                local sel = action_state.get_selected_entry()
                cleanup_refresh_state()
                actions.close(prompt_bufnr)
                if sel and sel.value then
                    writer.open(sel.value.filepath)
                else
                    submit(line, false)
                end
            end)

            map("i", cfg.force_create_key, function()
                local line = action_state.get_current_line()
                cleanup_refresh_state()
                actions.close(prompt_bufnr)
                submit(line, true)
            end)

            return true
        end,
    }):find()
end

M._test_build_entry = build_entry
M._test_compute_match_context = compute_match_context
M._test_compute_ordinal_text = compute_ordinal_text
M._test_entries_from_cache = entries_from_cache

return M
