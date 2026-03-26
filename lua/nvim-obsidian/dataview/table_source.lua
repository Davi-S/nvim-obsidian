local path = require("nvim-obsidian.path")

local M = {}

local function parse_iso_date_parts(s)
    if type(s) ~= "string" then
        return nil
    end
    local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
        return nil
    end
    return {
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
    }
end

local function has_tag(note, tag_name)
    local wanted = vim.fn.tolower(((tag_name or ""):gsub("^#", "")))
    if wanted == "" then
        return false
    end

    for _, tag in ipairs(note.tags or {}) do
        if type(tag) == "string" then
            local normalized = vim.fn.tolower((tag:gsub("^#", "")))
            if normalized == wanted then
                return true
            end
        end
    end
    return false
end

local function build_row(note)
    local row = {
        file = {
            path = note.relpath or note.filepath,
            name = path.stem(note.filepath),
            link = path.stem(note.filepath),
        },
        frontmatter = note.frontmatter or {},
    }

    for k, v in pairs(note.frontmatter or {}) do
        row[k] = v
    end

    if row["obito"] ~= nil and row["óbito"] == nil then
        row["óbito"] = row["obito"]
    end

    local nascimento_raw = row.nascimento
    local nascimento_parts = parse_iso_date_parts(nascimento_raw)
    if nascimento_parts then
        row.nascimento = nascimento_parts
    end

    return row
end

function M.collect(vault_notes, query)
    local rows = {}

    for _, note in ipairs(vault_notes) do
        local include = false
        if query.from_kind == "tag" then
            include = has_tag(note, query.from)
        elseif query.from_kind == "path" then
            local rel = note.relpath or ""
            local prefix = query.from or ""
            if prefix ~= "" and prefix:sub(-1) ~= "/" then
                prefix = prefix .. "/"
            end
            include = (prefix == "") or vim.startswith(rel, prefix)
        end

        if include then
            table.insert(rows, build_row(note))
        end
    end

    return rows, {}
end

return M
