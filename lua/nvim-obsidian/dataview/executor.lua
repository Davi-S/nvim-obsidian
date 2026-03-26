local where_eval = require("nvim-obsidian.dataview.where_eval")

local M = {}

local function trim(s)
    return vim.trim(s or "")
end

local function resolve_path(row, ident)
    local current = row
    for part in ident:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
    end
    return current
end

local function get_field(row, name, group_alias)
    if name == "file.link.date" then
        return row.file and row.file.link and row.file.link.date or nil
    end

    if group_alias then
        if name == group_alias .. ".date" then
            return row.group_key and row.group_key.date or nil
        end
    end

    return resolve_path(row, name)
end

local function evaluate_projection_expr(row, expr)
    local lhs_num, rhs_ident = trim(expr):match("^(%-?%d+)%s*%-%s*([^%s]+)$")
    if lhs_num and rhs_ident then
        local rhs = get_field(row, rhs_ident, nil)
        if type(rhs) ~= "number" then
            return nil
        end
        return tonumber(lhs_num) - rhs
    end

    local num = tonumber(trim(expr))
    if num ~= nil then
        return num
    end

    return get_field(row, trim(expr), nil)
end

function M.execute(query, tasks)
    if query.kind == "TABLE" then
        local filtered = {}
        local errors = {}

        for _, row in ipairs(tasks) do
            local ok, err = where_eval.match(query.where_expr, row)
            if ok == nil then
                table.insert(errors, "dataview: WHERE error: " .. err)
                break
            end
            if ok then
                table.insert(filtered, row)
            end
        end

        if #errors > 0 then
            return nil, errors
        end

        if query.sort_field then
            table.sort(filtered, function(a, b)
                local av = get_field(a, query.sort_field, nil)
                local bv = get_field(b, query.sort_field, nil)
                if av == bv then
                    local an = (a.file and a.file.name) or ""
                    local bn = (b.file and b.file.name) or ""
                    return an < bn
                end
                if query.sort_dir == "DESC" then
                    return (av or 0) > (bv or 0)
                end
                return (av or 0) < (bv or 0)
            end)
        end

        local table_rows = {}
        for _, row in ipairs(filtered) do
            local out = {}
            for _, proj in ipairs(query.projections) do
                local v = evaluate_projection_expr(row, proj.expr)
                if v == nil then
                    out[#out + 1] = ""
                else
                    out[#out + 1] = tostring(v)
                end
            end
            table.insert(table_rows, out)
        end

        local columns = {}
        for _, proj in ipairs(query.projections) do
            table.insert(columns, proj.label)
        end

        return {
            kind = "TABLE",
            table = {
                columns = columns,
                rows = table_rows,
            },
        }, {}
    end

    local filtered = {}
    local errors = {}

    for _, row in ipairs(tasks) do
        local ok, err = where_eval.match(query.where_expr, row)
        if ok == nil then
            table.insert(errors, "dataview: WHERE error: " .. err)
            break
        end
        if ok then
            table.insert(filtered, row)
        end
    end

    if #errors > 0 then
        return nil, errors
    end

    local groups = {}
    local ordered = {}

    for _, row in ipairs(filtered) do
        local key = row.file and row.file.path or "unknown"
        if query.group_by == "file.link" then
            key = row.file and row.file.path or "unknown"
        end

        if not groups[key] then
            groups[key] = {
                key = key,
                group_key = {
                    path = row.file and row.file.path or "",
                    date = row.file and row.file.link and row.file.link.date or nil,
                },
                rows = {},
            }
            table.insert(ordered, groups[key])
        end

        table.insert(groups[key].rows, row)
    end

    if query.sort_field then
        local alias = query.group_alias
        table.sort(ordered, function(a, b)
            local av = get_field({ group_key = a.group_key }, query.sort_field, alias)
            local bv = get_field({ group_key = b.group_key }, query.sort_field, alias)
            if av == bv then
                return a.key < b.key
            end
            if query.sort_dir == "DESC" then
                return (av or 0) > (bv or 0)
            end
            return (av or 0) < (bv or 0)
        end)
    end

    return {
        groups = ordered,
        total_rows = #filtered,
    }, {}
end

return M
