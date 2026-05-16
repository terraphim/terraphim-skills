---
name: deterministic-rlm-review
description: |
  Multi-perspective code review using an RLM swarm -- spawns specialised
  reviewer sub-queries (security, performance, correctness, API design)
  via capability-routed rlm_query calls, then reconciles findings into a
  single ranked report with P0/P1/P2 severity and a confidence score. Use
  when the change spans many files (rough threshold: more than five files
  or five hundred lines), touches security-critical code, or the user
  explicitly asks for an "adversarial", "swarm", or "multi-perspective"
  review. Prefer `code-review` for routine single-file review; prefer
  `structural-pr-review` for PR-shaped review with diagrams; prefer
  `quality-gate` for full pre-merge V-model evidence.
license: Apache-2.0
---

# Deterministic RLM Review

## When to use vs neighbours

| Situation | Use |
|---|---|
| Single file, single concern | `code-review` |
| PR with multiple files needing a structured PR comment | `structural-pr-review` |
| Pre-merge gate with verification plus validation evidence | `quality-gate` |
| Large multi-file change OR security-critical OR user wants adversarial perspectives | **this skill** |

If two could apply, prefer the more specific one. This skill exists for
cases the others would handle poorly because a single review pass cannot
hold enough context for all the relevant concerns.

## Why

A single review pass at large scale either truncates context or produces
shallow comments. Spawning role-bounded sub-reviewers gives each one the
full context for its concern, and explicit reconciliation surfaces
conflicts the model would otherwise paper over (e.g. security says "lock
this down", performance says "this lock is the bottleneck").

## Reviewer roles

Standard set (see `references/reviewer-roles.md`):

| Role | Capability triggered |
|---|---|
| Security | `SecurityAudit` |
| Correctness | `CodeReview` |
| Performance | `Performance` |
| API design | `Architecture` |

Add domain-specific roles when the change warrants it (e.g. concurrency,
WASM compatibility, KG schema). Do not run more than about six roles for
one change -- diminishing returns and exploding wall-clock budget.

Phrase each reviewer prompt so the `KeywordRouter` picks the right tier:

- "audit the following diff for security vulnerabilities..." -> `SecurityAudit` -> review tier
- "review for correctness, list edge cases not handled..." -> `CodeReview` -> review tier
- "analyse hot paths and allocation patterns..." -> `Performance` -> review tier
- "evaluate the API design for breaking changes and ergonomics..." -> `Architecture` -> planning tier

Do not pass a `model` parameter to `rlm_query` -- the router selects from
`docs/taxonomy/routing_scenarios/adf/{review,planning}_tier.md` based on
the capability.

## Procedure

1. **Pull change + project context**: run `git diff` for the change. Pull
   prior decisions:

   ```
   terraphim-agent search --role "Rust Engineer" --robot --format json \
     "<keywords from changed files>"
   ```

   Read the `concepts_matched` field; pass relevant ADRs and
   lessons-learned snippets into each reviewer-role prompt so the swarm
   reviews against the project's actual conventions, not generic best
   practice.

2. **Spawn reviewers**: for each role, call `rlm_query` with the
   capability-phrased prompt scoped to the relevant files plus the
   pulled-in project context. Store each verdict in `rlm_context` under
   a stable key (e.g. `verdict.security`, `verdict.performance`).

3. **Reconcile**: read all verdicts. For each pair of verdicts, look for
   conflicts. For each conflict, draft a resolution proposal and surface
   it to the user. Do not silently collapse a conflict; the conflict
   itself is information.

   Detailed protocol: `references/reconciliation-protocol.md`.

4. **Produce a single ranked report**:

   - **P0 (block merge)**: correctness or security findings with evidence
   - **P1 (fix before merge)**: real issues, lower severity
   - **P2 (follow-up)**: nits and suggestions

5. **Confidence score (1-5)**: state the basis. Lower confidence when
   coverage is incomplete (e.g. tests not read), conflicts unresolved, or
   the change touches unfamiliar territory.

6. **Close the loop**: if reviewing a PR, post the report via
   `gtr comment --owner O --repo R --index <PR-IDX>`. If the report
   reveals work for another issue, file it via `gtr create-issue`.

## Anti-patterns

- Running more than six reviewer roles for one change
- Suppressing a P0 to keep a "clean" report
- Claiming consensus where there was conflict -- surface it
- Passing a `model` parameter and bypassing the router
- Reviewing without project context (becomes generic-best-practice review)
- Posting the report to Gitea before showing the user

## CLI-first principle

- KG context: `terraphim-agent search --robot --format json`
- Diff: `git diff`
- LLM calls: `rlm_query` with capability-phrased prompts
- State: `rlm_context`
- Report posting: `gtr comment`
