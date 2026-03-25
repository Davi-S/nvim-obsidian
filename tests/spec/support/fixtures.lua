local M = {}

function M.journal_title_formats()
    return {
        daily = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
        weekly = "{{iso_year}} semana {{iso_week}}",
        monthly = "{{year}} {{month_name}}",
        yearly = "{{year}}",
    }
end

function M.journal_dirs(root)
    return {
        daily = { dir_abs = root .. "/11 Diario/11.01 Diario" },
        weekly = { dir_abs = root .. "/11 Diario/11.02 Semanal" },
        monthly = { dir_abs = root .. "/11 Diario/11.03 Mensal" },
        yearly = { dir_abs = root .. "/11 Diario/11.04 Anual" },
    }
end

function M.journal_cfg(root)
    local vault_root = root or "/vault"
    return {
        journal_enabled = true,
        notes_dir_abs = vault_root .. "/10 Novas notas",
        journal = vim.tbl_deep_extend("force", {}, M.journal_dirs(vault_root), {
            title_formats = M.journal_title_formats(),
        }),
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
