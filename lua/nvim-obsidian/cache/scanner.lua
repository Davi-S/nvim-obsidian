local config = require("nvim-obsidian.config")
local path = require("nvim-obsidian.path")
local parser = require("nvim-obsidian.parser.frontmatter")
local markdown_parser = require("nvim-obsidian.parser.markdown")
local vault = require("nvim-obsidian.model.vault")
local classifier = require("nvim-obsidian.journal.classifier")
local async_constants = require("nvim-obsidian.async.constants")

local M = {}

-- Dependency injection: store references to dependencies (default to real modules)
local _config = config
local _vault = vault
local _parser = parser
local _classifier = classifier

local reconcile_timer = nil
local watch_restart_timer = nil
local watchers = {
    handles = {},
    by_dir = {},
}

local refresh_state = {
    token = 0,
    in_progress = false,
}

local function abort_active_refresh()
    if refresh_state.in_progress then
        refresh_state.token = refresh_state.token + 1
        refresh_state.in_progress = false
        -- Ensure indexes are not left stale if a previous async refresh is interrupted.
        pcall(function()
            _vault.end_bulk_update()
        end)
    end
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
    local cfg = _config.get()
    if not cfg then
        return
    end
    local nabs = path.normalize(abs)
    if not path.is_inside(cfg.vault_root, nabs) then
        return
    end
    if vim.fn.filereadable(nabs) == 0 then
        _vault.remove_note(nabs)
        return
    end
    local text = table.concat(vim.fn.readfile(nabs), "\n")
    local meta = _parser.parse(text)
    local headings = markdown_parser.extract_headings(text)
    local blocks = markdown_parser.extract_blocks(text)
    _vault.upsert_note(nabs, {
        relpath = path.rel_to_root(cfg.vault_root, nabs),
        aliases = meta.aliases,
        tags = meta.tags,
        headings = headings,
        blocks = blocks,
        frontmatter = meta,
        note_type = _classifier.note_type_for_path(nabs, cfg),
    })
end

function M.refresh_all_sync()
    abort_active_refresh()

    local cfg = _config.get()
    if not cfg then
        return
    end

    local files = {}
    scan_recursive(cfg.vault_root, files)

    _vault.begin_bulk_update()
    _vault.reset()
    for _, file in ipairs(files) do
        M.refresh_one(file)
    end
    _vault.end_bulk_update()
end

function M.refresh_all_async(cb)
    abort_active_refresh()

    local cfg = _config.get()
    if not cfg then
        if cb then
            cb()
        end
        return
    end

    local files = {}
    scan_recursive(cfg.vault_root, files)

    local batch_size = async_constants.SCANNER_BATCH_SIZE or 40
    local batch_delay_ms = async_constants.SCANNER_BATCH_DELAY_MS or 1

    refresh_state.token = refresh_state.token + 1
    local my_token = refresh_state.token
    refresh_state.in_progress = true

    _vault.begin_bulk_update()
    _vault.reset()

    local idx = 1

    local function finish()
        if refresh_state.token ~= my_token then
            return
        end
        _vault.end_bulk_update()
        refresh_state.in_progress = false
        if cb then
            cb()
        end
    end

    local function step()
        if refresh_state.token ~= my_token then
            return
        end

        local last = math.min(idx + batch_size - 1, #files)
        for i = idx, last do
            M.refresh_one(files[i])
        end
        idx = last + 1

        if idx <= #files then
            vim.defer_fn(step, batch_delay_ms)
        else
            finish()
        end
    end

    vim.schedule(function()
        if #files == 0 then
            finish()
            return
        end
        step()
    end)
end

function M.reconcile_async()
    if reconcile_timer then
        reconcile_timer:stop()
        reconcile_timer:close()
        reconcile_timer = nil
    end

    reconcile_timer = vim.uv.new_timer()
    reconcile_timer:start(async_constants.RECONCILE_DEBOUNCE_MS, 0, function()
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
    watch_restart_timer:start(async_constants.WATCHER_RESTART_DELAY_MS, 0, function()
        vim.schedule(function()
            M.start_fs_watchers()
        end)
        watch_restart_timer:stop()
        watch_restart_timer:close()
        watch_restart_timer = nil
    end)
end

function M.start_fs_watchers()
    local cfg = _config.get()
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
                        _vault.remove_note(changed_norm)
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
    local cfg = _config.get()
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
                    _vault.remove_note(prev)
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
                _vault.remove_note(path.normalize(file))
            end
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

--- Initialize scanner with optional dependency injection (for testing)
--- @param opts table Optional: { config = ..., vault = ..., parser = ..., classifier = ... }
function M.init(opts)
    opts = opts or {}
    if opts.config then _config = opts.config end
    if opts.vault then _vault = opts.vault end
    if opts.parser then _parser = opts.parser end
    if opts.classifier then _classifier = opts.classifier end
end

return M
