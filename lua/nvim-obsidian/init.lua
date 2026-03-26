--[[
Main plugin module for nvim-obsidian.

Provides setup() for initialization and template_register_placeholder() for extending the template system.

Example setup:
  require("nvim-obsidian").setup({
    vault_root = "/home/user/Obsidian Vault",
      new_notes_subdir = "10 Notas",
  require("nvim-obsidian").template_register_placeholder("title", function(ctx)
    return ctx.note.title
  end)

  require("nvim-obsidian").template_register_placeholder("date", function(ctx)
    return ctx.time.format_local("%Y-%m-%d")
  end)

  require("nvim-obsidian").template_register_placeholder("author", function(ctx)
    return "John Doe"
  end)
]]

local config_mod = require("nvim-obsidian.config")
local scanner = require("nvim-obsidian.cache.scanner")
local commands = require("nvim-obsidian.commands")
local template = require("nvim-obsidian.template")
local journal_placeholder_registry = require("nvim-obsidian.journal.placeholder_registry")
local dataview_engine = require("nvim-obsidian.dataview.engine")

local M = {
  _did_setup = false,
  journal = {},
}

local function ensure_hard_dependencies()
  local deps = {
    { module = "telescope",               label = "nvim-telescope/telescope.nvim" },
    { module = "cmp",                     label = "hrsh7th/nvim-cmp" },
    { module = "nvim-treesitter.parsers", label = "nvim-treesitter/nvim-treesitter" },
    { module = "plenary.job",             label = "nvim-lua/plenary.nvim" },
  }

  for _, dep in ipairs(deps) do
    local ok = pcall(require, dep.module)
    if not ok then
      error("nvim-obsidian requires dependency: " .. dep.label)
    end
  end
end

local function setup_cmp_source()
  local cmp = require("cmp")
  cmp.register_source("nvim_obsidian", require("nvim-obsidian.cmp.source").new())
end

function M.setup(opts)
  --[[
    Initialize the nvim-obsidian plugin with configuration.

    Arguments:
      opts: table - configuration options (see lua/nvim-obsidian/config.lua for full reference)
        Required:
          vault_root: string - absolute path to the Obsidian vault
        Common options:
          new_notes_subdir: string - subdirectory where new standard notes are created (default: "10 Novas notas")
          locale: string - locale for month/weekday names (default: "pt-BR")
          force_create_key: string - telescope key for forced creation (default: "<S-CR>")
          journal: table - journal configuration (daily.subdir, weekly.subdir, etc.)
          templates: table - template strings for each note type

    After calling setup(), register custom placeholders via template_register_placeholder():

      require("nvim-obsidian").setup({
        vault_root = "/path/to/vault",
      })

      require("nvim-obsidian").template_register_placeholder("title", function(ctx)
        return ctx.note.title
      end)

    Behavior:
      - Validates hard dependencies (telescope, cmp, treesitter, plenary)
      - Resolves and stores configuration
      - Registers all Obsidian* commands
      - Registers nvim-cmp completion source
      - Asynchronously scans vault and populates cache
      - Sets up filesystem watchers and autocmds when cache is ready
    ]]
  if M._did_setup then
    return
  end

  ensure_hard_dependencies()
  local cfg = config_mod.resolve(opts or {})
  config_mod.set(cfg)

  commands.register()
  setup_cmp_source()

  scanner.refresh_all_async(function()
    scanner.setup_autocmds()
    dataview_engine.setup_autocmds()
    dataview_engine.refresh_open_markdown_buffers()
    vim.notify("nvim-obsidian: vault cache ready", vim.log.levels.INFO)
  end)

  M._did_setup = true
end

function M.template_register_placeholder(name, resolver)
  --[[
    Register a custom placeholder for use in templates.

    Arguments:
      name: string - placeholder name (alphanumeric + underscore, e.g., "title", "my_var")
      resolver: function(ctx) -> string - function that receives context and returns replacement text

    The resolver function receives a context object with:
      ctx.note - note metadata (title, type, input, rel_path, aliases, tags, abs_path)
      ctx.time - timestamp and date info (timestamp, local, utc, iso tables, format_local/format_utc functions)
      ctx.config - read-only configuration object

    Examples:
      template_register_placeholder("title", function(ctx)
        return ctx.note.title
      end)

      template_register_placeholder("date", function(ctx)
        return ctx.time.format_local("%Y-%m-%d")
      end)

      template_register_placeholder("year", function(ctx)
        return tostring(ctx.time.iso.year)
      end)

      template_register_placeholder("vault", function(ctx)
        return ctx.config.vault_root
      end)

    Usage in templates:
      # {{title}}
      Created: {{date}}
      Vault: {{vault}}

      Unknown placeholders will be kept as-is: {{unknown}} remains {{unknown}}
    ]]
  template.register_placeholder(name, resolver)
end

function M.journal.register_placeholder(name, resolver, regex_fragment)
  journal_placeholder_registry.register_placeholder(name, resolver, regex_fragment)
end

return M
