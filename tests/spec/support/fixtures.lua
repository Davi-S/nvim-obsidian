local M = {}

function M.register_default_journal_placeholders()
    local registry = require("nvim-obsidian.journal.placeholder_registry")

    registry.register_placeholder("year", function(ctx)
        return tostring(ctx.date.year)
    end, "(%d%d%d%d)")

    registry.register_placeholder("iso_year", function(ctx)
        return tostring(ctx.date.iso_year)
    end, "(%d%d%d%d)")

    registry.register_placeholder("month_name", function(ctx)
        return ctx.locale.month_name or ""
    end, "(.+)")

    registry.register_placeholder("day2", function(ctx)
        return string.format("%02d", ctx.date.day or 0)
    end, "(%d%d?)")

    registry.register_placeholder("weekday_name", function(ctx)
        return ctx.locale.weekday_name or ""
    end, "(.+)")

    registry.register_placeholder("iso_week", function(ctx)
        return tostring(ctx.date.iso_week)
    end, "(%d%d?)")
end

function M.journal_dirs_new(root)
    -- New nested structure with title_format in each type
    return {
        daily = {
            subdir = "11 Diario/11.01 Diario",
            title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
            dir_abs = root .. "/11 Diario/11.01 Diario",
        },
        weekly = {
            subdir = "11 Diario/11.02 Semanal",
            title_format = "{{iso_year}} semana {{iso_week}}",
            dir_abs = root .. "/11 Diario/11.02 Semanal",
        },
        monthly = {
            subdir = "11 Diario/11.03 Mensal",
            title_format = "{{year}} {{month_name}}",
            dir_abs = root .. "/11 Diario/11.03 Mensal",
        },
        yearly = {
            subdir = "11 Diario/11.04 Anual",
            title_format = "{{year}}",
            dir_abs = root .. "/11 Diario/11.04 Anual",
        },
    }
end

function M.journal_title_formats()
    -- Flat title formats (computed by config, but kept for test reference)
    return {
        daily = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
        weekly = "{{iso_year}} semana {{iso_week}}",
        monthly = "{{year}} {{month_name}}",
        yearly = "{{year}}",
    }
end

function M.journal_cfg(root)
    local vault_root = root or "/vault"
    M.register_default_journal_placeholders()
    local journal = M.journal_dirs_new(vault_root)
    -- Config.lua builds title_formats table from nested structure
    journal.title_formats = M.journal_title_formats()
    return {
        journal_enabled = true,
        notes_dir_abs = vault_root .. "/10 Novas notas",
        journal = journal,
    }
end

function M.standard_cfg(root)
    local vault_root = root or "/vault"
    return {
        journal_enabled = false,
        vault_root = vault_root,
        notes_dir_abs = vault_root .. "/10 Novas notas",
    }
end

function M.note(overrides)
    return vim.tbl_deep_extend("force", {
        title = "Default Note",
        aliases = {},
        relpath = "10 Novas notas/Default Note.md",
        filepath = "/vault/10 Novas notas/Default Note.md",
    }, overrides or {})
end

return M
