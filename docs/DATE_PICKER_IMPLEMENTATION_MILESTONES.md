# Date Picker Implementation Milestones

Status: MVP in progress (M1, M2, and M3 implemented; M4 in progress)
Owner: nvim-obsidian maintainers
Last Updated: 2026-04-25

## Goal

Introduce a reusable calendar capability with two user-facing modes:

1. Date visualizer mode (browse/navigate calendar without selecting)
2. Date picker mode (select a date and return it to a consumer)

The picker returns a selected date (and optional metadata), while feature-specific
actions (journal open/create, template insert, query scope, etc.) remain outside this module.

## Why This Direction

- Keeps separation of concerns clean:
  - date browsing/selection is UI + interaction logic
  - business actions remain in their own domains/use cases
- Makes future reuse straightforward (journal, dataview filters, custom commands, future CLI)
- Reduces risk of duplicated date-navigation logic in multiple features
- Preserves direct end-user value even when no consumer action is attached (visualizer mode)

## Architecture Decision

Decision: Build a reusable calendar backend contract first, ship one UI frontend first (normal buffer),
and support both visualizer and picker modes through the same backend contract.

Rationale:
- Delivers user value quickly
- Preserves layered architecture (domain -> use case -> adapter)
- Allows adding floating window and other frontends later with minimal rewrite

## Proposed Layering

### Domain (pure)

Responsibility:
- Date-grid model generation (month matrix, navigation boundaries, selected day)
- Cursor movement rules (left/right/up/down/page jumps)
- Optional annotations model (today, selected, has_note)

Must not do:
- No Neovim API calls
- No filesystem I/O
- No navigation/opening files

### Use Case (orchestration)

Responsibility:
- Accept calendar options including mode ("visualizer" | "picker")
- Request the UI adapter to display calendar
- In picker mode, return selected date payload to caller
- In visualizer mode, return browse outcome without requiring selection

Notes:
- Keep this generic so multiple features can consume it.
- Journal-specific behavior must not live here.

### Adapters

Responsibility:
- Render and handle interaction for a specific frontend
- First frontend: normal buffer date picker
- Future frontend: floating window date picker

Mode behavior:
- visualizer: navigate months/years/days, optional read-only note indicators
- picker: same navigation plus explicit confirm/cancel selection actions

## Public Contract Draft (subject to implementation)

Date object:
- year (number)
- month (1-12)
- day (1-31)

Date picker result:
- ok (boolean)
- action ("selected" | "cancelled")
- date (table | nil)

Calendar visualizer result:
- ok (boolean)
- action ("closed" | "cancelled")
- cursor_date (table | nil)

Date picker input options:
- initial_date (table | nil)
- locale (string | nil)
- marks (optional metadata keyed by date token)
- ui_variant ("buffer" for milestone 1)
- mode ("visualizer" | "picker")

Suggested user entrypoint (planned):
- `:ObsidianCalendar` opens visualizer mode by default

## Integration Strategy

### Journal integration (first consumer)

1. Add a command entrypoint that opens date picker.
2. On date selection, journal command composes a title token for daily journal kind.
3. Journal command calls existing ensure_open_note use case.
4. Journal logic remains in journal/ensure_open_note, not in picker internals.

### Future consumers

- Any command/use case can consume picker and decide what to do with date result.

## Milestones

### M1 - Date Picker Core Contract

Scope:
- Define domain types and pure date grid/navigation functions
- Add unit tests for date matrix and cursor navigation edge cases

Exit criteria:
- No Neovim dependency in core date logic
- Tests cover leap years, month boundaries, locale-dependent week starts (if supported)

### M2 - Buffer UI Adapter

Scope:
- Implement normal buffer UI renderer + keymaps
- Support month/year navigation and day selection
- Support visualizer and picker interaction modes
- Return selected date payload only in picker mode

Exit criteria:
- User can navigate years, months, days interactively
- Selection and cancel both return deterministic results
- Visualizer mode works without forcing selection

### M3 - Journal Consumer Command

Scope:
- Add one journal command that invokes date picker and then open/create journal note
- Reuse existing ensure_open_note flow
- Keep visualizer command independent from journal behavior
- Support daily/weekly/monthly/yearly selection from picker UI

