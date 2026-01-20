# Right Side of the V: Verification & Validation

This repo already provides strong “left side of the V” support via:
- `disciplined-research` (Phase 1)
- `disciplined-design` (Phase 2)
- `disciplined-specification` (Phase 2.5)
- `disciplined-implementation` (Phase 3)

It also includes specialist verification skills (`code-review`, `security-audit`,
`rust-performance`, `testing`). The gap was an explicit, disciplined
right-side-of-V workflow that:
1) selects the right gates based on risk,
2) ties evidence back to requirements, and
3) covers UAT and visual regression explicitly.

## Proposed Agent/Skill Design

Treat “agents” as roles, implemented as skills.

| Agent Role | Skill | Primary Output |
|------------|-------|----------------|
| V&V Lead / Quality Gate | `quality-gate` | Quality Gate Report (go/no-go + evidence) |
| Static Analysis Engineer | `ubs-scanner` | Automated bug detection (1000+ patterns) |
| Code Reviewer | `code-review` | Review findings + checklist verification |
| Security Reviewer | `security-audit` | Security findings + remediation |
| Performance Reviewer | `rust-performance` | Benchmarks/profiles + regression risk |
| Traceability Engineer | `requirements-traceability` | Traceability matrix + coverage gaps |
| UAT Engineer | `acceptance-testing` | UAT plan + acceptance scenarios + sign-off |
| Visual QA Engineer | `visual-testing` | Visual regression plan/tests + baseline policy |

## Disciplined Right-Side Flow (After Implementation)

1. Run `quality-gate` on the PR/change.
2. `quality-gate` selects which specialist gates apply (always: review + traceability; conditional: security/perf/UAT/visual).
3. Produce a single Quality Gate Report that links:
   - Requirement IDs → implementation locations → tests → evidence artifacts
4. Only merge/release when blockers are resolved or explicitly waived with rationale.

## Evidence Pack (Recommended)

For any non-trivial change, the goal is to be able to answer:
- “Which requirements did we change?”
- “Where is it implemented?”
- “How do we know it works?”
- “How do we know it’s safe and non-regressing?”

The skills are designed to produce that evidence in a compact, reviewable form
(usually Markdown reports plus logs/screenshots/bench results).
