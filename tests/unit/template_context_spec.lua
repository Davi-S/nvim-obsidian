---@diagnostic disable: undefined-global, undefined-field

local template_context = require("nvim_obsidian.app.template_context")

describe("template_context.build", function()
    it("keeps note nil for non-note-bound render flows", function()
        local ctx = template_context.build({
            meta_origin = "insert_template_command",
            note = nil,
        })

        assert.is_nil(ctx.note)
    end)

    it("builds note when title and path are non-empty strings", function()
        local ctx = template_context.build({
            meta_origin = "omni_create",
            note = {
                kind = "note",
                title = "Alpha",
                path = "notes/Alpha.md",
            },
        })

        assert.is_table(ctx.note)
        assert.equals("Alpha", ctx.note.title)
        assert.equals("notes/Alpha.md", ctx.note.path)
        assert.is_table(ctx.note.yaml)
    end)

    it("keeps note nil when note payload is incomplete", function()
        local ctx_missing_title = template_context.build({
            meta_origin = "omni_create",
            note = {
                kind = "note",
                title = nil,
                path = "notes/Alpha.md",
            },
        })

        local ctx_missing_path = template_context.build({
            meta_origin = "omni_create",
            note = {
                kind = "note",
                title = "Alpha",
                path = "",
            },
        })

        assert.is_nil(ctx_missing_title.note)
        assert.is_nil(ctx_missing_path.note)
    end)
end)
