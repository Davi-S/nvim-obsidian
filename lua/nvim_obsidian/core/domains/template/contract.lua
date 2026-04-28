---Domain contract: placeholder registry and template rendering.
---
---Used by note creation and explicit template insertion workflows.
local M = {
    name = "template",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    api = {
        register_placeholders = {
            input = {
                registry = "table<string, function>",
            },
            output = {
                ok = "boolean",
                error = "domain_error|nil",
            },
        },
        render = {
            input = {
                content = "string",
                context = "table",
            },
            output = {
                rendered = "string",
                unresolved = "string[]",
            },
        },
    },
}

return M
