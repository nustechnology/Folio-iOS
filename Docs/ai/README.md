# Folio AI Coding Guide

This directory is the implementation-derived reference for coding agents working in Folio iOS. It documents what the current codebase does and the patterns new work should follow.

## Instruction precedence

1. Root [`CLAUDE.md`](../../CLAUDE.md) is the primary project instruction and takes precedence over this directory.
2. Root [`AGENTS.md`](../../AGENTS.md) directs agents to `CLAUDE.md`.
3. These guides supplement those instructions with evidence from the current source code and tests.
4. When documentation and the implementation disagree, treat the current implementation and tests as the source of truth, then update the relevant documentation as part of the scoped work.

Existing general references remain in [`Docs/Architecture.md`](../Architecture.md), [`Docs/CodeStyle.md`](../CodeStyle.md), and [`Docs/Testing.md`](../Testing.md). Use this directory for details that are specific to the current app.

## Required workflow

Before changing code:

1. Read `CLAUDE.md` and the guide that matches the work.
2. Search for the closest existing feature, view model, endpoint, repository, DTO, component, helper, localization key, and test. Use `rg` before creating files or abstractions.
3. Reuse existing components, extensions, tokens, protocols, and test doubles before adding another implementation.
4. Confirm the file belongs in the existing layer and feature location. Preserve `Presentation → Domain ← Data`.
5. Keep the task scoped. Do not refactor unrelated code or use a feature as a reason to normalize legacy inconsistencies.

After changing code:

1. Format the changed Swift files using the project tooling available in the environment.
2. Run relevant lint, test, and build commands from [testing-validation.md](testing-validation.md).
3. Check localization, accessibility, error handling, dependency direction, and cancellation/race behavior where applicable.
4. Review `git diff --check` and the final diff. Report commands that cannot run or fail; do not claim they passed without output.

## Guides

- [Architecture](architecture.md): layers, feature structure, state/navigation, networking, storage, and resilience.
- [Coding conventions](coding-conventions.md): naming, file placement, state, errors, logging, and localization.
- [UI and design system](ui-design-system.md): tokens, shared SwiftUI components, visual rules, and accessibility.
- [Testing and validation](testing-validation.md): XCTest patterns and required checks.

## Non-negotiable rules

- Search before creating.
- Reuse before duplicating.
- Use existing color and duration tokens rather than hard-coded values.
- Follow the existing architecture and naming conventions.
- Check similar features before implementation.
- Avoid unnecessary abstractions and speculative configuration.
- Keep files focused; split new responsibilities when that is clearer than expanding an already-large file.
- Use the established localization, error-handling, logging, and test patterns.
