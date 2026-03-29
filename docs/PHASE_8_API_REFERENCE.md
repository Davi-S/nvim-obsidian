# Phase 8 Part 3: Public API & Command Reference

Version: 1.0
Date: March 28, 2026
Status: Complete

Document role: Complete API reference for nvim-obsidian V2 users.
Related documents:
- docs/PHASE_8_CONFIG_SCHEMA.md (configuration validation contract)
- README.md (quick-start guide)

---

## Setup Function

### Signature

```lua
require("nvim_obsidian").setup(opts) -> container
```

### Arguments

| Parameter | Type  | Required | Description                                       |
| --------- | ----- | -------- | ------------------------------------------------- |
| opts      | table | Yes      | Configuration table with required/optional fields |

### Required Fields in opts

| Field      | Type   | Description                               |
| ---------- | ------ | ----------------------------------------- |
| vault_root | string | Absolute path to Obsidian vault directory |

### Optional Fields in opts

| Field            | Type   | Default    | Description                                 |
| ---------------- | ------ | ---------- | ------------------------------------------- |
| locale           | string | "en-US"    | Locale for month/weekday names              |
| log_level        | enum   | "warn"     | "error" \| "warn" \| "info"                 |
| force_create_key | string | "<S-CR>"   | Telescope key for forced note creation      |
| new_notes_subdir | string | vault_root | Subdirectory for new standard notes         |
| journal          | table  | nil        | Journal configuration (optional)            |
| dataview         | table  | (defaults) | Dataview rendering configuration (optional) |

### Return Value

Returns a **container object** with the following structure:

```lua
{
  -- Configuration (read-only)
  config = {
    vault_root = "/path/to/vault",
    locale = "en-US",
    log_level = "warn",
    force_create_key = "<S-CR>",
    new_notes_subdir = "/path/to/vault",
    journal = { ... },
    dataview = { ... },
  },

  -- Domain contracts (internal use)
  domains = {
    vault_catalog = { ... },    -- Vault indexing contract
    journal = { ... },          -- Journal operations contract
    wiki_link = { ... },        -- Wiki link handling contract
    template = { ... },         -- Template rendering contract
    dataview = { ... },         -- Dataview execution contract
    search_ranking = { ... },   -- Full-text search contract
  },

  -- Use case implementations (internal use)
  use_cases = {
    ensure_open_note = { ... },      -- Create/open note
    follow_link = { ... },           -- Follow wiki link
    reindex_sync = { ... },          -- Full vault reindex
    render_query_blocks = { ... },   -- Dataview rendering
    search_open_create = { ... },    -- Search and open/create
    show_backlinks = { ... },        -- Backlinks to note
    vault_search = { ... },          -- Global vault search
    insert_template = { ... },       -- Template insertion
  },

  -- Neovim adapters (internal use)
  adapters = {
    commands = { ... },     -- Command registration
    notifications = { ... },  -- Notifications toasts
    navigation = { ... },   -- Buffer/window navigation
    telescope = { ... },    -- Telescope picker
    cmp_source = { ... },   -- Completion source
    fs_io = { ... },        -- Filesystem I/O
    watcher = { ... },      -- File watcher
    frontmatter = { ... },  -- Frontmatter parsing
    markdown = { ... },     -- Markdown parsing
  },
}
```

### Behavior

1. **Validation**: Configuration is validated at setup time. Invalid config raises error with clear message:
   ```
   nvim-obsidian setup: <field> <reason>
   ```

2. **Deterministic**: Repeated calls with identical options return the same container (cached).

3. **Idempotent**: Repeated calls with different options re-initialize wiring and re-bootstrap services.

4. **Async Initialization**: Vault scanning happens asynchronously after setup returns. Cache is ready when notification fires:
   ```
   nvim-obsidian: vault cache ready
   ```