Exit criteria:
- Selecting a date opens or creates correct journal note in configured subdir
- Existing journal commands remain unchanged and passing

### M4 - Hardening and Expandability

Scope:
- Add integration tests for command-to-picker-to-journal flow
- Stabilize adapter boundaries and document extension points
- Optional: expose a reusable internal API for other use cases

Exit criteria:
- Clear extension path for floating UI variant
- Documentation is sufficient for new contributors

## Commenting and Documentation Policy for This Feature

The implementation must be very well commented.

Rules:
- Every non-trivial function includes a short purpose comment.
- Every state transition in UI interaction loop is explained.
- Every domain rule with edge cases includes rationale comments.
- Public contracts include inline examples for expected input/output.
- Avoid comments that restate obvious code; comments must explain intent and constraints.

## Implementation File Map (MVP)

- Core date-picker domain:
  - `lua/nvim_obsidian/core/domains/date_picker/impl.lua`
- Generic open-date-picker use case:
  - `lua/nvim_obsidian/use_cases/open_date_picker.lua`
- Buffer UI calendar adapter:
  - `lua/nvim_obsidian/adapters/neovim/calendar_buffer.lua`
- Container wiring updates:
  - `lua/nvim_obsidian/app/container.lua`
- Command entrypoint updates:
  - `lua/nvim_obsidian/adapters/neovim/commands.lua`

## Change Log (append-only)

### 2026-04-23

- Established feature direction: calendar is a reusable date picker, not a journal-only view.
- Chosen first delivery UI: normal buffer frontend.
- Defined milestone roadmap M1-M4.
- Updated scope to explicitly include date visualizer mode for direct user use.
- Implemented M1 domain MVP: pure date normalization, day/month/year shifts, and fixed 6x7 month matrix.
- Implemented M2 adapter MVP: normal-buffer interactive calendar with navigation keymaps and picker/visualizer modes.
- Implemented generic open-date-picker use case and composition wiring so other domains can consume it.
- Added `:ObsidianCalendar` command with default visualizer mode and optional picker mode (`pick` / `picker`).
- Fixed UI freeze in `:ObsidianCalendar` by replacing blocking `vim.wait(...)` loop with non-blocking event-driven close/selection callbacks.
- Added calendar config schema under plugin config (`calendar.week_start`, `calendar.highlights.*`) and wired it through use-case and adapter.
- Updated date-picker backend month matrix to support configurable week starts while staying pure and frontend-agnostic.
- Switched default week start to Sunday and aligned weekday header rendering accordingly.
- Fixed out-of-month visual artifact (`.0`, `.1`, `.3`) by rendering stable two-digit days and using highlight groups for visual differentiation.
- Added initial calendar highlight application (title, weekday header, in-month days, outside-month days, today) as configurable frontend styling groundwork.
- Extended calendar picker selection so Enter can create daily, weekly, monthly, or yearly journal notes based on cursor row.
- Wired `:ObsidianCalendar pick` selection callback into `ensure_open_note` so chosen journal family opens/creates directly.
- Prevented picker hover from auto-switching month when cursor lands on out-of-month day cells.
- Changed row-2 horizontal movement to two logical cells (month and year), so one keypress jumps between them.
- Made title line non-focusable in picker interaction (line 1 is informational only).
- Confirmed UX direction that calendar is a secondary power flow alongside directional journal commands.
- Added `:ObsidianJournalCalendar` as a dedicated picker-first journal command while keeping `:ObsidianCalendar` generic.
- Refactored calendar picker completion logic in command adapter into shared helpers to keep multi-command behavior aligned.
- Changed `:ObsidianJournalCalendar` default layout to current-buffer mode for direct replace/open workflows.
- Added split-layout command variants: `:ObsidianJournalCalendarVSplit` and `:ObsidianJournalCalendarHSplit`.
- Extended date-picker request contract with layout selection (`current`, `vsplit`, `hsplit`).
- Hardened split rendering to always use a dedicated calendar buffer so the source buffer is not overwritten in both windows.
- Added shell-command delete sync (`ShellCmdPost`) to reconcile index deletes after external removal flows like `:!rm "%"`.

## Next Immediate Task

Continue M4 hardening with:

1. Floating-window calendar frontend (new UI adapter variant)
2. Optional confirmation prompt before creating notes from calendar picker selections