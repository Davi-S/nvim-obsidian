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
        from = nil,
        where_expr = nil,
        group_by = nil,
        group_alias = nil,
        sort_field = nil,
        sort_dir = "ASC",
    }

    local has_where = false
    local has_group = false
    local has_sort = false

    for _, raw in ipairs(body_lines) do
        local line = trim(raw)
        if line ~= "" then
            if not query.kind then
                if line:upper() ~= "TASK" then
                    return nil, "only TASK query is supported"
                end
                query.kind = "TASK"
            elseif not query.from then
                local from_path = line:match('^FROM%s+"([^"]+)"$')
                if not from_path then
                    return nil, "invalid FROM clause"
                end
                query.from = from_path
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

    if query.kind ~= "TASK" then
        return nil, "missing TASK declaration"
    end
    if not query.from then
        return nil, "missing FROM clause"
    end

    return query
end

return M