5. **Hard Dependencies**: Verifies Neovim plugins are installed:
   - `nvim-telescope/telescope.nvim` (required for pickers)
   - `hrsh7th/nvim-cmp` (required for completion)
   - `nvim-treesitter/nvim-treesitter` (required for markdown parsing)
   - `nvim-lua/plenary.nvim` (required for async jobs)

---

## Template Placeholder Registration

### Signature

```lua
require("nvim_obsidian").template_register_placeholder(name, resolver) -> nil
```

### Arguments

| Parameter | Type     | Description                                  |
| --------- | -------- | -------------------------------------------- |
| name      | string   | Placeholder name (alphanumeric + underscore) |
| resolver  | function | Function(ctx) → string that resolves value   |

### Resolver Context

The resolver function receives a context object:

```lua
{
  note = {
    title = string,        -- Note title from frontmatter or filename
    type = string,         -- "standard" | "daily" | "weekly" | "monthly" | "yearly"
    input = string,        -- User search input that matched note
    rel_path = string,     -- Path relative to vault_root
    aliases = table,       -- List of aliases from frontmatter
    tags = table,          -- List of tags from frontmatter
    abs_path = string,     -- Absolute filesystem path
  },

  time = {
    timestamp = number,    -- Current unix timestamp
    local = table,         -- Local time table (year, month, day, hour, min, sec, ...)
    utc = table,           -- UTC time table
    iso = table,           -- ISO time (iso_year, iso_week, iso_weekday, ...)
    
    -- Helper functions
    format_local = function(fmt: string) -> string,  -- Format using local time
    format_utc = function(fmt: string) -> string,    -- Format using UTC time
  },

  config = {
    -- Read-only access to configuration
    vault_root = string,
    locale = string,
    log_level = string,
    -- ... other config fields
  },
}
```

### Example

```lua
require("nvim_obsidian").setup({
  vault_root = "/home/user/ObsidianVault",
})

-- Register custom placeholder
require("nvim_obsidian").template_register_placeholder("title", function(ctx)
  return ctx.note.title
end)

-- Register date placeholder
require("nvim_obsidian").template_register_placeholder("date", function(ctx)
  return ctx.time.format_local("%Y-%m-%d")
end)

-- Register vault path placeholder
require("nvim_obsidian").template_register_placeholder("vault", function(ctx)
  return ctx.config.vault_root
end)

-- Register author placeholder
require("nvim_obsidian").template_register_placeholder("author", function(ctx)
  return "John Doe"
end)
```

### Usage in Templates

Placeholders are referenced in template files using `{{placeholder_name}}`:

```markdown
# {{title}}

Created: {{date}}
Author: {{author}}
Vault: {{vault}}

Unknown placeholders remain unchanged: {{unknown}} → {{unknown}}
```

---

## Journal Placeholder Registration

### Signature

```lua
require("nvim_obsidian").journal.register_placeholder(name, resolver, regex_fragment) -> nil
```

### Arguments

| Parameter      | Type     | Description                                    |
| -------------- | -------- | ---------------------------------------------- |
| name           | string   | Placeholder name                               |
| resolver       | function | Function(ctx) → string that resolves value     |
| regex_fragment | string   | Regex pattern to recognize placeholder in text |

### Example

```lua
require("nvim_obsidian").journal.register_placeholder(
  "today",
  function(ctx)
    return ctx.time.format_local("%Y-%m-%d")
  end,
  "{{today}}"
)
```

---

## Command Reference

### ObsidianOmni

**Purpose:** Search vault and open/create note

**Keybinding:** Recommended: `<leader>on` (Omni Notes)

**Usage:**
```vim
:ObsidianOmni
```

**Behavior:**
1. Opens Telescope picker with all vault notes
2. Can search by note title, aliases, tags, or file path
3. Press `<CR>` to open selected note
4. Press `<S-CR>` (or custom `force_create_key`) to create new note with search text as title
5. Auto-detects note type based on `new_notes_subdir` target

