local M = {}

local function trim(s)
    return vim.trim(s or "")
end

local function tokenize(s)
    local tokens = {}
    local i = 1

    local function add(kind, val)
        tokens[#tokens + 1] = { kind = kind, value = val }
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
            -- Find the matching closing parenthesis
            local close_pos = s:find(")", i + 5, true)
            if not close_pos then
                return nil, "unclosed date() literal"
            end

            local date_str = trim(s:sub(i + 5, close_pos - 1))
            local dq = date_str:match('^"(.*)"$')
            if dq then
                date_str = dq
            else
                local sq = date_str:match("^'(.*)'$")
                if sq then
                    date_str = sq
                end
            end

            -- Validate date format YYYY-MM-DD
            if not date_str:match("^%d%d%d%d%-%d%d%-%d%d$") then
                return nil, "invalid date format, expected YYYY-MM-DD"
            end

            add("DATE", date_str)
            i = close_pos + 1
        else
            local word = s:sub(i):match("^([^%s%(%)!<>=]+)")
            if not word then
                return nil, "invalid token near: " .. s:sub(i, math.min(i + 10, #s))
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
                if num then
                    add("NUMBER", num)
                else
                    add("IDENT", word)
                end
            end

            i = i + #word
        end
    end

    return tokens
end

local function parse_date_to_ts(s)
    local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then
        return nil
    end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function get_field(row, ident)
    if ident == "checked" then
        return row.checked
    end

    local current = row
    for part in ident:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
    end
    return current
end

local function eval_comparison(lhs, op, rhs)
    if lhs == nil or rhs == nil then
        return false
    end
    if op == "=" then
        return lhs == rhs
    elseif op == "!=" then
        return lhs ~= rhs
    elseif op == "<" then
        return lhs < rhs
    elseif op == ">" then
        return lhs > rhs
    elseif op == "<=" then
        return lhs <= rhs
    elseif op == ">=" then
        return lhs >= rhs
    end
    return false
end

local function parser(tokens, row)
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

    local parse_expr, parse_or, parse_and, parse_not, parse_primary

    local function parse_value()
        local t = peek()
        if not t then
            return nil, "unexpected end of expression"
        end

        if t.kind == "IDENT" then
            pos = pos + 1
            return get_field(row, t.value)
        end
        if t.kind == "BOOL" then
            pos = pos + 1
            return t.value
        end
        if t.kind == "NUMBER" then
            pos = pos + 1
            return t.value
        end
        if t.kind == "DATE" then
            pos = pos + 1
            return parse_date_to_ts(t.value)
        end

        return nil, "expected value"
    end

    function parse_primary()
        if take("LPAREN") then
            local v, err = parse_expr()
            if err then
                return nil, err
            end
            if not take("RPAREN") then
                return nil, "missing closing ')'"
            end
            return v
        end

        local save_pos = pos
        local lhs, lhs_err = parse_value()
        if lhs_err then
            return nil, lhs_err
        end

        local op = take("OP")
        if op then
            local rhs, rhs_err = parse_value()
            if rhs_err then
                return nil, rhs_err
            end
            return eval_comparison(lhs, op.value, rhs)
        end

        pos = save_pos
        local lone, lone_err = parse_value()
        if lone_err then
            return nil, lone_err
        end
        if type(lone) == "boolean" then
            return lone
        end
        return lone ~= nil
    end

    function parse_not()
        if take("NOT") then
            local v, err = parse_not()
            if err then
                return nil, err
            end
            return not v
        end
        return parse_primary()
    end

    function parse_and()
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
        return lhs
    end

    function parse_or()
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
        return lhs
    end

    function parse_expr()
        return parse_or()
    end

    local result, err = parse_expr()
    if err then
        return nil, err
    end

    if pos <= #tokens then
        return nil, "unexpected token at end"
    end

    return not not result
end

function M.match(where_expr, row)
    if not where_expr or vim.trim(where_expr) == "" then
        return true
    end

    local tokens, token_err = tokenize(where_expr)
    if not tokens then
        return nil, token_err
    end

    return parser(tokens, row)
end

return M
