# nvim-obsidian V2 User Guide

**Version:** 1.0  
**Date:** March 28, 2026  
**Audience:** End users installing and configuring nvim-obsidian V2

---

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Configuration Guide](#configuration-guide)
4. [Workflow Examples](#workflow-examples)
5. [Troubleshooting](#troubleshooting)

---

## Installation

### Prerequisites

Before installing nvim-obsidian V2, ensure you have:

1. **Neovim >= 0.9.0**
   ```bash
   nvim --version  # Check your version
   ```

2. **Required Plugins**
   - `nvim-telescope/telescope.nvim` - Note picker and search
   - `hrsh7th/nvim-cmp` - Completion menu
   - `nvim-treesitter/nvim-treesitter` - Markdown parsing
   - `nvim-lua/plenary.nvim` - Async jobs and utilities

### Install with packer.nvim

```lua
-- In your plugins specification
use "Davi-S/nvim-obsidian"  -- Main plugin
use "nvim-telescope/telescope.nvim"  -- For pickers
use "hrsh7th/nvim-cmp"  -- For completions
use "nvim-treesitter/nvim-treesitter"  -- For parsing
use "nvim-lua/plenary.nvim"  -- For utilities
```

Then run `:PackerSync` in Neovim.

### Install with lazy.nvim

```lua
-- In your lazy spec
{
  "Davi-S/nvim-obsidian",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "nvim-treesitter/nvim-treesitter",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("nvim_obsidian").setup({
      vault_root = "/path/to/your/vault",
    })
  end,
}
```

---

## Quick Start

### 1. Basic Setup (5 minutes)

Create a minimal configuration in your Neovim init file:

```lua
-- ~/.config/nvim/init.lua (or add to your existing setup)

require("nvim_obsidian").setup({
  vault_root = "/path/to/your/ObsidianVault",
})
```

### 2. Verify Installation

Run the health check command:

```vim
:ObsidianHealth
```

Expected output:
```
nvim-obsidian health: ok
```

If it fails, check:
1. Is the vault path correct and accessible?
2. Are all required plugins installed? (`packer` or `lazy`)
3. Is Neovim >= 0.9.0?

### 3. First Commands

Try these commands in a Markdown file within your vault:

```vim
:ObsidianOmni          " Search/create notes
:ObsidianSearch        " Full-text search vault
:ObsidianFollow        " Follow link under cursor
:ObsidianReindex       " Refresh vault cache
```

---

## Configuration Guide

### Minimal Configuration (Production Ready)

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),  -- Expand ~ to home
})
```

**Why this works:**
- Uses sensible defaults for all optional fields
- Supports all core features (search, notes, templates, completion)
- No configuration required unless you want to customize

### Standard Configuration (With Journal)

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  
  -- Daily journaling
  journal = {
    daily = {
      subdir = "01 Daily",
      title_format = "%Y-%m-%d",  -- 2026-03-28
    },
    weekly = {
      subdir = "02 Weekly",
      title_format = "%G-W%V",    -- 2026-W13
    },
  },
  
  -- Localization for journal titles
  locale = "en-US",  -- or "pt-BR", "es-ES", etc.
  
  -- Where new notes go by default
  new_notes_subdir = "03 Inbox",
})
```

### Advanced Configuration (All Features)

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  
  -- Logging
  log_level = "warn",  -- "error" | "warn" | "info"
  
  -- Locale for month/weekday names in templates
  locale = "pt-BR",
  
  -- Key for creating new note in Telescope picker
  force_create_key = "<C-n>",
  
  -- Directory for new standard notes
  new_notes_subdir = "10 Novas notas",
  
  -- Complete journal setup
  journal = {
    daily = {
      subdir = "11 Diário/11.01 Diário",
      title_format = "{{year}}-{{month}}-{{day}}",
    },
    weekly = {
      subdir = "11 Diário/11.02 Semanal",
      title_format = "{{iso_year}}-W{{iso_week}}",
    },
    monthly = {
      subdir = "11 Diário/11.03 Mensal",
      title_format = "{{month_name}} {{year}}",
    },
    yearly = {
      subdir = "11 Diário/11.04 Anual",
      title_format = "{{year}}",
    },
  },
  
  -- Dataview (inline query blocks) configuration
  dataview = {
    enabled = true,
    render = {
      when = { "on_open", "on_save" },  -- Auto-render on these events
      scope = "event",  -- event | current | visible | loaded
      patterns = { "*.md" },  -- Files to scan
    },
    placement = "below_block",  -- below_block | above_block
    messages = {
      task_no_results = {
        enabled = true,
        text = "Dataview: No results to show for task query.",
      }
    }
  }
})

