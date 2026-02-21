---
name: acceptance-testing
description: |
  Plan and (when feasible) implement or execute user acceptance tests (UAT) /
  end-to-end acceptance scenarios. Converts requirements or user stories into
  acceptance criteria, test cases, test data, and a sign-off checklist; suggests
  automation (Playwright/Cypress for web, golden/snapshot tests for CLIs/APIs).
  Use when validating user-visible behavior for a release, or mapping
  requirements to acceptance coverage.
license: Apache-2.0
---

# Acceptance Testing

## Overview

You are a user-focused test engineer. Validate behavior from the outside-in and
produce a runnable acceptance test plan (manual and/or automated).

## Inputs (Ask If Missing)

- What “done” means: acceptance criteria, requirement IDs, release goals
- Target interface: UI, CLI, API, library
- Environments available: local, staging, prod-like
- Existing e2e tooling (if any): Playwright/Cypress/Webdriver, test data seeding
- Software Release Definition (SRD): if applicable, for traceability

## Core Principles

1. **Test user outcomes, not internals**.
2. **Small set of high-value scenarios** beats a large brittle suite.
3. **Make setup/data explicit** (no hidden dependencies).
4. **Every failure is reproducible** (pin environment + commit).

## Workflow

### 1) Derive Acceptance Criteria

- For each requirement in scope, write:
  - Positive criteria (what must work)
  - Negative criteria (what must fail safely)
  - Non-functional criteria (error messages, latency, accessibility) when relevant

### SRD Acceptance Criteria Mapping (if applicable)

If a Software Release Definition (SRD) exists, map SRD requirements to acceptance scenarios:

| SRD Requirement | SRD Criterion | Acceptance Scenario | Test Data | Expected Result |
|-----------------|---------------|---------------------|-----------|-----------------|
| SRD-REQ-001 | [Criterion] | AT-001: ... | [Data] | [Result] |
| SRD-REQ-002 | [Criterion] | AT-002: ... | [Data] | [Result] |

**Coverage Check**: All SRD acceptance criteria must have at least one acceptance scenario.

### 2) Write Scenarios

Prefer Gherkin for clarity, but plain checklists are acceptable.

Example (Gherkin):

```gherkin
Scenario: User updates profile successfully (REQ-012)
  Given I am signed in as a standard user
  When I change my display name to "Alex"
  Then I see a success message
  And my profile shows "Alex" after refresh
```

### 3) Choose Execution Mode

- **Manual UAT**: one-off validation or when automation isn’t feasible.
- **Automated E2E**: regression protection for stable workflows.

### 4) Automation Defaults by Stack (Don’t Fight the Repo)

- Web / WASM UI: Playwright/Cypress interaction tests; keep selectors stable.
- Rust CLI tools: golden/snapshot tests (e.g., `insta`) + shell-driven integration tests.
- HTTP APIs: contract tests + integration harness with seeded data.

If the repo already has a tool, extend it; do not introduce a new framework
without justification and approval.

### 5) Produce UAT Plan + Sign-off Checklist

Include ownership, environment details, and how to report bugs.

## UAT Plan Template

```markdown
# UAT Plan: {feature/change}

## Scope
- In scope:
- Out of scope:

## SRD Reference (if applicable)
- SRD ID:
- SRD Version:
- SRD Requirements in scope:

## Environments
- {local/staging/prod-like}
- Test accounts / roles:

## Test Data
- Seeds/fixtures:
- Reset/cleanup:

## SRD Acceptance Criteria Coverage
| SRD Req | Criterion | Scenario | Status |
|---------|-----------|----------|--------|
| SRD-001 | ... | AT-001 | [ ] |

## Scenarios
### AT-001: {title} (maps: REQ-…)
**Preconditions:**
**Steps:**
**Expected:**
**Notes:**

## Demo D15 Reference (if applicable)
- Demo D15 ID: [Demo reference for regulated environments]
- Demo Date: [Scheduled demo date]
- Demo Scenarios: [List of scenarios to be demonstrated]

## Sign-off
- [ ] All “In scope” scenarios executed
- [ ] SRD acceptance criteria covered (if applicable)
- [ ] Demo D15 scenarios verified (if applicable)
- [ ] High/critical bugs resolved or waived (with rationale)
- [ ] Release notes updated (if user-visible)
```

## Bug Report Template

```markdown
**Title:** {short}
**Scenario:** AT-…
**Environment:** {commit, env}
**Steps to reproduce:** …
**Expected:** …
**Actual:** …
**Attachments:** logs/screenshots
```

## ZDP Integration (Optional)

When this skill is used within a ZDP (Zestic AI Development Process) lifecycle, the following additional guidance applies. **This section can be ignored for standalone usage.**

### ZDP Context

Acceptance testing maps to the ZDP **Design** stage (Workflow 3: UAT Strategy) and **Deploy** stage (UAT execution). Test scenarios feed into the LCA and IOC gates.

### Additional Guidance

When working within a ZDP lifecycle:
- Derive UAT scenarios from ZDP business scenarios (map each AT scenario to its source business scenario ID)
- Add a `Business Scenario` column to the UAT Plan Scenarios table: `### AT-001: {title} (maps: REQ-..., BS-...)`
- Align synthetic test data with privacy-preserving requirements from ZDP Workflow 3

### Cross-References

If available, coordinate with:
- `/business-scenario-design` -- source business scenarios for UAT derivation
- `/responsible-ai` -- Responsible-AI acceptance criteria

## Constraints

- Do not mark scenarios as "passed" without stating environment and commit.
- Keep scenarios stable: avoid timing-dependent assertions; delegate pixel diffs
  to `visual-testing`.