**Examples:**
```vim
:ObsidianOmni
" Type "My Project" and press <S-CR> to create new note

:ObsidianOmni
" Search existing "Project Setup" and press <CR> to open
```

---

### ObsidianToday

**Purpose:** Open or create today's daily journal note

**Keybinding:** Recommended: `<leader>ot` (Obsidian Today)

**Usage:**
```vim
:ObsidianToday
```

**Behavior:**
1. Calculates today's date using system timezone
2. Resolves journal.daily.title_format placeholder (e.g., "{{year}}-{{month}}-{{day}}")
3. Creates note if missing, or opens if exists
4. Note is created in journal.daily.subdir path

**Requirements:**
- Journal must be configured with `daily` section
- Requires fields: `journal.daily.subdir`, `journal.daily.title_format`

**Example Setup:**
```lua
require("nvim_obsidian").setup({
  vault_root = "/home/user/ObsidianVault",
  journal = {
    daily = {
      subdir = "11 Diário/11.01 Diário",
      title_format = "{{year}}-{{month}}-{{day}}",
    }
  }
})
```

---

### ObsidianNext

**Purpose:** Open next journal note (relative to current)

**Keybinding:** Recommended: `<leader>on` (Obsidian Next)

**Usage:**
```vim
:ObsidianNext
```

**Behavior:**
1. Detects current note type (daily, weekly, etc.)
2. Calculates next period (tomorrow if in daily, next week if in weekly)
3. Resolves title_format for that period
4. Creates note if missing, or opens if exists

**Requirements:**
- Current buffer must be a journal note
- Journal section for that period must be configured

---

### ObsidianPrev

**Purpose:** Open previous journal note (relative to current)

**Keybinding:** Recommended: `<leader>op` (Obsidian Prev)

**Usage:**
```vim
:ObsidianPrev
```

**Behavior:**
1. Detects current note type (daily, weekly, etc.)
2. Calculates previous period (yesterday if in daily, last week if in weekly)
3. Resolves title_format for that period
4. Creates note if missing, or opens if exists

**Requirements:**
- Current buffer must be a journal note
- Journal section for that period must be configured

---

### ObsidianFollow

**Purpose:** Follow wiki link under cursor

**Keybinding:** Recommended: `<leader>of` (Obsidian Follow)

**Usage:**
```vim
:ObsidianFollow
```

**Behavior:**
1. Detects wiki link at cursor position: `[[note-title]]` or `[[file.md#anchor]]`
2. Resolves link target (exact match or fuzzy search if ambiguous)
3. Opens target note in current window
4. Jumps to anchor if specified (e.g., `#heading`)

**Link Formats Supported:**
- `[[Note Title]]` - Link by note title (fuzzy matched)
- `[[note.md]]` - Link by file path (relative to vault)
- `[[Note Title#heading]]` - Link to heading within note
- `[[note.md#^block-id]]` - Link to block reference

---

### ObsidianBacklinks

**Purpose:** Show all notes linking to current note

**Keybinding:** Recommended: `<leader>ob` (Obsidian Backlinks)

**Usage:**
```vim
:ObsidianBacklinks
```

**Behavior:**
1. Identifies current note by file path
2. Scans entire vault for references to this note
3. Opens Telescope picker with all backlinks
4. Press `<CR>` to open a backlink source
5. Shows context (surrounding text) for each link

**Output Example:**
```
File: "Project Alpha.md" (3 backlinks)
  Line 5:   "We started work on [[Project Alpha]]..."
  Line 12:  "Related project: [[Project Alpha#timeline]]"

File: "2026-03-28.md" (1 backlink)
  Line 3:   "Worked on [[Project Alpha]] today"
```

---

### ObsidianSearch

**Purpose:** Global full-text search across entire vault

**Keybinding:** Recommended: `<leader>os` (Obsidian Search)

**Usage:**
```vim
:ObsidianSearch
```

