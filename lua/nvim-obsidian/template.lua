--[[
Template system for nvim-obsidian.

Provides a flexible templating engine with user-configurable placeholders.

Usage:
  -- Register placeholders during setup
  local obsidian = require("nvim-obsidian")
  obsidian.setup({ vault_root = "/path/to/vault" })
  
  obsidian.register_placeholder("title", function(ctx)
    return ctx.note.title
  end)
  
  obsidian.register_placeholder("date", function(ctx)
    return ctx.time.format_date("%Y-%m-%d")
  end)
  
  -- Render templates manually
  local template = "---\ntitle: {{title}}\ndate: {{date}}\n---\n"
  local ctx = obsidian.template.build_context({
    cfg = config,
    title = "My Note",
    note_type = "standard",
    note_abs_path = "/path/to/note.md",
    input = "My Note",
    timestamp = os.time(),
  })
  local rendered = obsidian.template.render(template, ctx)

Placeholder context object has the following structure:
  ctx.note = {
    title: string,           -- note title
    type: string,            -- note type (standard/daily/weekly/monthly/yearly)
    input: string,           -- original user input
    rel_path: string,        -- vault-relative path
    aliases: table,          -- array of aliases
    tags: table,             -- array of tags
    abs_path: string,        -- absolute file path
  }
  ctx.time = {
    timestamp: number,       -- unix timestamp
    local: table,            -- local date table {year, month, day, hour, min, sec, wday, yday}
    utc: table,              -- UTC date table
    iso: table,              -- ISO date object {year, month, day}
    format_date: function,   -- format function: format_date(fmt) -> string
  }
  ctx.config = {...}        -- read-only config object

Placeholders in templates:
  - Use {{placeholder_name}} syntax
  - Unknown placeholders are left unchanged with a warning
  - No built-in placeholders—all must be registered by user
  - Resolver functions return a string value
]]

local registry = require("nvim-obsidian.template.registry")
local engine = require("nvim-obsidian.template.engine")
local context = require("nvim-obsidian.template.context")

local M = {}

function M.register_placeholder(name, resolver)
    registry.register_placeholder(name, resolver)
end

function M.render(template_text, ctx)
    return engine.render(template_text, ctx)
end

function M.build_context(params)
    return context.build(params)
end

function M._reset_for_tests()
    registry.reset_for_tests()
    engine.reset_for_tests()
end

return M
