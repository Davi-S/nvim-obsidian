local path = require("nvim-obsidian.path")

local M = {}

local defaults = {
    vault_root = "",
    locale = "pt-BR",
    notes_subdir = "10 Novas notas",
    force_create_key = "<S-CR>",
    journal = {
        daily = { subdir = "11 Diário/11.01 Diário" },
        weekly = { subdir = "11 Diário/11.02 Semanal" },
        monthly = { subdir = "11 Diário/11.03 Mensal" },
        yearly = { subdir = "11 Diário/11.04 Anual" },
    },
    templates = {
        standard = "---\naliases: []\ntags: []\n---\n\n# {{title}}\n",
        daily = "---\naliases: []\ntags: [nota_diaria]\n---\n\n# {{title}}\n",
        weekly = "---\naliases: []\ntags: [nota_semanal]\n---\n\n# {{title}}\n",
        monthly = "---\naliases: []\ntags: [nota_mensal]\n---\n\n# {{title}}\n",
        yearly = "---\naliases: []\ntags: [nota_anual]\n---\n\n# {{title}}\n",
    },
    month_names = {
        [1] = "janeiro",
        [2] = "fevereiro",
        [3] = "março",
        [4] = "abril",
        [5] = "maio",
        [6] = "junho",
        [7] = "julho",
        [8] = "agosto",
        [9] = "setembro",
        [10] = "outubro",
        [11] = "novembro",
        [12] = "dezembro",
    },
    weekday_names = {
        [1] = "domingo",
        [2] = "segunda-feira",
        [3] = "terça-feira",
        [4] = "quarta-feira",
        [5] = "quinta-feira",
        [6] = "sexta-feira",
        [7] = "sábado",
    },
}

local state = {}

local function validate(cfg)
    if cfg.vault_root == "" then
        error("vault_root is required")
    end
    if not path.is_absolute(cfg.vault_root) then
        error("vault_root must be an absolute path")
    end
    if vim.fn.isdirectory(cfg.vault_root) == 0 then
        error("vault_root directory does not exist: " .. cfg.vault_root)
    end
end

function M.resolve(user)
    local cfg = vim.tbl_deep_extend("force", {}, defaults, user or {})
    cfg.vault_root = path.normalize(vim.fn.expand(cfg.vault_root))

    validate(cfg)

    cfg.notes_dir_abs = path.join(cfg.vault_root, cfg.notes_subdir)
    cfg.journal.daily.dir_abs = path.join(cfg.vault_root, cfg.journal.daily.subdir)
    cfg.journal.weekly.dir_abs = path.join(cfg.vault_root, cfg.journal.weekly.subdir)
    cfg.journal.monthly.dir_abs = path.join(cfg.vault_root, cfg.journal.monthly.subdir)
    cfg.journal.yearly.dir_abs = path.join(cfg.vault_root, cfg.journal.yearly.subdir)

    return cfg
end

function M.set(cfg)
    state.cfg = cfg
end

function M.get()
    return state.cfg
end

return M
