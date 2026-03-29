local errors = require("nvim_obsidian.core.shared.errors")

local M = {}

local TASK_PATTERN = "^(%s*)%- %[(.)%]%s*(.*)$"

local task_cache = {
    by_path = {},
}

local function split_lines(text)
    local src = tostring(text or "")
    if src == "" then
        return {}
    end

    local out = {}
    local start = 1
    while true do
        local nl = src:find("\n", start, true)
        if not nl then
            table.insert(out, src:sub(start))
            break
        end
        table.insert(out, src:sub(start, nl - 1))
        start = nl + 1
    end
    return out
end

local function normalize_path(path)
    local p = tostring(path or "")
    p = p:gsub("\\", "/")
    p = p:gsub("//+", "/")
    return p
end

local function relpath_from_root(path, root)
    local p = normalize_path(path)
    local r = normalize_path(root):gsub("/+$", "")
    if p == "" or r == "" then
        return p
    end
    local prefix = r .. "/"
    if p:sub(1, #prefix) == prefix then
        return p:sub(#prefix + 1)
    end
    return p
end

local function stem(path)
    local p = normalize_path(path)
    local name = p:match("[^/]+$") or p
    return (name:gsub("%.md$", ""))
end

local function parse_iso_date_to_ts(text)
    local y, m, d = tostring(text or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
        return nil
    end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local MONTH_INDEX = {
    january = 1,
    february = 2,
    march = 3,
    april = 4,
    may = 5,
    june = 6,
    july = 7,
    august = 8,
    september = 9,
    october = 10,
    november = 11,
    december = 12,
    janeiro = 1,
    fevereiro = 2,
    marco = 3,
    ["março"] = 3,
    abril = 4,
    maio = 5,
    junho = 6,
    julho = 7,
    agosto = 8,
    setembro = 9,
    outubro = 10,
    novembro = 11,
    dezembro = 12,
}

local function parse_flexible_date_to_ts(text)
    local ts = parse_iso_date_to_ts(text)
    if ts then
        return ts
    end

    local s = tostring(text or "")
    local y, month_name, d = s:match("(%d%d%d%d)%s+([^%s,]+)%s+(%d%d?)")
    if not y then
        return nil
    end

    local month = MONTH_INDEX[string.lower(month_name)]
    if not month then
        return nil
    end

    return os.time({ year = tonumber(y), month = month, day = tonumber(d), hour = 12 })
end

local function note_date_timestamp(path, title, frontmatter)
    local by_path = parse_flexible_date_to_ts(path)
    if by_path then
        return by_path
    end

    local by_title = parse_flexible_date_to_ts(title)
    if by_title then
        return by_title
    end

    if type(frontmatter) == "table" and type(frontmatter.date) == "string" then
        return parse_flexible_date_to_ts(frontmatter.date)
    end

    return nil
end

local function is_absolute_path(path)
    local p = tostring(path or "")
    if p:match("^/") then
        return true
    end
    if p:match("^%a:[/\\]") then
        return true
    end
    return false
end

local function join_path(base, leaf)
    local b = tostring(base or ""):gsub("\\", "/"):gsub("//+", "/"):gsub("/+$", "")
    local l = tostring(leaf or ""):gsub("\\", "/"):gsub("^/", "")
    if b == "" then
        return l
    end
    if l == "" then
        return b
    end
    return b .. "/" .. l
end

local function file_stat(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    if vim and type(vim.uv) == "table" and type(vim.uv.fs_stat) == "function" then
        local ok, stat = pcall(vim.uv.fs_stat, path)
        if ok and type(stat) == "table" then
            local mtime = nil
            if type(stat.mtime) == "number" then
                mtime = stat.mtime
            elseif type(stat.mtime) == "table" then
                mtime = tonumber(stat.mtime.sec)
            end
            local size = tonumber(stat.size)
            if mtime ~= nil or size ~= nil then
                return {
                    mtime = mtime,
                    size = size,
                }
            end
        end
    end

    if vim and type(vim.loop) == "table" and type(vim.loop.fs_stat) == "function" then
        local ok, stat = pcall(vim.loop.fs_stat, path)
        if ok and type(stat) == "table" then
            local mtime = nil
            if type(stat.mtime) == "number" then
                mtime = stat.mtime
            elseif type(stat.mtime) == "table" then
                mtime = tonumber(stat.mtime.sec)
            end
            local size = tonumber(stat.size)
            if mtime ~= nil or size ~= nil then
                return {
                    mtime = mtime,
                    size = size,
                }
            end
        end
    end

    return nil
end

local function collect_markdown_paths(ctx)
    local paths = nil
    if type(ctx.scan_markdown_files) == "function" then
        paths = ctx.scan_markdown_files()
    elseif type(ctx.fs_io) == "table" and type(ctx.fs_io.list_markdown_files) == "function" then
        paths = ctx.fs_io.list_markdown_files(ctx.config and ctx.config.vault_root)
    end

    if type(paths) ~= "table" then
        return nil
    end

    local vault_root = type(ctx.config) == "table" and ctx.config.vault_root or nil
    local dedup = {}
    local out = {}
    for _, p in ipairs(paths) do
        if type(p) == "string" and p ~= "" then
            local candidate = p
            if not is_absolute_path(candidate) and type(vault_root) == "string" and vault_root ~= "" then
                candidate = join_path(vault_root, candidate)
            end
            if not dedup[candidate] then
                dedup[candidate] = true
                table.insert(out, candidate)
            end
        end
    end

    table.sort(out)
    return out
end

local function parse_task_rows_for_file(ctx, abs_path)
    local content = ctx.fs_io.read_file(abs_path)
    if type(content) ~= "string" then
        return {}
    end

    local vault_root = type(ctx.config) == "table" and ctx.config.vault_root or nil
    local relpath = relpath_from_root(abs_path, vault_root)
    local title = stem(abs_path)

    local meta = nil
    if type(ctx.frontmatter) == "table" and type(ctx.frontmatter.parse) == "function" then
        local parsed = ctx.frontmatter.parse(content)
        if type(parsed) == "table" then
            meta = parsed
        end
    end

    local ts = note_date_timestamp(relpath, title, meta)
    local rows = {}
    for line_no, line in ipairs(split_lines(content)) do
        local _, mark, text = line:match(TASK_PATTERN)
        if mark then
            table.insert(rows, {
                checked = mark ~= " ",
                text = tostring(text or ""),
                raw = line,
                line = line_no,
                file = {
                    path = relpath,
                    title = title,
                    name = title,
                    link = {
                        date = ts,
                    },
                },
            })
        end
    end

    return rows
end

local function collect_task_rows(ctx, query)
    if type(query) ~= "table" or query.kind ~= "task" then
        return nil
    end

    local paths = collect_markdown_paths(ctx)

    if type(paths) ~= "table" then
        return nil
    end

    if type(ctx.fs_io) ~= "table" or type(ctx.fs_io.read_file) ~= "function" then
        return nil
    end

    local task_rows = {}
    local seen = {}

    for _, abs_path in ipairs(paths) do
        seen[abs_path] = true
        local stat = file_stat(abs_path)
        local cached = task_cache.by_path[abs_path]

        local should_reparse = true
        if cached and stat and cached.mtime == stat.mtime and cached.size == stat.size then
            should_reparse = false
        elseif cached and not stat and type(cached.rows) == "table" then
            -- No stat support available; keep behavior correct by reparsing.
            should_reparse = true
        end

        if should_reparse then
            local rows = parse_task_rows_for_file(ctx, abs_path)
            task_cache.by_path[abs_path] = {
                mtime = stat and stat.mtime or nil,
                size = stat and stat.size or nil,
                rows = rows,
            }
            cached = task_cache.by_path[abs_path]
        end

        if cached and type(cached.rows) == "table" then
            for _, row in ipairs(cached.rows) do
                table.insert(task_rows, row)
            end
        end
    end

    for cached_path, _ in pairs(task_cache.by_path) do
        if not seen[cached_path] then
            task_cache.by_path[cached_path] = nil
        end
    end

    return task_rows
end

M.contract = {
    name = "render_query_blocks",
    version = "phase3-contract",
    dependencies = {
        "dataview",
        "vault_catalog",
        "parser.markdown",
        "neovim.navigation",
        "neovim.notifications",
    },
    input = {
        buffer = "integer",
        trigger = "on_open|on_save|manual",
    },
    output = {
        ok = "boolean",
        rendered_blocks = "integer|nil",
        error = "domain_error|nil",
    },
}

function M.execute(_ctx, _input)
    if type(_ctx) ~= "table" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "ctx must be a table"),
        }
    end
    if type(_input) ~= "table" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "input must be a table"),
        }
    end

    local ctx = _ctx
    local input = _input

    local function invalid(message)
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INVALID_INPUT, message),
        }
    end

    if type(input.buffer) ~= "number" then
        return invalid("buffer must be an integer")
    end

    local trigger = input.trigger
    if trigger ~= "on_open" and trigger ~= "on_save" and trigger ~= "manual" then
        return invalid("trigger must be on_open|on_save|manual")
    end

    local dataview = ctx.dataview
    local vault_catalog = ctx.vault_catalog

    if type(dataview) ~= "table" or type(dataview.parse_blocks) ~= "function" or type(dataview.execute_query) ~= "function" then
        return invalid("ctx.dataview parse/execute functions are required")
    end

    if type(vault_catalog) ~= "table" then
        return invalid("ctx.vault_catalog is required")
    end

    local get_buffer_markdown = ctx.get_buffer_markdown
    if type(get_buffer_markdown) ~= "function" and type(ctx.navigation) == "table" then
        get_buffer_markdown = ctx.navigation.get_buffer_markdown
    end

    if type(get_buffer_markdown) ~= "function" then
        return invalid("buffer markdown reader is required")
    end

    local apply_rendered_blocks = ctx.apply_rendered_blocks
    if type(apply_rendered_blocks) ~= "function" and type(ctx.navigation) == "table" then
        apply_rendered_blocks = ctx.navigation.apply_rendered_blocks
    end

    if type(apply_rendered_blocks) ~= "function" then
        return invalid("render patch applier is required")
    end

    local function trigger_enabled(cfg_when)
        if trigger == "manual" then
            return true
        end

        if type(cfg_when) ~= "table" then
            return false
        end

        for _, configured in ipairs(cfg_when) do
            if configured == trigger then
                return true
            end
        end

        -- Backward-compatible explicit map shape: { open = true, save = false }
        local mapped = trigger:gsub("^on_", "")
        if cfg_when[mapped] ~= nil then
            return cfg_when[mapped] == true
        end

        return false
    end

    if type(ctx.config) ~= "table" or type(ctx.config.dataview) ~= "table" then
        return invalid("ctx.config.dataview is required")
    end

    local dataview_cfg = ctx.config.dataview
    if type(dataview_cfg.render) ~= "table" or type(dataview_cfg.render.when) ~= "table" then
        return invalid("ctx.config.dataview.render.when is required")
    end

    if not trigger_enabled(dataview_cfg.render.when) then
        return {
            ok = true,
            rendered_blocks = 0,
            error = nil,
        }
    end

    local markdown = get_buffer_markdown(input.buffer)
    if type(markdown) ~= "string" then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to read current buffer markdown"),
        }
    end

    local parsed = dataview.parse_blocks(markdown)
    local blocks = {}
    if type(parsed) == "table" and type(parsed.blocks) == "table" then
        blocks = parsed.blocks
    elseif parsed ~= nil then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "dataview.parse_blocks returned invalid result"),
        }
    end

    local function collect_notes()
        if type(vault_catalog.list_notes) ~= "function" then
            return nil, "ctx.vault_catalog.list_notes is required"
        end
        local notes = vault_catalog.list_notes()
        if type(notes) ~= "table" then
            return nil, "vault_catalog.list_notes returned invalid result"
        end
        return notes, nil
    end

    local notes, notes_err = collect_notes()
    if not notes then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, notes_err),
        }
    end

    local msg_holder = dataview_cfg.messages
    if type(msg_holder) ~= "table" and type(dataview_cfg.render) == "table" then
        msg_holder = dataview_cfg.render.messages
    end

    local no_results_cfg = type(msg_holder) == "table" and msg_holder.task_no_results or nil
    if type(no_results_cfg) ~= "table" then
        return invalid("ctx.config.dataview.messages.task_no_results is required")
    end
    if type(no_results_cfg.enabled) ~= "boolean" then
        return invalid("ctx.config.dataview.messages.task_no_results.enabled must be boolean")
    end
    if type(no_results_cfg.text) ~= "string" or no_results_cfg.text == "" then
        return invalid("ctx.config.dataview.messages.task_no_results.text must be non-empty string")
    end

    local no_results_enabled = no_results_cfg.enabled
    local no_results_text = no_results_cfg.text

    local overlays = {}

    local placement = dataview_cfg.placement
    if placement ~= "below_block" and placement ~= "above_block" then
        return invalid("ctx.config.dataview.placement must be below_block|above_block")
    end

    for _, block in ipairs(blocks) do
        local source_rows = notes
        local task_rows = collect_task_rows(ctx, block.query)
        if type(task_rows) == "table" then
            source_rows = task_rows
        end

        local exec = dataview.execute_query(block, source_rows)
        local lines = {}

        if exec and exec.error then
            local message = type(exec.error.message) == "string" and exec.error.message or "query execution failed"
            table.insert(lines, {
                text = "Dataview: " .. message,
                highlight = "error",
            })
        else
            local result = type(exec) == "table" and exec.result or nil
            if type(result) ~= "table" then
                return {
                    ok = false,
                    rendered_blocks = nil,
                    error = errors.new(errors.codes.INTERNAL, "dataview.execute_query returned invalid result"),
                }
            end

            local rendered = result.rendered_lines
            if type(rendered) ~= "table" then
                return {
                    ok = false,
                    rendered_blocks = nil,
                    error = errors.new(errors.codes.INTERNAL, "dataview query result missing rendered_lines table"),
                }
            end

            if result.kind == "task" and #rendered == 0 and no_results_enabled then
                table.insert(lines, {
                    text = no_results_text,
                    highlight = "task_no_results",
                })
            else
                for _, line in ipairs(rendered) do
                    if type(line) == "table" and type(line.text) == "string" then
                        table.insert(lines, line)
                    else
                        table.insert(lines, {
                            text = tostring(line),
                            highlight = "task_text",
                        })
                    end
                end
            end
        end

        table.insert(overlays, {
            anchor_line = block.end_line,
            placement = placement,
            lines = lines,
        })
    end

    local applied, apply_err = apply_rendered_blocks(input.buffer, overlays, dataview_cfg.highlights)
    if not applied then
        return {
            ok = false,
            rendered_blocks = nil,
            error = errors.new(errors.codes.INTERNAL, "failed to apply dataview render patches", {
                reason = apply_err,
            }),
        }
    end

    if type(parsed) == "table" and parsed.error and type(ctx.notifications) == "table" and type(ctx.notifications.warn) == "function" then
        local message = type(parsed.error.message) == "string" and parsed.error.message or "parse failed"
        ctx.notifications.warn("Dataview parse warning: " .. message)
    end

    return {
        ok = true,
        rendered_blocks = #overlays,
        error = nil,
    }
end

return M
