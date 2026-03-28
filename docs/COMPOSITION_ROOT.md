# Composition Root Pattern (Phase 2)

Composition root is the single location where modules are wired.

## Files

- lua/nvim_obsidian/app/container.lua
- lua/nvim_obsidian/app/bootstrap.lua
- lua/nvim_obsidian/init.lua

## Pattern

1. Normalize config in app/config.lua.
2. Build a dependency container in app/container.lua.
3. Start integration wiring in app/bootstrap.lua.
4. Expose setup through lua/nvim_obsidian/init.lua.

## Constraints

- Domain modules are imported by container, not by plugin entrypoint.
- Commands are registered from adapter layer only.
- No business rules in bootstrap.
