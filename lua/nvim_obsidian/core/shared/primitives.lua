---Shared structural contracts used across the domain and use-case layers.
---
---These tables are descriptive type maps (not runtime validators). They provide
---a centralized vocabulary for core entities to keep contract naming coherent.
local M = {}

---Represents identity fields for a note entity in the vault catalog.
M.note_identity = {
    path = "string",
    title = "string",
    aliases = "string[]",
}

---Represents a parsed wiki-link target.
M.link_target = {
    raw = "string",
    note_ref = "string",
    anchor = "string|nil",
    block_id = "string|nil",
    display_alias = "string|nil",
}

---Represents normalized dataview execution output.
M.query_result = {
    kind = "task|table",
    rows = "table[]",
    rendered_lines = "string[]",
}

---Represents the shared domain error payload shape.
M.domain_error = {
    code = "string",
    message = "string",
    meta = "table",
}

return M
