# V2 Repository Layout (Phase 2)

This document defines the enforced Phase 2 skeleton.

## Root

- lua/nvim_obsidian_v2
- plugin
- tests
- docs

## Architecture-aligned folders

- lua/nvim_obsidian_v2/core
  - domains
  - shared
- lua/nvim_obsidian_v2/use_cases
- lua/nvim_obsidian_v2/adapters
  - neovim
  - picker
  - completion
  - filesystem
  - parser
- lua/nvim_obsidian_v2/app

## Rule Summary

- Domain logic lives only in core/domains.
- Use-case orchestration lives only in use_cases.
- Neovim and external integrations live only in adapters.
- Bootstrap and wiring live only in app.
