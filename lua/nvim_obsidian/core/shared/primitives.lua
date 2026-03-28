local M = {}

M.note_identity = {
    path = "string",
    title = "string",
    aliases = "string[]",
}

M.link_target = {
    raw = "string",
    note_ref = "string",
    anchor = "string|nil",
    block_id = "string|nil",
    display_alias = "string|nil",
}

M.query_result = {
    kind = "task|table",
    rows = "table[]",
    rendered_lines = "string[]",
}

M.domain_error = {
    code = "string",
    message = "string",
    meta = "table",
}

return M
