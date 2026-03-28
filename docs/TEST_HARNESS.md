# Test Harness (Phase 4)

This document defines the initial harness and execution model.

## Pyramid

1. Unit (`tests/unit`)
2. Integration (`tests/integration`)
3. E2E (`tests/e2e`)

Red tests used for TDD entrypoints are isolated in `tests/unit_red`.

## Commands

From repository root:

1. `make test-unit`
2. `make test-integration`
3. `make test-e2e`
4. `make test`
5. `make test-red` (expected to fail until Phase 5 implementations exist)

## Deterministic Fixtures

- Vault fixture root: `tests/fixtures/vault`
- Golden behavior scenarios: `tests/golden/scenarios.lua`

Fixtures are static text assets and should only change when product behavior contracts change.

## Red-Suite Policy

Red tests intentionally fail and are not part of `make test`.
They provide the explicit TDD entrypoint for domain implementation in Phase 5.
