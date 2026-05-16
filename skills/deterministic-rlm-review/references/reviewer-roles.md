# Reviewer Roles

Each reviewer is a single `rlm_query` call with a prompt phrased to
trigger a specific `Capability`. The router picks the provider; the
prompt focuses the model on one concern.

## Standard roles

### Security (`SecurityAudit`)

```
Audit the following diff for security vulnerabilities. Cover: input
validation, authentication, authorisation, secrets handling, injection
(SQL, command, path), OWASP-top-10-relevant categories. Cite the file
and line for every finding. For each finding, state: severity (P0/P1/P2),
the attack vector, and a minimal fix sketch.

Project context: {ADRs and lessons-learned snippets from KG}

Diff:
{git diff output}
```

### Correctness (`CodeReview`)

```
Review the following diff for correctness. Cover: invariants, error
paths, edge cases, off-by-one, race conditions, lifetime issues.
List edge cases not handled and propose a minimal test for each.

Project context: {ADRs}

Diff:
{git diff output}
```

### Performance (`Performance`)

```
Analyse the following diff for performance. Cover: hot paths, allocation
patterns, async correctness, lock contention, complexity. Cite file and
line for each finding; suggest a measurement to confirm impact.

Project context: {prior benchmarks if available}

Diff:
{git diff output}
```

### API design (`Architecture`)

```
Evaluate the API design in the following diff. Cover: breaking changes,
ergonomics, naming, type-level guarantees, alignment with project
conventions in {project context}.

Diff:
{git diff output}
```

## Optional domain roles

Add only when the change warrants it. Each costs budget and increases
reconciliation effort.

| Role | Capability | When to add |
|---|---|---|
| Concurrency | `CodeReview` + "concurrency" keyword | Touches Mutex/Arc/async primitives |
| WASM | `CodeReview` + "wasm compatibility" | Touches code compiled to wasm32 |
| KG schema | `Architecture` + "knowledge graph schema" | Touches haystack or thesaurus format |
| Migration safety | `CodeReview` + "migration backwards-compatibility" | DB migrations or wire-format changes |

## Why phrase by capability

Hardcoding "use Opus for security review" rots the moment a tier doc is
updated. Phrasing by capability (`SecurityAudit`) means the router picks
the best available model in the user's environment today, and tomorrow,
without skill changes. The tier docs at
`docs/taxonomy/routing_scenarios/adf/` are the single source of truth for
which model serves which capability.
