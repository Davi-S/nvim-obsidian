local M = {}

local function trim(s)
    return vim.trim(s or "")
end

local function starts_with_ci(s, prefix)
    return s:sub(1, #prefix):upper() == prefix
end

function M.find_blocks(lines)
    local blocks = {}
    local i = 1

    while i <= #lines do
        local line = lines[i]
        if trim(line):lower() == "```dataview" then
            local start_line = i
            local j = i + 1
            while j <= #lines and trim(lines[j]) ~= "```" do
                j = j + 1
            end

            if j <= #lines then
                local body = {}
                for k = i + 1, j - 1 do
                    table.insert(body, lines[k])
                end

                table.insert(blocks, {
                    start_line = start_line,
                    end_line = j,
                    body_lines = body,
                })

                i = j + 1
            else
                break
            end
        else
            i = i + 1
        end
    end

    return blocks
end

local function parse_where(where_text)
    local expr = trim(where_text)
    if expr == "" then
        return nil, "invalid WHERE clause"
    end
    return expr
end

function M.parse_query(body_lines)
    local query = {
        kind = nil,
        without_id = false,
        projections = {},
        from = nil,
        from_kind = nil,
        where_expr = nil,
        group_by = nil,
        group_alias = nil,
        sort_field = nil,
        sort_dir = "ASC",
    }

    local has_where = false
    local has_group = false
    local has_sort = false
    local parsing_table_projections = false

    for _, raw in ipairs(body_lines) do
        local line = trim(raw)
        if line ~= "" then
            if not query.kind then
                if line:upper() == "TASK" then
                    query.kind = "TASK"
                elseif line:upper() == "TABLE WITHOUT ID" then
                    query.kind = "TABLE"
                    query.without_id = true
                    parsing_table_projections = true
                else
                    return nil, "only TASK or TABLE WITHOUT ID query is supported"
                end
            elseif not query.from then
                local from_path = line:match('^FROM%s+"([^"]+)"$')
                local from_tag = line:match("^FROM%s+#([^%s]+)$")

                if from_path then
                    query.from = from_path
                    query.from_kind = "path"
                    parsing_table_projections = false
                elseif from_tag then
                    query.from = from_tag
                    query.from_kind = "tag"
                    parsing_table_projections = false
                elseif query.kind == "TABLE" and parsing_table_projections then
                    local expr, label = line:match('^(.-)%s+AS%s+"([^"]+)"%s*,?$')
                    expr = trim(expr)
                    if not expr or expr == "" or not label or label == "" then
                        return nil, "invalid TABLE projection"
                    end
                    table.insert(query.projections, {
                        expr = expr,
                        label = label,
                    })
                else
                    return nil, "invalid FROM clause"
                end
            elseif starts_with_ci(line, "WHERE ") then
                if has_where then
                    return nil, "duplicate WHERE clause"
                end
                local expr, err = parse_where(line:sub(7))
                if not expr then
                    return nil, err
                end
                query.where_expr = expr
                has_where = true
            elseif starts_with_ci(line, "GROUP BY ") then
                if query.kind ~= "TASK" then
                    return nil, "GROUP BY is only supported for TASK"
                end
                if has_group then
                    return nil, "duplicate GROUP BY clause"
                end
                local field, alias = line:match("^GROUP%s+BY%s+([%w%._]+)%s+AS%s+([%w_]+)$")
                if not field or not alias then
                    return nil, "invalid GROUP BY clause"
                end
                query.group_by = field
                query.group_alias = alias
                has_group = true
            elseif starts_with_ci(line, "SORT ") then
                if has_sort then
                    return nil, "duplicate SORT clause"
                end
                local field, dir = line:match("^SORT%s+([%w%._]+)%s+(%u+)$")
                if not field then
                    return nil, "invalid SORT clause"
                end
                dir = dir:upper()
                if dir ~= "ASC" and dir ~= "DESC" then
                    return nil, "invalid SORT direction"
                end
                query.sort_field = field
                query.sort_dir = dir
                has_sort = true
            else
                return nil, "unsupported clause: " .. line
            end
        end
    end

    if not query.kind then
        return nil, "missing query declaration"
    end
    if not query.from then
        return nil, "missing FROM clause"
    end
    if query.kind == "TABLE" and #query.projections == 0 then
        return nil, "missing TABLE projections"
    end

    return query
end

return M
