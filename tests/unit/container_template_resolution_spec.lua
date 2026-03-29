---@diagnostic disable: undefined-global

local container_builder = require("nvim_obsidian.app.container")

describe("container template resolution", function()
    local function make_temp_vault()
        local base = os.tmpname()
        os.remove(base)
        os.execute("mkdir -p '" .. base .. "'")
        return base
    end

    local function write_file(path, content)
        local file = io.open(path, "w")
        assert.is_not_nil(file)
        file:write(content)
        file:close()
    end

    it("resolves journal template on note creation", function()
        local vault = make_temp_vault()
        os.execute("mkdir -p '" .. vault .. "/08 Templates'")
        write_file(vault .. "/08 Templates/Nota diária.md", "# Daily {{title}}")

        local c = container_builder.build({
            vault_root = vault,
            locale = "pt-BR",
            journal = {
                daily = {
                    subdir = "11 Diário/11.01 Diário",
                    title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
                    template = "08 Templates/Nota diária",
                },
            },
        })

        local content = c.resolve_template_content({
            origin = "journal",
            kind = "daily",
            title = "2026 março 29, domingo",
        })

        assert.equals("# Daily {{title}}", content)
    end)

    it("resolves standard template by symbolic query", function()
        local vault = make_temp_vault()
        os.execute("mkdir -p '" .. vault .. "/08 Templates'")
        write_file(vault .. "/08 Templates/Nova nota.md", "# Standard {{title}}")

        local c = container_builder.build({
            vault_root = vault,
            templates = {
                standard = "08 Templates/Nova nota",
            },
        })

        local content = c.resolve_template_content({
            query = "standard",
            command = "ObsidianInsertTemplate",
        })

        assert.equals("# Standard {{title}}", content)
    end)
end)
