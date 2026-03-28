# Phase 8 Part 2: Config Schema & Validation Contract

Version: 1.0
Date: March 28, 2026
Status: Complete & Validated

Document role: Specification for Phase 8 Part 2 config validation and schema enhancements.
Related documents:
- docs/PRODUCT_CONTRACT.md (Configuration Requirements section)
- docs/IMPLEMENTATION_PHASES.md (Phase 8 progress tracking)

---

## Overview

Phase 8 Part 2 expands the Phase 8 Part 1 config foundations with:
1. Full dataview schema validation (render, placement, messages).
2. Optional journal section validation (daily/weekly/monthly/yearly).
3. Strict enum validation for log_level, dataview scope, placement, render triggers.
4. Clear error messages for all invalid cases.

---

## validation Rules

### Required Fields

| Field            | Type   | Constraint               | Default  |
| ---------------- | ------ | ------------------------ | -------- |
| vault_root       | string | non-empty, absolute path | REQUIRED |
| locale           | string | non-empty                | "en-US"  |
| log_level        | enum   | "error", "warn", "info"  | "warn"   |
| force_create_key | string | non-empty                | "<S-CR>" |

### Dataview Block (required shape when enabled)

| Field                                     | Type     | Constraint                                        |
| ----------------------------------------- | -------- | ------------------------------------------------- |
| dataview.enabled                          | boolean  | required                                          |
| dataview.render.when                      | string[] | non-empty list of: on_open, on_save, on_buf_enter |
| dataview.render.scope                     | string   | must be one of: event, current, visible, loaded   |
| dataview.render.patterns                  | string[] | non-empty list of glob patterns                   |
| dataview.placement                        | string   | must be one of: below_block, above_block          |
| dataview.messages.task_no_results.enabled | boolean  | required                                          |
| dataview.messages.task_no_results.text    | string   | non-empty required                                |

### Optional Journal Sections

When `journal` table is provided, each section (daily/weekly/monthly/yearly) may be configured.
If a section is present, both `.subdir` and `.title_format` must be non-empty strings.

Example valid journal config:

```lua
journal = {
    daily = {
        subdir = "journal/daily",
        title_format = "{{year}}-{{month}}-{{day}}"
    },
    weekly = {
        subdir = "journal/weekly",
        title_format = "{{iso_year}}-W{{iso_week}}"
    }
}
```

---

## Error Handling

All validation failures fail fast at setup time with a clear message following this format:

```
nvim-obsidian setup: <specific field> <reason>
```

Example:

```
nvim-obsidian setup: vault_root must be an absolute path
nvim-obsidian setup: dataview.render.scope has invalid value: workspace
nvim-obsidian setup: journal.daily.title_format must be a non-empty string
```

---

## Deterministic Config Normalization

1. User input is merged with defaults using `vim.tbl_deep_extend("force", defaults, user)`.
2. Defaults are never mutated.
3. All validation happens after merge (`opts` table).

Current defaults:

```lua
{
    log_level = "warn",
    locale = "en-US",
    force_create_key = "<S-CR>",
    dataview = {
        enabled = true,
        render = {
            when = { "on_open", "on_save" },
            scope = "event",
            patterns = { "*.md" },
        },
        placement = "below_block",
        messages = {
            task_no_results = {
                enabled = true,
                text = "Dataview: No results to show for task query.",
            },
        },
    },
}
```

---

## User API Contract

```lua
-- Require vault_root (absolute path) and journal when journal is enabled.
-- All other fields are optional.

require("nvim_obsidian").setup({
    vault_root = "/home/user/ObsidianVault",  -- REQUIRED
    
    -- Optional overrides
    locale = "pt-BR",
    log_level = "info",
    new_notes_subdir = "10 Novas notas",
    force_create_key = "<C-n>",
    
    dataview = {
        enabled = true,
        render = {
            when = { "on_open" },
            scope = "current",
            patterns = { "*.md", "*.markdown" },
        },
        placement = "above_block",
        messages = {
            task_no_results = {
                enabled = false,
            },
        },
    },
    
    journal = {
        daily = {
            subdir = "11 Diário/11.01 Diário",
            title_format = "{{year}} {{month_name}} {{day2}}, {{weekday_name}}",
        },
        weekly = {
            subdir = "11 Diário/11.02 Semanal",
            title_format = "{{iso_year}} semana {{iso_week}}",
        },
    },
})
```

---

## Test Coverage

Phase 8 Part 2 verification:
- ✅ Rejects missing vault_root.
- ✅ Rejects relative vault_root.
- ✅ Applies all defaults deterministically.
- ✅ Does not mutate user input.
- ✅ Rejects invalid log_level enum values.
- ✅ Rejects invalid dataview.render.scope values.
- ✅ Rejects invalid dataview.render.when trigger values.
- ✅ Rejects invalid dataview.placement values.
- ✅ Rejects non-list dataview.render.patterns.
- ✅ Rejects incomplete journal sections (missing subdir or title_format).
- ✅ Accepts valid optional journal configuration.

Tests: tests/unit/config_schema_spec.lua (11 cases)

---

## Phase 8 Part 3 Prerequisite

Config schema is now complete and validated. Phase 8 Part 3 will expand beyond setup to cover:
1. User-facing API documentation (README update with config examples).
2. Config error recovery and hints (e.g., "did you forget vault_root?").
3. Schema versioning for backward compatibility planning.

---

Last Updated: March 28, 2026