-- Register custom template placeholders
require("nvim_obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

require("nvim_obsidian").template_register_placeholder("date", function(ctx)
  return ctx.time.format_local("%Y-%m-%d")
end)

require("nvim_obsidian").template_register_placeholder("author", function(ctx)
  return "John Doe"
end)

require("nvim_obsidian").template_register_placeholder("vault_name", function(ctx)
  return vim.fn.fnamemodify(ctx.config.vault_root, ":t")
end)

-- Reuse plugin wikilink detection in your own mappings/config helpers
-- No args: reads current line and cursor position from Neovim
local parsed = require("nvim_obsidian").wiki_link_under_cursor()
if parsed and parsed.target then
  print("Link target: " .. tostring(parsed.target.note_ref))
end

-- Optional explicit line/column (1-based column)
local parsed_explicit = require("nvim_obsidian").wiki_link_under_cursor("See [[Project Plan|Plan]]", 8)
if parsed_explicit and parsed_explicit.target then
  print("Explicit target: " .. tostring(parsed_explicit.target.note_ref))
end
```

`wiki_link_under_cursor` returns the same parser shape used by `:ObsidianFollow`:
- `target`: parsed wikilink object when cursor is inside `[[...]]`, otherwise `nil`.
- `error`: parser validation error for invalid inputs, otherwise `nil`.

You can also reuse vault boundary checks from the plugin API:

```lua
local obsidian = require("nvim_obsidian")

-- Explicit path check
if obsidian.is_inside_vault("/home/user/MyVault/notes/today.md") then
  print("Inside vault")
end

-- No args: uses current buffer path, then cwd fallback
if obsidian.is_inside_vault() then
  print("Current context is inside vault")
end
```

### Configuration Fields Explained

#### vault_root (REQUIRED)

```lua
vault_root = vim.fn.expand("~/ObsidianVault")
```

- **Type:** string (absolute path)
- **Must be:** Full path to root directory of Obsidian vault
- **Error if:** Relative path, doesn't exist, or not a directory

#### locale

```lua
locale = "en-US"  -- Default
-- Other common values:
locale = "pt-BR"  -- Portuguese (Brazil)
locale = "es-ES"  -- Spanish
locale = "fr-FR"  -- French
locale = "de-DE"  -- German
```

- **Type:** string
- **Used for:** Month names and weekday names in templates
- **Example output with `{{month_name}}`:**
  - en-US: "March"
  - pt-BR: "Março"
  - es-ES: "Marzo"

#### log_level

```lua
log_level = "warn"  -- Default
-- Or:
log_level = "error"  -- Quiet
log_level = "info"   -- Verbose
```

- **Type:** enum string
- **Used for:** Plugin debug logging
- **Recommendation:** Leave as "warn" unless debugging

#### new_notes_subdir

```lua
new_notes_subdir = "/path/to/your/ObsidianVault"  -- Default (vault_root)
```

- **Type:** string
- **Used for:** Where `:ObsidianOmni` creates new notes
- **When auto-detected:** If you create a note with `force_create_key` in Telescope
- **Example:** Create note "Project Alpha" → creates in `<vault_root>/Project Alpha.md` (unless overridden)

#### force_create_key

```lua
force_create_key = "<S-CR>"  -- Default (Shift+Enter)
```

- **Type:** string (Neovim key notation)
- **Used for:** In Telescope picker, key to create new note instead of search
- **Common alternatives:**
  - `"<C-n>"` - Ctrl+N
  - `"<C-d>"` - Ctrl+D (mnemonic: "define"/"create")
  - `"<Esc>"` - Just Escape (careful: conflicts with normal picker escape)

#### journal Configuration

```lua
journal = {
  daily = {
    subdir = "11 Diário/11.01 Diário",
    title_format = "{{year}}-{{month}}-{{day}}"
  },
  weekly = {
    subdir = "11 Diário/11.02 Semanal",
    title_format = "{{iso_year}}-W{{iso_week}}"
  },
  monthly = {
    subdir = "11 Diário/11.03 Mensal",
    title_format = "{{month_name}} {{year}}"
  },
  yearly = {
    subdir = "11 Diário/11.04 Anual",
    title_format = "{{year}}"
  }
}
```

- **Type:** table (optional)
- **When required:** Only if you use `:ObsidianToday`, `:ObsidianNext`, `:ObsidianPrev`
- **Format:** Each section (daily/weekly/monthly/yearly) needs:
  - `subdir` - Relative path within vault
  - `title_format` - Template with placeholders

**Available journal placeholders:**

| Placeholder        | Type                | Example             | Locale-Aware |
| ------------------ | ------------------- | ------------------- | ------------ |
| `{{year}}`         | 4-digit year        | "2026"              | No           |
| `{{month}}`        | 2-digit month       | "03"                | No           |
| `{{day}}`          | 2-digit day         | "28"                | No           |
| `{{month_name}}`   | Full month name     | "March" or "Março"  | Yes          |
| `{{weekday_name}}` | Full weekday        | "Friday" or "Sexta" | Yes          |
| `{{iso_year}}`     | ISO week year       | "2026"              | No           |
| `{{iso_week}}`     | ISO week number     | "13"                | No           |
| `{{iso_weekday}}`  | ISO weekday (1=Mon) | "5"                 | No           |

#### dataview Configuration

Only configure if you use inline query blocks (`\`\`\`dataview ... \`\`\``):

