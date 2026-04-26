---Shared error primitives used by domains, use-cases, and adapters.
---
---The project intentionally carries small, serializable error tables instead of
---raising exceptions across boundaries. This keeps contracts explicit and allows
---adapters to map domain/use-case failures into user-facing notifications.
local M = {}

---Create a normalized domain error object.
---@param code string Stable machine-readable error code.
---@param message string Human-readable error message.
---@param meta? table Additional contextual information.
---@return table error_obj
function M.new(code, message, meta)
    return {
        code = code,
        message = message,
        meta = meta or {},
    }
end

---Canonical error code set used throughout the plugin.
---
---These values are part of the internal contract surface between layers.
---Keep them stable unless all call sites and tests are updated together.
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
