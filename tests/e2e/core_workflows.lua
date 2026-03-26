require("tests.support.runtime").setup_runtime_paths()

local function assert_true(cond, msg)
    if not cond then
        error(msg)
    end
end

local function wait_until(timeout_ms, interval_ms, predicate)
    return vim.wait(timeout_ms, predicate, interval_ms, false)
end

local function exists_cmd(name)
    return vim.fn.exists(":" .. name) == 2
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.mkdir(root .. "/08 Templates", "p")
vim.fn.writefile({ "---", "aliases: []", "tags: [nota_diaria]", "---", "", "# {{title}}" },
    root .. "/08 Templates/Nota diaria.md")
vim.fn.writefile({ "# {{title}}" }, root .. "/08 Templates/Nova nota.md")

local opts = {
    vault_root = root,
    locale = "pt-BR",
    new_notes_subdir = "10 Novas notas",
    journal = {
        daily = {
            subdir = "11 Diario/11.01 Diario",
            title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
            template = "08 Templates/Nota diaria",
        },
        weekly = {
            subdir = "11 Diario/11.02 Semanal",
            title_format = "{{iso_year}} semana {{iso_week}}",
        },
        monthly = {
            subdir = "11 Diario/11.03 Mensal",
            title_format = "{{year}} {{month_name}}",
        },
        yearly = {
            subdir = "11 Diario/11.04 Anual",
            title_format = "{{year}}",
        },
    },
    templates = {
        standard = "08 Templates/Nova nota",
    },
}

local obsidian = require("nvim-obsidian")

obsidian.journal.register_placeholder("year", function(ctx)
    return tostring(ctx.date.year)
end, "(%d%d%d%d)")

obsidian.journal.register_placeholder("iso_year", function(ctx)
    return tostring(ctx.date.iso_year)
end, "(%d%d%d%d)")

obsidian.journal.register_placeholder("month_name", function(ctx)
    return ctx.locale.month_name or ""
end, "(.+)")

obsidian.journal.register_placeholder("day2", function(ctx)
    return string.format("%02d", ctx.date.day or 0)
end, "(%d%d?)")

obsidian.journal.register_placeholder("weekday_name", function(ctx)
    return ctx.locale.weekday_name or ""
end, "(.+)")

obsidian.journal.register_placeholder("iso_week", function(ctx)
    return tostring(ctx.date.iso_week)
end, "(%d%d?)")

obsidian.setup(opts)
obsidian.register_placeholder("title", function(ctx)
    return ctx.note.title
end)
obsidian.register_placeholder("date", function(ctx)
    return ctx.time.iso.date
end)

assert_true(wait_until(2000, 20, function()
    return exists_cmd("ObsidianToday") and exists_cmd("ObsidianNext") and exists_cmd("ObsidianPrev") and
        exists_cmd("ObsidianFollow") and exists_cmd("ObsidianReindex")
end), "commands were not registered")

vim.cmd("ObsidianToday")
local today_path = vim.api.nvim_buf_get_name(0)
assert_true(today_path ~= "", "ObsidianToday did not open a file")
assert_true(vim.fn.filereadable(today_path) == 1, "today note file was not created")
assert_true(today_path:find("11 Diario/11.01 Diario", 1, true) ~= nil, "today note not routed to daily dir")

vim.cmd("ObsidianNext")
local next_path = vim.api.nvim_buf_get_name(0)
assert_true(next_path ~= today_path, "ObsidianNext did not move to a different note")
assert_true(vim.fn.filereadable(next_path) == 1, "next note file missing")

vim.cmd("ObsidianPrev")
local prev_path = vim.api.nvim_buf_get_name(0)
assert_true(prev_path == today_path, "ObsidianPrev did not return to today note")

local scanner = require("nvim-obsidian.cache.scanner")
local vault = require("nvim-obsidian.model.vault")
scanner.refresh_all_sync()
local notes = vault.all_notes()
assert_true(#notes >= 2, "cache did not index created journal notes")

local target_path = root .. "/10 Novas notas/Target Note.md"
local linker_path = root .. "/10 Novas notas/Linker.md"
vim.fn.mkdir(root .. "/10 Novas notas", "p")
vim.fn.writefile({ "---", "aliases: [Target Alias]", "tags: [x]", "---", "", "# Target Note" }, target_path)
vim.fn.writefile({ "# Linker", "", "See [[Target Note|Anything]] now." }, linker_path)
scanner.refresh_all_sync()

vim.cmd("edit " .. vim.fn.fnameescape(linker_path))
vim.api.nvim_win_set_cursor(0, { 3, 8 })
vim.cmd("ObsidianFollow")
local followed = vim.api.nvim_buf_get_name(0)
assert_true(followed == target_path, "ObsidianFollow did not resolve wiki link target")

local cmp_source = require("nvim-obsidian.cmp.source").new()
local completed = nil
cmp_source:complete({ context = { cursor_before_line = "[[Tar" } }, function(result)
    completed = result
end)
assert_true(completed ~= nil and type(completed.items) == "table", "cmp source did not return completion payload")

local found_target = false
for _, item in ipairs(completed.items) do
    if item.label == "Target Note" then
        found_target = true
        break
    end
end
assert_true(found_target, "cmp source missing expected note completion")

local watcher_created = root .. "/10 Novas notas/Watcher Created.md"
vim.fn.writefile({ "# Watcher Created" }, watcher_created)
assert_true(wait_until(2500, 50, function()
    return #vault.resolve_by_title_or_alias("Watcher Created", require("nvim-obsidian.config").get()) == 1
end), "filesystem watcher did not index newly created file")

local watcher_renamed = root .. "/10 Novas notas/Watcher Renamed.md"
os.rename(watcher_created, watcher_renamed)
assert_true(wait_until(3000, 50, function()
    local cfg = require("nvim-obsidian.config").get()
    local old_count = #vault.resolve_by_title_or_alias("Watcher Created", cfg)
    local new_count = #vault.resolve_by_title_or_alias("Watcher Renamed", cfg)
    return old_count == 0 and new_count == 1
end), "filesystem watcher did not reconcile rename correctly")

os.remove(watcher_renamed)
assert_true(wait_until(3000, 50, function()
    return #vault.resolve_by_title_or_alias("Watcher Renamed", require("nvim-obsidian.config").get()) == 0
end), "filesystem watcher did not remove deleted file from cache")

print("E2E smoke passed")