```lua
dataview = {
  enabled = true,  -- Set to false to disable
  render = {
    when = { "on_open", "on_save" },  -- When to auto-render
    scope = "event",  -- Which buffers: event|current|visible|loaded
    patterns = { "*.md" },  -- Which files to scan
  },
  placement = "below_block",  -- Position: below_block|above_block
  messages = {
    task_no_results = {
      enabled = true,
      text = "Dataview: No results..."
    }
  }
}
```

---

## Workflow Examples

### Example 1: Daily Journal Workflow

Setup for journaling:

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  locale = "en-US",
  journal = {
    daily = {
      subdir = "Journal/Daily",
      title_format = "%Y-%m-%d",
    }
  }
})
```

Your daily routine:

```vim
" Start day - open today's note
:ObsidianToday

" Review yesterday's note
:ObsidianPrev

" Plan next day
:ObsidianNext

" Search for related notes
:ObsidianBacklinks
```

### Example 2: Project Research Workflow

Setup for projects:

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  new_notes_subdir = "Projects/Ideas",
})
```

Your workflow:

```vim
" Search projects
:ObsidianOmni
" → Type: "Project Alpha"
" → Press: <S-CR> to create
" → Creates: "Projects/Ideas/Project Alpha.md"

" Add a link from another note
" Type in any note: [[Project Alpha]]
" Position cursor and:
:ObsidianFollow
" → Opens "Project Alpha.md"

" See all notes linking to this project
:ObsidianBacklinks
```

### Example 3: Writing with Templates

Setup with templates:

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
})

