# ADR-001: Layering and Dependency Rules

## Status

Accepted

## Date

March 28, 2026

## Context

Phase 0 defined a clean architecture model with explicit domain boundaries and a one-way dependency rule. The current V1 plugin has tight coupling risks from shared singleton state, while V2 is intended to preserve feature parity with strict architectural isolation.

Without an explicit ADR, dependency violations are likely during implementation (for example adapters leaking into domains, cross-domain imports, or command-layer logic inside lower layers).

## Decision Drivers

- Preserve long-term maintainability for a plugin with many feature domains.
- Prevent architecture drift while implementing Phase 2+.
- Improve testability by isolating pure logic from Neovim and filesystem concerns.
- Keep user-visible behavior stable while allowing internal refactors.

## Selected Approach

Strict layered architecture with enforcement rules.

## Decision

Adopt strict layered architecture with explicit dependency rules:

1. Adapters may depend on services, domains, and shared modules.
2. Services may depend on domains and shared modules.
3. Domains may depend only on shared modules.
4. Shared modules must not depend on adapters, services, or domains.
5. Reverse or lateral dependencies across disallowed layers are forbidden.

Dependency direction:

Adapters -> Services -> Domains -> Shared

## Architectural Rules

- Domains are pure business logic and must not call Neovim APIs directly.
- Filesystem and parsing concerns are adapter responsibilities.
- Command registration and UI integrations stay in adapter layer.
- Services orchestrate multi-domain workflows and application transactions.
- Shared modules may contain utilities, constants, and value helpers only.

## Consequences

### Positive

- Predictable architecture and easier onboarding.
- Lower coupling and improved modularity.
- Higher confidence in isolated testing.

### Negative

- More explicit interfaces required.
- Some short-term friction when wiring modules.

### Risks and Mitigations

Risk:
- Teams may bypass boundaries to move faster.

Mitigation:
- Add architecture checks in PR review rubric.
- Keep domain APIs narrow and explicit.

## Enforcement

- Each Phase 2+ PR must list touched layers and confirm dependency direction.
- Any intentional exception requires an ADR update or superseding ADR.

## Related Documents

- ../PROJECT_CONTEXT.md
- ../DOMAIN_OWNERSHIP_MAP.md
- ../PRODUCT_CONTRACT.md
- ../UX_BEHAVIOR_CONTRACT.md
