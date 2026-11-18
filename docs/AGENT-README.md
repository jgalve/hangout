# Generic GitHub Copilot Web App Agents — v3.1 (Stack + Design First)

Reusable custom agents for building small web apps in **VS Code with GitHub Copilot**. This pack has **9 agents**. Keep agents generic; put project-specific rules in documentation.

## Included agents

| Agent | Responsibility |
|---|---|
| **Orchestrator** | Main entry point; handles routing, approvals and milestones |
| Planner | Requirements, MVP scope, task breakdown, acceptance criteria |
| **Tech Stack Advisor (NEW)** | Compares stacks and documents recommendation **before project initialization** |
| Design-System | Distinct visual direction and reusable design tokens |
| UI-UX | Responsive user interfaces and UX states |
| Developer | Full-stack coding and setup against approved architecture |
| Visual-QA | Rendered screen, responsiveness and accessibility inspection |
| QA | Functional, integration and regression tests |
| Reviewer | Architecture, code quality and security review |

## Installation in VS Code

1. Install VS Code and enable GitHub Copilot Chat.
2. Open your project folder as the VS Code workspace root.
3. Extract this pack and **merge** its `.github/` directory into the project root; do not overwrite existing project-specific instructions blindly.
4. Optionally merge the `docs/` starter templates, preserving existing documents.
5. Open Copilot Chat in **Agent** mode and select **Orchestrator** from the agent selector.
6. For an existing project, edit `.github/copilot-instructions.md` to specify the approved stack, coding conventions and actual commands.
7. For a new project, use the initial prompt below and **approve the recommended stack before scaffolding**. Later approve a UI direction before major screens are built.

> Delegation depends on installed VS Code/Copilot capabilities and enabled tools. Agent handoffs can be manual; listing an agent is not proof it ran.

## Initial prompt — create a new web app (copy/paste)

```text
Build a small [DESCRIBE YOUR WEB APP] in this VS Code repository.

Act as Orchestrator. Coordinate Planner, Tech Stack Advisor, Design-System,
UI-UX, Developer, Visual-QA, QA and Reviewer when relevant.

FIRST — DO NOT WRITE APP CODE YET:
1. Inspect the repository, determine whether it is empty or established, and
   have Planner define the MVP, users, constraints and acceptance criteria.
2. Have Tech Stack Advisor evaluate up to three realistic end-to-end stacks
   (frontend, backend, database, authentication, hosting, testing).
3. Obtain Developer feasibility and Reviewer security/maintenance input where
   delegation is available. Produce a weighted comparison with trade-offs.
4. Save docs/TECH-STACK-EVALUATION.md and a proposed docs/ARCHITECTURE.md.
5. Recommend a primary stack and alternative and ASK FOR MY APPROVAL.
   Do not initialize packages or install dependencies before approval.

AFTER I APPROVE THE STACK:
6. Ask Design-System and UI-UX to propose 2-3 distinct visual directions
   suitable for the app and audience. Avoid generic AI dashboard patterns.
   Document tokens, references and flows, then request visual approval.
7. Have Developer initialize the approved stack and build one complete MVP
   feature at a time. UI-UX handles interface-specific changes.
8. Have QA run tests, Visual-QA inspect rendered pages if tools are present,
   and Reviewer assess correctness, security and maintainability.
9. Report actual files changed, commands run, test outcomes, limitations, and
   the next milestone. Do not claim absent tools/agents/tests ran.
```

## Prompt — select a stack for an existing idea (no code)

```text
Orchestrator: Evaluate the best stack for [APP IDEA]. Use Planner to establish
constraints and Tech Stack Advisor to compare appropriate alternatives.
Review feasibility and risks. Include a weighted decision matrix, official
documentation links when available, and an explicit approval request.
Create docs/TECH-STACK-EVALUATION.md and a proposed docs/ARCHITECTURE.md.
Do not install dependencies, scaffold a repository or write features yet.
```

## Prompt — add a new feature to an existing project

```text
Orchestrator: Add [FEATURE] to this app. Inspect the approved architecture
and existing code. Have Planner set acceptance criteria if needed. Use the
existing stack unless a concrete limitation requires a proposed change.
Have Developer implement a small scoped change, UI-UX assist when needed,
QA execute tests, Visual-QA inspect UI where available, and Reviewer assess
the diff. Report evidence, limitations and next steps.
```

## Prompt — improve a generic-looking UI

```text
Orchestrator: Review [SCREEN] using docs/DESIGN-SYSTEM.md, UI-REFERENCES.md,
and UX-FLOWS.md. Have Design-System/UI-UX propose a distinctive direction
for our audience, without copying proprietary designs. Ask my approval for
major visual changes. Implement shared tokens and components; run Visual-QA
on actual rendered mobile/desktop screens and report what was inspected.
```

## Prompt — fix a bug

```text
Orchestrator: Reproduce [BUG] in the existing project. Delegate the smallest
safe fix to Developer, regression verification to QA and high-risk review
to Reviewer. Preserve the approved architecture and report actual results.
```

## Standard workflows

**New project:** Planner → Tech Stack Advisor → Developer feasibility + Reviewer risk review → **human stack approval** → Design-System + UI-UX → **human design approval** → Developer → QA + Visual-QA → Reviewer.

**Existing app, new feature:** Planner (when needed) → Developer/UI-UX → QA → Reviewer. Preserve existing approved stack.

**Architecture change:** Planner + Tech Stack Advisor → human approval → implementation.

**Bug fix:** Developer → QA → Reviewer for consequential changes.

## Included files

```text
.github/
  copilot-instructions.md
  agents/
    orchestrator.agent.md
    planner.agent.md
    tech-stack-advisor.agent.md
    design-system.agent.md
    developer.agent.md
    ui-ux.agent.md
    visual-qa.agent.md
    qa.agent.md
    reviewer.agent.md
docs/
  TECH-STACK-EVALUATION.md
  ARCHITECTURE.md
  DESIGN-SYSTEM.md
  UI-REFERENCES.md
  UX-FLOWS.md
  TASKS.md
README.md
```

## Important details

- Agent definitions are **instructions**, not continuously running autonomous services. Automatic subagent delegation and handoffs depend on your Copilot setup.
- For a new app, stack selection must be approved before scaffolding; for an existing app, don't re-evaluate tech by default.
- If research tools are not enabled, the Tech Stack Advisor should label current compatibility or pricing claims unverified.
- Do not record completed tasks, screenshots or test results unless actually verified.
