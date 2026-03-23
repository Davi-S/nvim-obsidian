local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")

local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local router = require("nvim-obsidian.journal.router")
local vault = require("nvim-obsidian.model.vault")

local M = {}

local SEARCH_POLICY = {
    order = { "title", "aliases", "relpath" },
    display = {
        default = "title",
        alias_override = true,
    },
}

local function ensure_note(filepath, title, note_type, cfg)
    if vim.fn.filereadable(filepath) == 0 then
        path.ensure_dir(path.parent(filepath))
        local tpl = router.template_for_type(note_type, cfg)
        local rendered = router.render_template(tpl, title)
        if rendered == "" then
            vim.fn.writefile({}, filepath)
        else
            vim.fn.writefile(vim.split(rendered, "\n", { plain = true }), filepath)
        end
    end
end

local function open_note(filepath)
    vim.cmd.edit(vim.fn.fnameescape(filepath))
end

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
            open_note(preferred.filepath)
            return
        end
        if #matches > 1 then
            vim.notify("nvim-obsidian: multiple matches; type vault-relative path to disambiguate", vim.log.levels.WARN)
            return
        end
    end

    local note_type, title = router.classify_input(input, cfg)
    local filepath = router.path_for_type(note_type, title, cfg)
    ensure_note(filepath, title, note_type, cfg)
    open_note(filepath)
end

local function compute_match_context(note, query)
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

local function compute_rank(ctx, query)
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

local function compute_display_label(note, ctx)
    if SEARCH_POLICY.display.alias_override and ctx.alias_match and not ctx.title_match then
        return ctx.matched_alias
    end
    return note.title
end

local function compute_ordinal_text(note)
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

local function build_entry(note, query)
    local rel = note.relpath and ("  ->  " .. note.relpath) or ""
    local ctx = compute_match_context(note, query)
    local label = compute_display_label(note, ctx)

    return {
        value = note,
        display = label .. rel,
        ordinal = compute_ordinal_text(note),
        rank = compute_rank(ctx, query),
    }
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
    return sorters.Sorter:new({
        discard = true,
        scoring_function = function()
            return 1
        end,
        highlighter = function()
            return {}
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

                    refresh_timer:start(60, 0, vim.schedule_wrap(function()
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
                    open_note(sel.value.filepath)
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