**Behavior:**
1. Opens Telescope picker for vault-wide search
2. Searches note titles, aliases, tags, file paths, and content
3. Results ranked by relevance (title match > alias match > tag match > content match)
4. Press `<CR>` to open selected note
5. Can refine search using Telescope filters

**Search Features:**
- Case-insensitive by default
- Fuzzy matching on note titles
- Tag search: `tag:project` or `#project`
- Type filter: `type:daily` or `type:weekly`

---

### ObsidianReindex

**Purpose:** Force full vault reindex and cache refresh

**Keybinding:** Recommended: `<leader>or` (Obsidian Reindex)

**Usage:**
```vim
:ObsidianReindex
```

**Behavior:**
1. Scans entire vault directory
2. Re-parses all Markdown files
3. Rebuilds note catalog (titles, aliases, tags, links)
4. Updates backlink graph
5. Notifies when complete: `nvim-obsidian: reindex complete`

**Use Cases:**
- After bulk import of notes (Obsidian desktop app)
- After external file system changes
- To sync after moving notes around

**Performance:**
- Small vaults (<1000 notes): <500ms
- Medium vaults (1000-5000 notes): <2s
- Large vaults (>5000 notes): <10s

---

### ObsidianInsertTemplate

**Purpose:** Insert rendered template at cursor position

**Keybinding:** Recommended: `<leader>ot` (Obsidian Template)

**Usage:**
```vim
:ObsidianInsertTemplate                    " Auto-detect type from current buffer
:ObsidianInsertTemplate standard           " Insert standard note template
:ObsidianInsertTemplate daily              " Insert daily journal template
:ObsidianInsertTemplate weekly             " Insert weekly journal template
:ObsidianInsertTemplate monthly            " Insert monthly journal template
:ObsidianInsertTemplate yearly             " Insert yearly journal template
:ObsidianInsertTemplate ./path/to/file.md " Insert from custom template file
:ObsidianInsertTemplate /abs/path/to/file " Insert from absolute path
```

**Behavior:**
1. Loads template for specified type (or auto-detects from current note)
2. Resolves all placeholders: `{{title}}`, `{{date}}`, custom registered placeholders
3. Inserts rendered template at cursor position
4. Unknown placeholders remain unchanged

**Template Argument Completion:**
- Supports completion for: `standard`, `daily`, `weekly`, `monthly`, `yearly`
- Tab-complete in Neovim command line for quick selection

**Example Usage:**
```vim
" In a daily journal note, insert template
:ObsidianInsertTemplate daily

" In an empty note, specify what you want
:ObsidianInsertTemplate standard

" Load custom template with placeholders
:ObsidianInsertTemplate ~/templates/project.md
```

---

### ObsidianRenderDataview

**Purpose:** Explicitly re-render all dataview blocks in current buffer

**Keybinding:** Recommended: `<leader>ov` (Obsidian View)

**Usage:**
```vim
:ObsidianRenderDataview
```

**Behavior:**
1. Scans current buffer for dataview query blocks
2. Re-executes all queries (task lists, table views, etc.)
3. Updates rendered results inline
4. Notifies: `Rendered <N> dataview blocks`
5. Shows parse errors if query syntax is invalid

**Dataview Block Format:**
````markdown
```dataview
task
WHERE status = "🔴"
GROUP BY project
```
````

**Use Cases:**
- After editing note properties that affect dataview results
- After adding/completing tasks to refresh a task list
- Debugging dataview query syntax

---

### ObsidianHealth

**Purpose:** Verify nvim-obsidian adapter wiring and dependencies

**Keybinding:** Recommended: `<leader>oh` (Obsidian Health)

**Usage:**
```vim
:ObsidianHealth
```

**Behavior:**
1. Checks if setup was called and completed
2. Verifies all hard dependencies are installed
3. Reports adapter wiring status
4. Shows: `nvim-obsidian health: ok` if all green

