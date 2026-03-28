# Phase 3 Contracts Reference

This document indexes Phase 3 contract artifacts.

## Shared primitives

- lua/nvim_obsidian_v2/core/shared/primitives.lua
- lua/nvim_obsidian_v2/core/shared/errors.lua

## Domain contracts

- lua/nvim_obsidian_v2/core/domains/vault_catalog/contract.lua
- lua/nvim_obsidian_v2/core/domains/journal/contract.lua
- lua/nvim_obsidian_v2/core/domains/wiki_link/contract.lua
- lua/nvim_obsidian_v2/core/domains/template/contract.lua
- lua/nvim_obsidian_v2/core/domains/dataview/contract.lua
- lua/nvim_obsidian_v2/core/domains/search_ranking/contract.lua

## Use-case contracts

- lua/nvim_obsidian_v2/use_cases/ensure_open_note.lua
- lua/nvim_obsidian_v2/use_cases/follow_link.lua
- lua/nvim_obsidian_v2/use_cases/reindex_sync.lua
- lua/nvim_obsidian_v2/use_cases/render_query_blocks.lua
- lua/nvim_obsidian_v2/use_cases/search_open_create.lua

## Contract policy

- These files define interface and shape contracts only.
- Business implementations are deferred to later phases.
