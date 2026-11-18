# Shared Web Application Instructions

This is a small web application. Respect the existing stack and conventions; do not introduce frameworks or infrastructure without a clear reason.

- Inspect the repository, package scripts, and relevant tests before proposing edits.
- Keep changes narrowly scoped to the user's request. Prefer simple, maintainable solutions over complex abstractions.
- Preserve existing public interfaces and behavior unless a change is explicitly requested.
- Enforce authentication, authorization, and validation on the server when applicable.
- Never hardcode secrets or put sensitive server data in client code.
- Use accessible, responsive UI patterns; include loading, empty, and error states.
- Follow `docs/DESIGN-SYSTEM.md` and `docs/UX-FLOWS.md` for responsive layouts. Keep mobile screens compact (600px and below), preserve at least 44px interactive targets, and verify new UI at mobile, tablet, and desktop widths.
- On signed-in mobile screens, preserve the fixed bottom icon navigation, its accessible names and device safe-area padding; ensure page content can scroll clear of it.
- Add or update tests for meaningful behavior changes.
- When feasible, run the repository's existing lint, typecheck, test, and build commands.
- State which checks were actually run and what remains unverified.
- Ask for approval before destructive database operations, deployment, adding paid services, or wide architectural changes.
- Write brief handoff notes in docs/TASKS.md when moving between agents.

## Project visual identity
- Before major user-facing implementation, read `docs/DESIGN-SYSTEM.md`, `docs/UI-REFERENCES.md`, and `docs/UX-FLOWS.md`. If these are unfilled templates, use Design-System/UI-UX for discovery before coding significant screens.
- Do not default to generic gradient dashboards or scatter inconsistent colors, radii or typography throughout the app. Choose patterns based on the audience, tasks, and approved project direction.
- Reuse existing components and semantic design tokens. Make responsive, accessible states part of acceptance criteria.
- When possible, validate actual rendered UI via Visual-QA; never claim screenshot/visual checks were run without evidence.

## Technology selection gate
- For **new projects**, Planner and Tech Stack Advisor must assess requirements, compare suitable stacks and request explicit approval **before** scaffolding, installing dependencies or implementing code. Record the decision in `docs/TECH-STACK-EVALUATION.md` and `docs/ARCHITECTURE.md`.
- For **existing projects**, inspect and preserve the established stack; only reopen selection for material new requirements or clearly documented failure modes.
- Do not claim you checked current framework support or compatibility without using available verification tools and citing results.
