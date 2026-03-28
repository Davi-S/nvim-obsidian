local errors = require("nvim_obsidian.core.shared.errors")

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
        where_title_eq = nil,
        sort_field = nil,
        sort_dir = "ASC",
    }

    local i = 1
    local first = lines[i]
    if first == "TASK" then
        query.kind = "task"
        i = i + 1
    elseif first == "TABLE WITHOUT ID" then
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
        local where_title_eq = line:match('^WHERE%s+title%s*=%s*"([^"]+)"$')
        if where_title_eq then
            query.where_title_eq = where_title_eq
            i = i + 1
        else
            local field, dir = line:match("^SORT%s+([%w_%.]+)%s+(ASC|DESC)$")
            if field then
                query.sort_field = field
                query.sort_dir = dir
                i = i + 1
            else
                return nil, errors.new(errors.codes.PARSE_FAILURE, "unsupported clause: " .. line)
            end
        end
    end

    return query, nil
end

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
        local path = tostring(note.path or "")
        local prefix = tostring(query.from_value or "")
        if prefix ~= "" and prefix:sub(-1) ~= "/" then
            prefix = prefix .. "/"
        end
        return prefix == "" or path:sub(1, #prefix) == prefix
    end

    if query.from_kind == "tag" then
        return note_has_tag(note, query.from_value)
    end

    return false
end

local function apply_where(notes, query)
    if query.where_title_eq == nil then
        return notes
    end

    local out = {}
    for _, note in ipairs(notes) do
        if tostring(note.title or "") == query.where_title_eq then
            table.insert(out, note)
        end
    end
    return out
end

local function sort_notes(notes, query)
    if not query.sort_field then
        table.sort(notes, function(a, b)
            return tostring(a.path or "") < tostring(b.path or "")
        end)
        return
    end

    table.sort(notes, function(a, b)
        local av
        local bv
        if query.sort_field == "title" then
            av = tostring(a.title or "")
            bv = tostring(b.title or "")
        else
            av = tostring(a.path or "")
            bv = tostring(b.path or "")
        end

        if av == bv then
            return tostring(a.path or "") < tostring(b.path or "")
        end

        if query.sort_dir == "DESC" then
            return av > bv
        end
        return av < bv
    end)
end

local function table_cell(note, expr)
    if expr == "file.link" then
        return tostring(note.title or "")
    end
    if expr == "title" then
        return tostring(note.title or "")
    end
    if expr == "file.path" then
        return tostring(note.path or "")
    end
    if expr == "aliases.count" then
        return tostring(type(note.aliases) == "table" and #note.aliases or 0)
    end
    return ""
end

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
                table.insert(source_notes, {
                    path = tostring(n.path or ""),
                    title = tostring(n.title or ""),
                    aliases = type(n.aliases) == "table" and n.aliases or {},
                    tags = type(n.tags) == "table" and n.tags or {},
                })
            end
        end
    end

    local filtered = {}
    for _, note in ipairs(source_notes) do
        if note_matches_from(note, query) then
            table.insert(filtered, note)
        end
    end

    filtered = apply_where(filtered, query)
    sort_notes(filtered, query)

    if query.kind == "task" then
        local rows = {}
        local rendered_lines = {}
        for _, note in ipairs(filtered) do
            local row = {
                file = {
                    path = note.path,
                    title = note.title,
                },
            }
            table.insert(rows, row)
            table.insert(rendered_lines, "- [ ] [[" .. note.title .. "]]")
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
        local rows = {}
        local rendered_lines = {}
        local headers = {}

        for _, projection in ipairs(query.projections or {}) do
            table.insert(headers, projection.label)
        end

        if #headers > 0 then
            table.insert(rendered_lines, table.concat(headers, " | "))
            table.insert(rendered_lines, string.rep("-", #rendered_lines[1]))
        end

        for _, note in ipairs(filtered) do
            local row = {}
            for _, projection in ipairs(query.projections or {}) do
                table.insert(row, table_cell(note, projection.expr))
            end
            table.insert(rows, row)
            table.insert(rendered_lines, table.concat(row, " | "))
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
