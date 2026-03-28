# Static Dependency Rules (Phase 2)

These rules operationalize ADR-001.

## Allowed dependency direction

Adapters -> Use Cases -> Domains -> Shared

## Forbidden dependencies

- Domains must not require adapters.
- Domains must not require use_cases.
- Use cases must not require adapters.
- Shared must not require domains/use_cases/adapters.
- Plugin entrypoint must not contain business logic.

## Conventions to enforce

- Any vim.api usage belongs in adapters/neovim.
- Any filesystem watcher logic belongs in adapters/filesystem.
- Domain modules expose deterministic contracts and pure logic only.
- Cross-domain orchestration belongs in use_cases.

## Review checklist

1. Does any domain file require adapter modules?
2. Does any use case directly call vim.api?
3. Are business rules present in adapters?
4. Is all wiring centralized in app/container.lua and app/bootstrap.lua?
