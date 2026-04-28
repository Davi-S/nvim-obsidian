local errors = require("nvim_obsidian.core.shared.errors")

---Domain implementation: dataview parser and query evaluator.
---
---This module is pure and deterministic. It parses fenced dataview blocks and
---evaluates query clauses against normalized note rows.
local M = {}

local function trim(s)
    local text = tostring(s or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

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

local function normalize_tag(tag)
    local t = trim(tag):lower()
    if t:sub(1, 1) == "#" then
        t = t:sub(2)
    end
    return t
end

local function note_has_tag(note, tag)
    if type(note.tags) ~= "table" then
        return false
    end

    local target = normalize_tag(tag)
    if target == "" then
        return false
    end

    for _, raw in ipairs(note.tags) do
        if normalize_tag(raw) == target then
            return true
        end
    end
    return false
end

local function parse_block_query(body_lines)
    local lines = {}
    for _, raw in ipairs(body_lines or {}) do
        local t = trim(raw)
        if t ~= "" then
            table.insert(lines, t)
        end
    end

    if #lines == 0 then
        return nil, errors.new(errors.codes.PARSE_FAILURE, "empty dataview query block")
    end

    local query = {
        kind = nil,
        from_kind = nil,
        from_value = nil,
        projections = {},
        where_expr = nil,
        group_by = nil,
        group_alias = nil,
        sort_field = nil,
        sort_dir = "ASC",
    }

    local i = 1
    local first = lines[i]
    if first:upper() == "TASK" then
        query.kind = "task"
        i = i + 1
    elseif first:upper() == "TABLE WITHOUT ID" then
        query.kind = "table"
        i = i + 1
        while i <= #lines and not lines[i]:match("^FROM%s+") do
            local expr, label = lines[i]:match('^(.-)%s+AS%s+"([^"]+)"%s*,?$')
            expr = trim(expr)
            label = trim(label)
            if expr == "" or label == "" then
                return nil, errors.new(errors.codes.PARSE_FAILURE, "invalid TABLE projection")
            end
            table.insert(query.projections, { expr = expr, label = label })
            i = i + 1
        end
        if #query.projections == 0 then
            return nil, errors.new(errors.codes.PARSE_FAILURE, "missing TABLE projections")
        end
    else
        return nil, errors.new(errors.codes.PARSE_FAILURE, "unsupported dataview query type")
    end

    if i > #lines then
        return nil, errors.new(errors.codes.PARSE_FAILURE, "missing FROM clause")
    end

    local from_line = lines[i]
    local from_path = from_line:match('^FROM%s+"([^"]+)"$')
    local from_tag = from_line:match('^FROM%s+#([^%s]+)$')
    if from_path then
        query.from_kind = "path"
        query.from_value = from_path
    elseif from_tag then
        query.from_kind = "tag"
        query.from_value = from_tag
    else
        return nil, errors.new(errors.codes.PARSE_FAILURE, "invalid FROM clause")
    end

    i = i + 1
    while i <= #lines do
        local line = lines[i]
        local where_expr = line:match("^WHERE%s+(.+)$")
        if where_expr then
            if query.where_expr ~= nil then
                return nil, errors.new(errors.codes.PARSE_FAILURE, "duplicate WHERE clause")
            end
            query.where_expr = trim(where_expr)
            if query.where_expr == "" then
                return nil, errors.new(errors.codes.PARSE_FAILURE, "invalid WHERE clause")
            end
            i = i + 1
        else
            local group_field, group_alias = line:match("^GROUP%s+BY%s+([^%s]+)%s+AS%s+([A-Za-z0-9_]+)$")
            if group_field then
                if query.kind ~= "task" then
                    return nil, errors.new(errors.codes.PARSE_FAILURE, "GROUP BY is only supported for TASK")
                end
                if query.group_by ~= nil then
                    return nil, errors.new(errors.codes.PARSE_FAILURE, "duplicate GROUP BY clause")
                end
                query.group_by = group_field
                query.group_alias = group_alias
                i = i + 1
            else
                local field, dir = line:match("^SORT%s+([^%s]+)%s+([A-Za-z]+)$")
                if field then
                    dir = dir:upper()
                    if dir ~= "ASC" and dir ~= "DESC" then
                        return nil,
                            errors.new(errors.codes.PARSE_FAILURE, "unsupported SORT direction: " .. tostring(dir))
                    end
                    query.sort_field = field
                    query.sort_dir = dir
                    i = i + 1
                else
                    return nil, errors.new(errors.codes.PARSE_FAILURE, "unsupported clause: " .. line)
                end
            end
        end
    end

    return query, nil
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

    return os.time({
        year = tonumber(y),
        month = month,
        day = tonumber(d),
        hour = 12,
    })
end

local function normalize_path(path)
    return tostring(path or ""):gsub("\\", "/"):gsub("//+", "/")
end

local function path_matches_prefix(path, from_value)
    local p = normalize_path(path)
    local prefix = normalize_path(from_value)

    if prefix == "" then
        return true
    end
    if prefix:sub(-1) ~= "/" then
        prefix = prefix .. "/"
    end

    if p:sub(1, #prefix) == prefix then
        return true
    end

    return p:find("/" .. prefix, 1, true) ~= nil
end

local function tokenize_where(expr)
    local s = tostring(expr or "")
    local tokens = {}
    local i = 1

    local function add(kind, value)
        table.insert(tokens, { kind = kind, value = value })
    end

    while i <= #s do
        local ch = s:sub(i, i)
        if ch:match("%s") then
            i = i + 1
        elseif ch == "(" then
            add("LPAREN", ch)
            i = i + 1
        elseif ch == ")" then
            add("RPAREN", ch)
            i = i + 1
        elseif ch == "!" then
            if s:sub(i, i + 1) == "!=" then
                add("OP", "!=")
                i = i + 2
            else
                add("NOT", "!")
                i = i + 1
            end
        elseif s:sub(i, i + 1) == "<=" or s:sub(i, i + 1) == ">=" then
            add("OP", s:sub(i, i + 1))
            i = i + 2
        elseif ch == "<" or ch == ">" or ch == "=" then
            add("OP", ch)
            i = i + 1
        elseif s:sub(i, i + 4):lower() == "date(" then
            local close_pos = s:find(")", i + 5, true)
            if not close_pos then
                return nil, "unclosed date() literal"
            end

            local date_text = trim(s:sub(i + 5, close_pos - 1))
            local dq = date_text:match('^"(.*)"$')
            if dq then
                date_text = dq
            else
                local sq = date_text:match("^'(.*)'$")
                if sq then
                    date_text = sq
                end
            end

            if not date_text:match("^%d%d%d%d%-%d%d%-%d%d$") then
                return nil, "invalid date format"
            end

            add("DATE", date_text)
            i = close_pos + 1
        else
            local word = s:sub(i):match("^([^%s%(%)!<>=]+)")
            if not word then
                return nil, "invalid token"
            end
            local upper = word:upper()
            if upper == "AND" then
                add("AND", "AND")
            elseif upper == "OR" then
                add("OR", "OR")
            elseif upper == "TRUE" then
                add("BOOL", true)
            elseif upper == "FALSE" then
                add("BOOL", false)
            else
                local num = tonumber(word)
                if num ~= nil then
                    add("NUMBER", num)
                else
                    add("IDENT", word)
                end
            end
            i = i + #word
        end
    end

    return tokens, nil
end

local function resolve_value(row, ident)
    if ident == "checked" then
        return row.checked
    end

    local current = row
    for part in ident:gmatch("[^%.]+") do
        if type(current) == "string" then
            local y, m, d = current:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
            if y and m and d then
                if part == "year" then
                    current = tonumber(y)
                elseif part == "month" then
                    current = tonumber(m)
                elseif part == "day" then
                    current = tonumber(d)
                else
                    return nil
                end
            else
                return nil
            end
        elseif type(current) ~= "table" then
            return nil
        else
            current = current[part]
        end
    end
    return current
end

local function evaluate_where(expr, row)
    if type(expr) ~= "string" or trim(expr) == "" then
        return true, nil
    end

    local tokens, token_err = tokenize_where(expr)
    if not tokens then
        return nil, token_err
    end

    local pos = 1
    local function peek()
        return tokens[pos]
    end
    local function take(kind)
        local t = tokens[pos]
        if t and t.kind == kind then
            pos = pos + 1
            return t
        end
        return nil
    end

    local parse_expr
    local function parse_value()
        local t = peek()
        if not t then
            return nil, "unexpected end", nil, false
        end
        if t.kind == "IDENT" then
            pos = pos + 1
            local resolved = resolve_value(row, t.value)
            return resolved, nil, t.value, resolved ~= nil
        end
        if t.kind == "BOOL" or t.kind == "NUMBER" then
            pos = pos + 1
            return t.value, nil, nil, true
        end
        if t.kind == "DATE" then
            pos = pos + 1
            return parse_iso_date_to_ts(t.value), nil, nil, true
        end
        return nil, "expected value", nil, false
    end

    local function eval_cmp(lhs, op, rhs)
        if lhs == nil or rhs == nil then
            return false
        end
        if op == "=" then
            return lhs == rhs
        end
        if op == "!=" then
            return lhs ~= rhs
        end
        if op == "<" then
            return lhs < rhs
        end
        if op == ">" then
            return lhs > rhs
        end
        if op == "<=" then
            return lhs <= rhs
        end
        if op == ">=" then
            return lhs >= rhs
        end
        return false
    end

    local function parse_primary()
        if take("LPAREN") then
            local v, err = parse_expr()
            if err then
                return nil, err
            end
            if not take("RPAREN") then
                return nil, "missing ')'"
            end
            return v, nil
        end

        local lhs, lhs_err, lhs_ident, lhs_is_resolved = parse_value()
        if lhs_err then
            return nil, lhs_err
        end

        local op = take("OP")
        if op then
            local rhs, rhs_err, rhs_ident, rhs_is_resolved = parse_value()
            if rhs_err then
                return nil, rhs_err
            end

            -- Dataview allows bare words on the RHS, e.g. "title = Alpha".
            if rhs == nil and rhs_ident and not rhs_is_resolved then
                rhs = rhs_ident
            end
            if lhs == nil and lhs_ident and not lhs_is_resolved then
                lhs = lhs_ident
            end

            return eval_cmp(lhs, op.value, rhs), nil
        end

        if type(lhs) == "boolean" then
            return lhs, nil
        end
        return lhs ~= nil, nil
    end

    local function parse_not()
        if take("NOT") then
            local v, err = parse_not()
            if err then
                return nil, err
            end
            return not v, nil
        end
        return parse_primary()
    end

    local function parse_and()
        local lhs, err = parse_not()
        if err then
            return nil, err
        end
        while take("AND") do
            local rhs, rhs_err = parse_not()
            if rhs_err then
                return nil, rhs_err
            end
            lhs = lhs and rhs
        end
        return lhs, nil
    end

    local function parse_or()
        local lhs, err = parse_and()
        if err then
            return nil, err
        end
        while take("OR") do
            local rhs, rhs_err = parse_and()
            if rhs_err then
                return nil, rhs_err
            end
            lhs = lhs or rhs
        end
        return lhs, nil
    end

    parse_expr = parse_or
    local out, out_err = parse_expr()
    if out_err then
        return nil, out_err
    end
    if pos <= #tokens then
        return nil, "unexpected token"
    end
    return not not out, nil
end

local function sort_rows(rows, query)
    local field = query.sort_field
    if not field then
        table.sort(rows, function(a, b)
            local ap = tostring(a.file and a.file.path or "")
            local bp = tostring(b.file and b.file.path or "")
            if ap == bp then
                local al = tonumber(a.line)
                local bl = tonumber(b.line)
                if al ~= nil and bl ~= nil and al ~= bl then
                    return al < bl
                end
                return tostring(a.text or "") < tostring(b.text or "")
            end
            return ap < bp
        end)
        return
    end

    table.sort(rows, function(a, b)
        local av = resolve_value(a, field)
        local bv = resolve_value(b, field)
        if av == bv then
            local ap = tostring(a.file and a.file.path or "")
            local bp = tostring(b.file and b.file.path or "")
            if ap == bp then
                local al = tonumber(a.line)
                local bl = tonumber(b.line)
                if al ~= nil and bl ~= nil and al ~= bl then
                    return al < bl
                end
            end
            return ap < bp
        end
        if query.sort_dir == "DESC" then
            return (av or 0) > (bv or 0)
        end
        return (av or 0) < (bv or 0)
    end)
end

local function sort_groups(groups, query)
    if not query.sort_field then
        table.sort(groups, function(a, b)
            return tostring(a.key or "") < tostring(b.key or "")
        end)
        return
    end

    table.sort(groups, function(a, b)
        local av = resolve_value({ [query.group_alias or ""] = a.group_key, group = a.group_key }, query.sort_field)
        local bv = resolve_value({ [query.group_alias or ""] = b.group_key, group = b.group_key }, query.sort_field)
        if av == bv then
            return tostring(a.key or "") < tostring(b.key or "")
        end
        if query.sort_dir == "DESC" then
            return (av or 0) > (bv or 0)
        end
        return (av or 0) < (bv or 0)
    end)
end

local function row_matches_from(row, query)
    if query.from_kind == "path" then
        local path = tostring((row.file and row.file.path) or row.path or "")
        return path_matches_prefix(path, query.from_value)
    end

    if query.from_kind == "tag" then
        return note_has_tag(row, query.from_value)
    end

    return false
end

local function to_task_row(note)
    local path = tostring(note.path or "")
    local title = tostring(note.title or "")
    local stem = path:match("([^/]+)%.md$") or path
    local ts = parse_flexible_date_to_ts(stem) or parse_flexible_date_to_ts(title)

    return {
        checked = note.checked == true,
        text = tostring(note.text or title),
        raw = tostring(note.raw or ("- [ ] [[" .. title .. "]]")),
        tags = type(note.tags) == "table" and note.tags or {},
        file = {
            path = path,
            name = title,
            title = title,
            link = {
                date = ts,
            },
        },
    }
end

---Parse markdown and extract dataview query blocks.
---@param markdown string
---@return table[] blocks
---@return table|nil error
function M.parse_blocks(markdown)
    if type(markdown) ~= "string" then
        return {
            blocks = {},
            error = errors.new(errors.codes.INVALID_INPUT, "markdown must be a string"),
        }
    end

    local lines = split_lines(markdown)
    local blocks = {}
    local i = 1

    while i <= #lines do
        if trim(lines[i]):lower() == "```dataview" then
            local start_line = i
            local j = i + 1
            while j <= #lines and trim(lines[j]) ~= "```" do
                j = j + 1
            end

            if j > #lines then
                return {
                    blocks = blocks,
                    error = errors.new(errors.codes.PARSE_FAILURE, "unclosed dataview block"),
                }
            end

            local body = {}
            for k = i + 1, j - 1 do
                table.insert(body, lines[k])
            end

            local query, query_err = parse_block_query(body)
            if query_err then
                return {
                    blocks = blocks,
                    error = query_err,
                }
            end

            table.insert(blocks, {
                start_line = start_line,
                end_line = j,
                body_lines = body,
                query = query,
            })

            i = j + 1
        else
            i = i + 1
        end
    end

    return {
        blocks = blocks,
        error = nil,
    }
end

local function note_matches_from(note, query)
    if query.from_kind == "path" then
        return path_matches_prefix(note.path or "", query.from_value)
    end

    if query.from_kind == "tag" then
        return note_has_tag(note, query.from_value)
    end

    return false
end

local function apply_where_rows(rows, query)
    if query.where_expr == nil then
        return rows, nil
    end

    local out = {}
    for _, row in ipairs(rows) do
        local ok, err = evaluate_where(query.where_expr, row)
        if ok == nil then
            return nil, err
        end
        if ok then
            table.insert(out, row)
        end
    end
    return out, nil
end

local function table_cell(note, expr)
    local trimmed = trim(expr)
    if trimmed == "" then
        return ""
    end

    if trimmed == "file.link" then
        return tostring(note.title or "")
    end
    if trimmed == "title" then
        return tostring(note.title or "")
    end
    if trimmed == "file.path" then
        return tostring(note.path or "")
    end
    if trimmed == "aliases.count" then
        return tostring(type(note.aliases) == "table" and #note.aliases or 0)
    end

    local lhs, rhs = trimmed:match("^(%-?%d+)%s*%-%s*([%w_%.-]+)$")
    if lhs and rhs then
        local right_value = resolve_value(note, rhs)
        local left_num = tonumber(lhs)
        local right_num = tonumber(right_value)
        if left_num ~= nil and right_num ~= nil then
            return tostring(left_num - right_num)
        end
    end

    local resolved = resolve_value(note, trimmed)
    if resolved == nil then
        return ""
    end
    return tostring(resolved)
end

local function pad_cell(text, width, align_right)
    local value = tostring(text or "")
    local function display_width(s)
        if type(vim) == "table" and type(vim.fn) == "table" and type(vim.fn.strdisplaywidth) == "function" then
            local ok, w = pcall(vim.fn.strdisplaywidth, s)
            if ok and type(w) == "number" then
                return w
            end
        end
        return #s
    end

    local value_width = display_width(value)
    local cell_width = tonumber(width) or value_width
    if cell_width < value_width then
        cell_width = value_width
    end

    local pad = cell_width - value_width
    if pad < 0 then
        pad = 0
    end

    if align_right then
        return string.rep(" ", pad) .. value
    end
    return value .. string.rep(" ", pad)
end

local function is_numeric_text(value)
    if value == nil then
        return false
    end
    return tonumber(tostring(value)) ~= nil
end

local function task_render_text(row)
    local raw = tostring(row and row.raw or "")
    if raw ~= "" then
        return raw
    end

    local task_text = tostring(row and row.text or "")
    if task_text == "" then
        task_text = tostring((row and row.file and row.file.title) or "")
    end

    local mark = row and row.checked and "x" or " "
    return "- [" .. mark .. "] " .. task_text
end

---Execute one parsed dataview block against note identities.
---@param block table
---@param notes table[]
---@return table result
---@return table|nil error
function M.execute_query(block, notes)
    if type(block) ~= "table" then
        return {
            result = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "block must be a table"),
        }
    end

    local query = block.query
    if type(query) ~= "table" then
        return {
            result = nil,
            error = errors.new(errors.codes.INVALID_INPUT, "block.query must be a table"),
        }
    end

    local source_notes = {}
    if type(notes) == "table" then
        for _, n in ipairs(notes) do
            if type(n) == "table" then
                local normalized = {}
                for key, value in pairs(n) do
                    normalized[key] = value
                end

                normalized.path = tostring(n.path or "")
                normalized.title = tostring(n.title or "")
                normalized.text = n.text
                normalized.raw = n.raw
                normalized.checked = n.checked
                normalized.file = type(n.file) == "table" and n.file or nil
                normalized.aliases = type(n.aliases) == "table" and n.aliases or {}
                normalized.tags = type(n.tags) == "table" and n.tags or {}

                table.insert(source_notes, normalized)
            end
        end
    end

    if query.kind == "task" then
        local rows = {}
        for _, note in ipairs(source_notes) do
            local row = note
            if type(note.file) ~= "table" then
                row = to_task_row(note)
            end
            if row_matches_from(row, query) then
                table.insert(rows, row)
            end
        end

        local where_rows, where_err = apply_where_rows(rows, query)
        if not where_rows then
            return {
                result = nil,
                error = errors.new(errors.codes.PARSE_FAILURE,
                    "WHERE error: " .. tostring(where_err or "invalid expression")),
            }
        end

        local rendered_lines = {}
        if query.group_by and query.group_alias then
            local grouped = {}
            local ordered = {}
            for _, row in ipairs(where_rows) do
                local key_value = resolve_value(row, query.group_by)
                local group_key = tostring((row.file and row.file.path) or key_value or "")
                if not grouped[group_key] then
                    grouped[group_key] = {
                        key = group_key,
                        group_key = key_value,
                        rows = {},
                    }
                    table.insert(ordered, grouped[group_key])
                end
                table.insert(grouped[group_key].rows, row)
            end

            sort_groups(ordered, query)
            for group_index, group in ipairs(ordered) do
                sort_rows(group.rows, { sort_field = nil, sort_dir = "ASC" })
                -- Add file name as header
                local display_name = tostring(group.key or "")
                -- Extract just the filename from the path if it's a path
                if display_name:find("/") then
                    display_name = display_name:match("([^/]+)$") or display_name
                end
                display_name = display_name:gsub("%.md$", "")

                -- Add spacing around the filename header for readability.
                if group_index > 1 then
                    table.insert(rendered_lines, {
                        text = "",
                        highlight = "task_text",
                    })
                end
                table.insert(rendered_lines, {
                    text = display_name,
                    highlight = "header",
                })
                table.insert(rendered_lines, {
                    text = "",
                    highlight = "task_text",
                })
                for _, row in ipairs(group.rows) do
                    table.insert(rendered_lines, {
                        text = task_render_text(row),
                        highlight = "task_text",
                    })
                end
            end
        else
            sort_rows(where_rows, query)
            for _, row in ipairs(where_rows) do
                table.insert(rendered_lines, {
                    text = task_render_text(row),
                    highlight = "task_text",
                })
            end
        end

        local rows = {}
        for _, source_row in ipairs(where_rows) do
            local out_row = {
                file = {
                    path = tostring(source_row.file and source_row.file.path or ""),
                    title = tostring(source_row.file and source_row.file.title or ""),
                },
                checked = source_row.checked == true,
                text = tostring(source_row.text or ""),
            }
            table.insert(rows, out_row)
        end

        return {
            result = {
                kind = "task",
                rows = rows,
                rendered_lines = rendered_lines,
            },
            error = nil,
        }
    end

    if query.kind == "table" then
        local filtered = {}
        for _, note in ipairs(source_notes) do
            if note_matches_from(note, query) then
                table.insert(filtered, note)
            end
        end

        local where_rows, where_err = apply_where_rows(filtered, query)
        if not where_rows then
            return {
                result = nil,
                error = errors.new(errors.codes.PARSE_FAILURE,
                    "WHERE error: " .. tostring(where_err or "invalid expression")),
            }
        end

        sort_rows(where_rows, query)

        local rows = {}
        local rendered_lines = {}
        local headers = {}
        local widths = {}
        local right_align = {}
        local function display_width(s)
            local text = tostring(s or "")
            if type(vim) == "table" and type(vim.fn) == "table" and type(vim.fn.strdisplaywidth) == "function" then
                local ok, w = pcall(vim.fn.strdisplaywidth, text)
                if ok and type(w) == "number" then
                    return w
                end
            end
            return #text
        end

        for _, projection in ipairs(query.projections or {}) do
            local label = tostring(projection.label or "")
            table.insert(headers, label)
            table.insert(widths, display_width(label))
            table.insert(right_align, true)
        end

        for _, note in ipairs(where_rows) do
            local row = {}
            for col, projection in ipairs(query.projections or {}) do
                local cell = table_cell(note, projection.expr)
                table.insert(row, cell)
                widths[col] = math.max(widths[col] or 0, display_width(cell))
                if right_align[col] and not is_numeric_text(cell) then
                    right_align[col] = false
                end
            end
            table.insert(rows, row)
        end

        if #headers > 0 then
            local formatted_header = {}
            for col, label in ipairs(headers) do
                table.insert(formatted_header, pad_cell(label, widths[col], false))
            end

            local delimiter = "  "
            local header_text = table.concat(formatted_header, delimiter)
            table.insert(rendered_lines, {
                text = header_text,
                highlight = "table_header",
            })
            table.insert(rendered_lines, {
                text = string.rep("-", display_width(header_text)),
                highlight = "table_header",
            })
        end

        for _, row in ipairs(rows) do
            local formatted = {}
            for col, cell in ipairs(row) do
                table.insert(formatted, pad_cell(cell, widths[col], right_align[col] == true))
            end
            table.insert(rendered_lines, {
                text = table.concat(formatted, "  "),
                highlight = "table_link",
            })
        end

        return {
            result = {
                kind = "table",
                rows = rows,
                rendered_lines = rendered_lines,
            },
            error = nil,
        }
    end

    return {
        result = nil,
        error = errors.new(errors.codes.PARSE_FAILURE, "unsupported query kind"),
    }
end

return M
