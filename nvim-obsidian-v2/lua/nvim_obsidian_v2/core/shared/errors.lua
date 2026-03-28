local M = {}

function M.new(code, message, meta)
    return {
        code = code,
        message = message,
        meta = meta or {},
    }
end

return M
