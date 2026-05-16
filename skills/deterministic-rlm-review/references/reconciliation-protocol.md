# Reconciliation Protocol

How to merge the verdicts from multiple reviewer roles into one ranked
report without losing the disagreements that matter.

## Inputs

For each reviewer role, you have a verdict stored in `rlm_context` under
keys like `verdict.security`, `verdict.performance`. Each verdict is a
list of findings; each finding has at least: file, line, severity,
description.

## Step 1: Group by location

Build a map `(file, line-range) -> [findings...]`. Findings at the same
location across roles are candidates for either reinforcement (multiple
roles flag the same thing) or conflict (roles disagree on what to do).

## Step 2: Classify each group

For each location group:

- **Reinforced**: two or more roles flag the same issue. Increase
  severity by one tier (P2 -> P1, P1 -> P0). Cite all roles.
- **Independent**: only one role flags it. Keep the original severity.
- **Conflict**: roles propose incompatible actions (e.g. security says
  "add validation", performance says "this validation is the hot path").
  Surface the conflict in the report; do not silently resolve.

## Step 3: Draft resolution proposals for conflicts

For each conflict, propose a resolution that respects both concerns:

```
Conflict at src/foo.rs:42-58
- security: input must be validated before processing
- performance: validation is the hot path (~30% of CPU)
Proposed resolution: validate once at the API boundary, cache the
validated form, skip re-validation on the hot path.
```

If you cannot find a resolution that respects both, say so explicitly and
ask the user to choose.

## Step 4: Rank into P0/P1/P2

- **P0 (block merge)**: correctness or security findings with concrete
  evidence; reinforced findings that escalated to P0
- **P1 (fix before merge)**: real issues, lower severity; unresolved
  conflicts that affect correctness or security
- **P2 (follow-up)**: nits, suggestions, performance micro-optimisations

## Step 5: Confidence score (1-5)

State the basis. Examples:

- **5**: full diff reviewed, all reviewer roles ran successfully, tests
  also read, no unresolved conflicts, prior decisions consulted via KG
- **3**: full diff reviewed but tests not read, one reviewer role
  unresolved, project context partial
- **1**: only a subset of files reviewed, multiple reviewer failures, no
  KG context pulled

Confidence under 3 should be flagged to the user before the report is
considered actionable.

## Step 6: Format the report

```
# Review: {change description}

Confidence: {N}/5 -- {basis}

## P0 (block merge)
- {file}:{line} -- {finding} [{roles that flagged}]

## P1 (fix before merge)
- ...

## P2 (follow-up)
- ...

## Unresolved conflicts
- {location} -- {description, proposed resolution, ask user}
```

Then either show this to the user (default) or post via `gtr comment` if
they explicitly want it on the PR.
