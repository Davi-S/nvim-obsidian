local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values

local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local router = require("nvim-obsidian.journal.router")
local vault = require("nvim-obsidian.model.vault")

local M = {}

local function ensure_note(filepath, title, note_type, cfg)
    if vim.fn.filereadable(filepath) == 0 then
        path.ensure_dir(path.parent(filepath))
        local tpl = router.template_for_type(note_type, cfg)
        local rendered = router.render_template(tpl, title)
        vim.fn.writefile(vim.split(rendered, "\n", { plain = true }), filepath)
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

    local note_type, title = router.classify_input(input)
    local filepath = router.path_for_type(note_type, title, cfg)
    ensure_note(filepath, title, note_type, cfg)
    open_note(filepath)
end

local function entries_from_cache()
    local entries = {}
    for _, note in ipairs(vault.all_notes()) do
        table.insert(entries, {
            value = note,
            display = note.title .. (note.relpath and ("  ->  " .. note.relpath) or ""),
            ordinal = (note.title .. " " .. table.concat(note.aliases, " ")):lower(),
        })
    end
    return entries
end

function M.open()
    local cfg = config.get()
    pickers.new({}, {
        prompt_title = "Obsidian Omni",
        finder = finders.new_table({
            results = entries_from_cache(),
            entry_maker = function(item)
                return {
                    value = item.value,
                    display = item.display,
                    ordinal = item.ordinal,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local line = action_state.get_current_line()
                local sel = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if sel and sel.value then
                    open_note(sel.value.filepath)
                else
                    submit(line, false)
                end
            end)

            map("i", cfg.force_create_key, function()
                local line = action_state.get_current_line()
                actions.close(prompt_bufnr)
                submit(line, true)
            end)

            return true
        end,
    }):find()
end

return M
