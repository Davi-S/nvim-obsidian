local M = {}

function M.new(code, message, meta)
    return {
        code = code,
        message = message,
        meta = meta or {},
    }
end

M.codes = {
    INVALID_INPUT = "invalid_input",
    NOT_FOUND = "not_found",
    AMBIGUOUS_TARGET = "ambiguous_target",
    PARSE_FAILURE = "parse_failure",
    RENDER_FAILURE = "render_failure",
    CONFIG_ERROR = "config_error",
    INTERNAL = "internal",
}

return M
