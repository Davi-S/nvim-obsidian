local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local parser = require("nvim-obsidian.parser.frontmatter")
local vault = require("nvim-obsidian.model.vault")

local M = {}
local reconcile_timer = nil
local watch_restart_timer = nil
local watchers = {
    handles = {},
    by_dir = {},
}

local function note_type_for_path(abs, cfg)
    if not cfg.journal_enabled then
        return "standard"
    end

    local parent = path.normalize(path.parent(abs))
    if parent == path.normalize(cfg.journal.daily.dir_abs) then
        return "daily"
    end
    if parent == path.normalize(cfg.journal.weekly.dir_abs) then
        return "weekly"
    end
    if parent == path.normalize(cfg.journal.monthly.dir_abs) then
        return "monthly"
    end
    if parent == path.normalize(cfg.journal.yearly.dir_abs) then
        return "yearly"
    end
    return "standard"
end

local function scan_recursive(root, out)
    local fd = vim.uv.fs_scandir(root)
    if not fd then
        return
    end
    while true do
        local name, t = vim.uv.fs_scandir_next(fd)
        if not name then
            break
        end
        local abs = path.join(root, name)
        if t == "directory" then
            scan_recursive(abs, out)
        elseif t == "file" and abs:sub(-3) == ".md" then
            table.insert(out, path.normalize(abs))
        end
    end
end

local function scan_directories_recursive(root, out)
    table.insert(out, path.normalize(root))
    local fd = vim.uv.fs_scandir(root)
    if not fd then
        return
    end

    while true do
        local name, t = vim.uv.fs_scandir_next(fd)
        if not name then
            break
        end
        if t == "directory" then
            scan_directories_recursive(path.join(root, name), out)
        end
    end
end

local function stop_all_watchers()
    for _, handle in ipairs(watchers.handles) do
        if not handle:is_closing() then
            handle:stop()
            handle:close()
        end
    end
    watchers.handles = {}
    watchers.by_dir = {}
end

function M.refresh_one(abs)
    local cfg = config.get()
    if not cfg then
        return
    end
    local nabs = path.normalize(abs)
    if not path.is_inside(cfg.vault_root, nabs) then
        return
    end
    if vim.fn.filereadable(nabs) == 0 then
        vault.remove_note(nabs)
        return
    end
    local text = table.concat(vim.fn.readfile(nabs), "\n")
    local meta = parser.parse(text)
    vault.upsert_note(nabs, {
        relpath = path.rel_to_root(cfg.vault_root, nabs),
        aliases = meta.aliases,
        tags = meta.tags,
        frontmatter = meta,
        note_type = note_type_for_path(nabs, cfg),
    })
end

function M.refresh_all_sync()
    local cfg = config.get()
    if not cfg then
        return
    end

    local files = {}
    scan_recursive(cfg.vault_root, files)

    vault.begin_bulk_update()
    vault.reset()
    for _, file in ipairs(files) do
        M.refresh_one(file)
    end
    vault.end_bulk_update()
end

function M.refresh_all_async(cb)
    vim.schedule(function()
        M.refresh_all_sync()
        if cb then
            cb()
        end
    end)
end

function M.reconcile_async()
    if reconcile_timer then
        reconcile_timer:stop()
        reconcile_timer:close()
        reconcile_timer = nil
    end

    reconcile_timer = vim.uv.new_timer()
    reconcile_timer:start(200, 0, function()
        vim.schedule(function()
            M.refresh_all_sync()
        end)
        reconcile_timer:stop()
        reconcile_timer:close()
        reconcile_timer = nil
    end)
end

local function restart_watchers_async()
    if watch_restart_timer then
        watch_restart_timer:stop()
        watch_restart_timer:close()
        watch_restart_timer = nil
    end

    watch_restart_timer = vim.uv.new_timer()
    watch_restart_timer:start(350, 0, function()
        vim.schedule(function()
            M.start_fs_watchers()
        end)
        watch_restart_timer:stop()
        watch_restart_timer:close()
        watch_restart_timer = nil
    end)
end

function M.start_fs_watchers()
    local cfg = config.get()
    if not cfg then
        return
    end

    stop_all_watchers()

    local dirs = {}
    scan_directories_recursive(cfg.vault_root, dirs)

    for _, dir in ipairs(dirs) do
        if not watchers.by_dir[dir] then
            local watch_dir = dir
            local handle = vim.uv.new_fs_event()
            local started = handle:start(watch_dir, {}, function(err, filename, _)
                if err then
                    return
                end

                vim.schedule(function()
                    if not filename or filename == "" then
                        M.reconcile_async()
                        return
                    end

                    local changed_path = path.join(watch_dir, filename)
                    local changed_norm = path.normalize(changed_path)

                    if vim.fn.isdirectory(changed_norm) == 1 then
                        restart_watchers_async()
                        return
                    end

                    if changed_norm:sub(-3) ~= ".md" then
                        return
                    end

                    if vim.fn.filereadable(changed_norm) == 1 then
                        M.refresh_one(changed_norm)
                    else
                        vault.remove_note(changed_norm)
                        M.reconcile_async()
                    end
                end)
            end)

            if started then
                watchers.by_dir[watch_dir] = true
                table.insert(watchers.handles, handle)
            else
                if not handle:is_closing() then
                    handle:close()
                end
            end
        end
    end
end

function M.setup_autocmds()
    local cfg = config.get()
    local group = vim.api.nvim_create_augroup("NvimObsidianCacheSync", { clear = true })

    vim.api.nvim_create_autocmd({ "BufFilePre" }, {
        group = group,
        pattern = "*.md",
        callback = function(args)
            local old = vim.api.nvim_buf_get_name(args.buf)
            if old ~= "" and path.is_inside(cfg.vault_root, old) then
                vim.b[args.buf].nvim_obsidian_prev_path = path.normalize(old)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufNewFile", "BufFilePost" }, {
        group = group,
        pattern = "*.md",
        callback = function(args)
            local file = args.file
            if file and file ~= "" and path.is_inside(cfg.vault_root, file) then
                local prev = vim.b[args.buf].nvim_obsidian_prev_path
                if prev and prev ~= "" and prev ~= path.normalize(file) then
                    vault.remove_note(prev)
                end
                vim.b[args.buf].nvim_obsidian_prev_path = nil
                M.refresh_one(file)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufDelete" }, {
        group = group,
        pattern = "*.md",
        callback = function(args)
            local file = args.file
            if file and file ~= "" and path.is_inside(cfg.vault_root, file) then
                vault.remove_note(path.normalize(file))
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "FocusGained" }, {
        group = group,
        callback = function()
            M.reconcile_async()
        end,
    })

    vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        group = group,
        callback = function()
            stop_all_watchers()
            if reconcile_timer then
                reconcile_timer:stop()
                reconcile_timer:close()
                reconcile_timer = nil
            end
            if watch_restart_timer then
                watch_restart_timer:stop()
                watch_restart_timer:close()
                watch_restart_timer = nil
            end
        end,
    })

    M.start_fs_watchers()
end

return M
