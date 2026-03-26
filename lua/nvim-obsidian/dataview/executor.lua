local where_eval = require("nvim-obsidian.dataview.where_eval")

local M = {}

local function get_field(row, name, group_alias)
    if name == "file.link.date" then
        return row.file and row.file.link and row.file.link.date or nil
    end

    if group_alias then
        if name == group_alias .. ".date" then
            return row.group_key and row.group_key.date or nil
        end
    end

    return nil
end

function M.execute(query, tasks)
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