require("nvim_obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

require("nvim_obsidian").template_register_placeholder("date", function(ctx)
  return ctx.time.format_local("%Y-%m-%d")
end)
```

Create template file: `~/ObsidianVault/Templates/article.md`

```markdown
# {{title}}

**Date:** {{date}}

## Summary

[Description of article]

## Key Points

- Point 1
- Point 2

## Related Notes

<!-- Backlinks will appear here -->

```

Use template:

```vim
" Create new article
:ObsidianOmni
" → Type: "My Article"
" → Press: <S-CR>

" Insert template
:ObsidianInsertTemplate ~/Templates/article.md
" Or:
:ObsidianInsertTemplate
" (auto-detects file type)

" Notice {{title}} and {{date}} are resolved
```

---

## Troubleshooting

### Problem: "Health check failed: Missing dependency"

**Error:** `nvim-obsidian requires dependency: nvim-telescope/telescope.nvim`

**Solution:** Install the missing plugin using your package manager:

**Packer.nvim:**
```lua
use "nvim-telescope/telescope.nvim"
```

**Lazy.nvim:**
```lua
{
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = { "nvim-lua/plenary.nvim" }
}
```

Then sync: `:PackerSync` or restart Neovim.

---

### Problem: "ObsidianOmni command not found"

**Cause:** Either setup wasn't called, or setup failed with an error.

**Solution:**

1. Check your config has `require("nvim_obsidian").setup(...)` being called
2. Verify vault_root exists and is readable:
   ```bash
   ls -la /path/to/vault
   ```
3. Look for error messages in Neovim startup
4. Try `:ObsidianHealth` to see what's broken

---

### Problem: "Cannot find vault: permission denied"

**Cause:** Vault path doesn't exist or Neovim lacks read permission.

**Solution:**

```bash
# Check vault exists
ls -ld ~/ObsidianVault

# Fix permissions (if needed)
chmod u+rx ~/ObsidianVault

# Try absolute path in config
vault_root = "/home/username/ObsidianVault"  # Not ~/
```

---

### Problem: Journal commands fail ("ObsidianToday: not configured")

**Cause:** Journal section not configured in setup.

**Solution:** Add journal config:

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  journal = {
    daily = {
      subdir = "Journal/Daily",
      title_format = "%Y-%m-%d",
    }
  }
})
```

---

### Problem: Dataview blocks not rendering

**Cause:** Dataview disabled or patterns don't match.

**Solution:**

```lua
require("nvim_obsidian").setup({
  vault_root = vim.fn.expand("~/ObsidianVault"),
  dataview = {
    enabled = true,
    placement = "below_block", -- or "above_block"
    render = {
      when = { "on_open", "on_save" },
      scope = "event",
      patterns = { "*.md" },  -- Ensure matches your files
    }
  }
})
```

Also try manual render:
```vim
:ObsidianRenderDataview
```

---

### Problem: Template placeholders showing as {{title}} not resolved

**Cause:** Placeholders not registered or template file syntax is wrong.

**Solution:**

1. Verify placeholders are registered:
```lua
require("nvim_obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)
```

2. Verify template file uses correct syntax: `{{placeholder_name}}`

3. Verify template file is in vault or use absolute path:
```vim
:ObsidianInsertTemplate /home/user/Templates/article.md
```

---

### Problem: "Vault cache not ready" or slow initial load

**Cause:** Large vault (>1000 notes) takes time to scan.

**Solution:** This is normal behavior:
1. Initial scan happens asynchronously
2. You can use commands while scan completes
3. Notification confirms when ready: `nvim-obsidian: vault cache ready`
4. To force re-scan: `:ObsidianReindex`

Expected times:
- Small vault (<500 notes): <500ms
- Medium vault (500-1000 notes): <1s
- Large vault (1000-5000 notes): <5s

---

## Next Steps

1. **Read:** [API Reference](PHASE_8_API_REFERENCE.md) for detailed command documentation
2. **Configure:** Set up journal, dataview, and custom templates for your workflow
3. **Keybind:** Map commands to your preferred key combinations
4. **Explore:** Run `:help nvim-obsidian` for built-in documentation

---

**Last Updated:** March 28, 2026  
**For Issues:** Report bugs on [GitHub Issues](https://github.com/Davi-S/nvim-obsidian/issues)