**Dependencies Checked:**
- nvim-telescope/telescope.nvim
- hrsh7th/nvim-cmp
- nvim-treesitter/nvim-treesitter
- nvim-lua/plenary.nvim

**Troubleshooting:**
If health check fails, see docs/TROUBLESHOOTING.md for resolution steps.

---

## Configuration Example (Complete)

```lua
-- init.lua or init.vim (vim.cmd [[ lua = ... ]])

require("nvim_obsidian").setup({
  -- REQUIRED: Obsidian vault directory
  vault_root = "/home/user/ObsidianVault",

  -- Optional: Where new standard notes go
  new_notes_subdir = "10 Novas notas",

  -- Optional: Locale for month/weekday names
  locale = "pt-BR",  -- Default: "en-US"

  -- Optional: Log level for debugging
  log_level = "warn",  -- "error" | "warn" | "info"

  -- Optional: Telescope force-create key
  force_create_key = "<S-CR>",  -- Custom key combo

  -- Optional: Journal configuration
  journal = {
    daily = {
      subdir = "11 Diário/11.01 Diário",
      title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}"
    },
    weekly = {
      subdir = "11 Diário/11.02 Semanal",
      title_format = "Semana {{iso_week}} de {{iso_year}}"
    },
    monthly = {
      subdir = "11 Diário/11.03 Mensal",
      title_format = "{{month_name}} {{year}}"
    },
  },

  -- Optional: Dataview rendering configuration
  dataview = {
    enabled = true,
    render = {
      when = { "on_open", "on_save" },    -- When to auto-render
      scope = "event",                     -- event | current | visible | loaded
      patterns = { "*.md" },               -- File patterns to scan
    },
    placement = "below_block",             -- below_block | above_block
    messages = {
      task_no_results = {
        enabled = true,
        text = "Dataview: No results to show for task query."
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

-- Suggested keybindings
local map = vim.keymap.set
map("n", "<leader>on", ":ObsidianOmni<CR>", { noremap = true, silent = true })
map("n", "<leader>ot", ":ObsidianToday<CR>", { noremap = true, silent = true })
map("n", "<leader>of", ":ObsidianFollow<CR>", { noremap = true, silent = true })
map("n", "<leader>ob", ":ObsidianBacklinks<CR>", { noremap = true, silent = true })
map("n", "<leader>os", ":ObsidianSearch<CR>", { noremap = true, silent = true })
map("n", "<leader>or", ":ObsidianReindex<CR>", { noremap = true, silent = true })
map("n", "<leader>oi", ":ObsidianInsertTemplate<CR>", { noremap = true, silent = true })
map("n", "<leader>ov", ":ObsidianRenderDataview<CR>", { noremap = true, silent = true })
map("n", "<leader>oh", ":ObsidianHealth<CR>", { noremap = true, silent = true })
```

---

## Error Handling

### Common Errors

#### "nvim-obsidian setup: vault_root must be an absolute path"
- **Cause**: Provided relative path (e.g., `"~/MyVault"` or `"./vault"`)
- **Fix**: Use absolute path: `/home/user/MyVault` or expand `~` to full path

#### "nvim-obsidian setup: vault_root must be a non-empty string"
- **Cause**: Missing or nil `vault_root`
- **Fix**: Add required `vault_root` field to setup options

#### "nvim-obsidian setup: log_level has invalid value: debug"
- **Cause**: log_level not in allowed enum
- **Fix**: Use one of: `"error"`, `"warn"`, `"info"`

#### "nvim-obsidian setup: dataview.render.scope has invalid value: workspace"
- **Cause**: Invalid dataview scope
- **Fix**: Use one of: `"event"`, `"current"`, `"visible"`, `"loaded"`

#### "nvim-obsidian setup: journal.daily.title_format must be a non-empty string"
- **Cause**: Journal section missing required field
- **Fix**: Ensure all configured journal sections have both `subdir` and `title_format`

---

Last Updated: March 28, 2026
