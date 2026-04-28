local primitives = require("nvim_obsidian.core.shared.primitives")

---Domain contract: dataview query parsing and execution.
---
---This contract defines the pure API consumed by rendering use-cases for
---extracting dataview blocks and evaluating them against vault notes.
local M = {
    name = "dataview",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    models = {
        query_result = primitives.query_result,
    },
    api = {
        parse_blocks = {
            input = {
                markdown = "string",
            },
            output = {
                blocks = "table[]",
                error = "domain_error|nil",
            },
        },
        execute_query = {
            input = {
                block = "table",
                notes = "note_identity[]",
            },
            output = {
                result = primitives.query_result,
                error = "domain_error|nil",
            },
        },
    },
}

return M
