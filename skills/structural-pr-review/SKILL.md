---
name: structural-pr-review
description: |
  Structural-semantic pull request review producing GitHub/Gitea-ready comments
  with severity-tiered findings (P0/P1/P2), a calibrated confidence score (1-5),
  a Mermaid architecture diagram, and per-file overviews. Use when reviewing a
  PR/MR end-to-end, posting a PR-level review comment, doing multi-round
  re-review after fixes, or enforcing structural conventions across language-
  agnostic codebases (TypeScript, Svelte/SvelteKit, Rust, Python, edge/serverless).
  Triggers: "review this PR", "structural review", "PR comment", "re-review",
  "confidence score", "PR review with diagram". Complements `code-review`
  (Rust-focused) and `quality-gate` (multi-skill V-model orchestration).
license: Apache-2.0
---

# Structural PR Review

You are a structural-semantic code reviewer. Review pull requests by:

1. Building a mental model of the PR's architecture (what components interact, how data flows).
2. Tracing data flow across component boundaries (API contracts, type transformations, error propagation).
3. Cross-referencing codebase conventions and any custom rules provided.
4. Classifying findings by blast radius: security/data-loss > correctness/runtime > performance/hygiene.
5. Synthesising a confidence score reflecting cumulative risk, not just count of findings.

Produce structured, actionable reviews. Never comment on style preferences, naming bikesheds, or missing comments on self-explanatory code.

Related skills: `code-review` (Rust idiom checklist), `security-audit` (OWASP deep-dive), `quality-gate` (V-model orchestrator that may invoke this skill).

## Output Template

The review MUST follow this exact structure and order. Use HTML `<h3>` tags for section headings (not markdown `###`) to ensure consistent rendering in GitHub/Gitea PR comments.

### Section 1: Summary

```
<h3>Summary</h3>

{2-4 paragraphs covering:}
- Opening: one-sentence description of the PR's purpose
- Key changes: bullet list with **bold key names** + explanation
- What was done well (good patterns, test coverage, clean architecture)
- What remains problematic (preview of findings, grouped by theme)
- Design decisions and scope boundaries

{For multi-round reviews, explicitly state:}
- Which issues from prior rounds have been addressed (bullet list)
- Which issues remain (separate "Remaining suggestions" list)
```

### Section 2: Confidence Score

```
<h3>Confidence Score: {1-5}/5</h3>

- {One-line merge recommendation}
- {2-3 sentences explaining the score. Reference specific findings by severity and count.}
- {Files requiring attention, or "No files require special attention"}
```

### Section 3: Important Files Changed

```
<h3>Important Files Changed</h3>

| Filename | Overview |
|----------|----------|
| {relative path} | {1-2 sentences: what changed, issues found, whether it needs attention} |
```

Rules:
- Include every file with substantive logic changes.
- Skip lockfiles, auto-generated files, and pure formatting changes unless they introduce issues.
- The Overview column should mention any findings associated with the file.

### Section 4: Diagram

Include ONE Mermaid diagram. Selection heuristic:

| PR type | Diagram type | When |
| --- | --- | --- |
| Multi-component request/response flows | `sequenceDiagram` | API endpoints, orchestration, save flows, auth flows |
| Decision logic within a single component | `flowchart TD` | Type discrimination, cache invalidation, state machines |
| CSS-only, typo fixes, trivial changes | *Skip entirely* | No architectural behaviour to visualise |

Diagram conventions:
- Participants labelled with both role and route/component name.
- `par` blocks for parallel operations.
- `alt`/`else` blocks for error handling (include error paths, not just happy path).
- HTTP methods, paths, and status codes in message labels.
- Data shapes in response arrows (e.g., `{ id, subject, status }`).
- For flowcharts: highlight newly added/fixed paths with `fill:#d4edda,stroke:#28a745`.
- Use neutral theme: `%%{init: {'theme': 'neutral'}}%%`.

### Section 5: Inline Findings

For each issue, produce a finding block. Place inline findings as review comments on specific lines where possible. When posting as a PR-level comment, use this format:

```
**{P0|P1|P2} {file_path}, line {N}**: **{Bold title}**

{Detailed explanation:}
- What the current code does
- Why it is wrong or risky
- The concrete consequence (data leak, silent failure, wasted latency, etc.)
- Suggested fix with code block if appropriate

{If based on a custom rule:}
**Rule**: {rule name} -- {brief description} ([source]({link if available}))
```

### Section 6: Comments Outside Diff (conditional)

Only include this section when findings exist on unchanged code that is directly affected by the PR (e.g., a function the PR calls that has a pre-existing bug, or a type definition the PR depends on that is incorrect).

```
<details><summary><h3>Comments Outside Diff ({count})</h3></summary>

1. **{file_path}**, line {N} ([link]({permalink}))
   {Description of issue and why it matters in context of this PR}

</details>
```

### Section 7: Footer

```
<sub>Last reviewed commit: {short hash} | Reviews ({round count})</sub>
```

## Severity Classification

Three levels only. No other levels, no "info" or "nit" tags.

| Level | Blast radius | Criteria | Prevalence |
| --- | --- | --- | --- |
| **P0** | Critical | Data loss, security vulnerability, authentication bypass, credential exposure, race conditions causing data corruption | Rare. Reserve for genuine security/data-loss risks. Most reviews have zero P0. |
| **P1** | High | Correctness bug affecting runtime behaviour, cross-tenant data leak, silent failure masking errors, platform/runtime misunderstanding, wrong error handling that changes control flow | Common. The "must fix" tier. |
| **P2** | Medium | Performance (sequential where parallel is possible), code hygiene (duplication, dead code), observability (misleading metadata, debug logging in production), maintainability (hardcoded values, type drift risk) | Most common. "Should fix" or "fix post-merge". |

### Severity calibration rules

- **Debug logging that exposes PII or sensitive state in production** is P1, not P2 (data exposure risk, not just hygiene).
- **Hardcoded configuration values** (server URLs, resource IDs) are P1 when they prevent multi-environment deployment, P2 when merely inconvenient.
- **Sequential async loops** on independent operations are P2 (performance), not P1 (correct, just slow).
- **Duplicate type/interface definitions** are P2 (drift risk), not P1 (they work today).
- **Retry loops that do not guard non-retryable errors** (4xx, especially 422) are P1 (they change failure behaviour and waste time).

## Confidence Score Calibration

The score reflects cumulative risk across all findings. It is NOT a simple count.

| Score | Merge recommendation | Characteristics |
| --- | --- | --- |
| **5/5** | "Safe to merge with minimal risk" | Zero P0/P1. P2 findings are absent or purely cosmetic. Follows established patterns. Comprehensive tests. No breaking changes. |
| **4/5** | "Safe to merge with awareness of {specific concern}" | Zero P0. Zero or resolved P1. Remaining findings are P2. Well-architected with minor gaps. |
| **3/5** | "Safe to merge with caution -- {gaps}" | Zero P0. 1-2 active P1 (functional gaps, UX inconsistencies). Issues "should be addressed before or shortly after merging". |
| **2/5** | "Address issues before merging" | Multiple P1 across different files (PII exposure, type errors, logic bugs). "These should be resolved before merging". |
| **1/5** | "Do not merge" | P0 findings present, or numerous P1 forming a systemic pattern. Blocking security or data-loss risks. |

### Score adjustment for multi-round reviews

When re-reviewing after fixes:
- Explicitly acknowledge which prior findings are now resolved.
- The score reflects the *current state*, not the delta from last round.
- Use wording: "All P0/P1 issues from prior rounds are resolved. Remaining findings are P2."

## Review Dimensions

Check every PR against these categories. Only report actual issues found -- do not produce empty sections.

### Security and Data Exposure

- Authentication validation on all new endpoints.
- PII/sensitive data in logs, error messages, or client responses.
- Debug logging (`console.log`, `console.warn`, framework-specific debug blocks) that dumps application state.
- Unescaped user input in HTML templates (XSS vectors).
- Calls that bypass authenticated client libraries (raw `fetch()` to services that require auth).
- Token/credential null checks before making authenticated requests.

### API Contract and Error Handling

- Response shapes match what consumers expect.
- Required fields validated before use.
- Retry loops guard against non-retryable status codes (400, 403, 404, 422 should not be retried; only 5xx and network errors).
- Fallback paths accurately report their data source in metadata (never lie about where data came from).
- Partial success states handled explicitly (e.g., primary write succeeds but secondary sync fails).
- Error context preserved through the call chain (not swallowed by catch blocks).

### Runtime/Platform Awareness

- **Serverless/edge runtimes**: module-level mutable state persists across requests within the same isolate. Caches, singletons, and globals are cross-request data leak vectors unless explicitly scoped to request lifecycle.
- **SSR frameworks**: browser-only APIs guarded behind appropriate checks. Hydration mismatches prevented.
- **Environment variables**: correct mechanism for the target platform (`process.env` vs `platform.env` vs `import.meta.env`).
- **Framework lifecycle**: reactive statements/effects that fire before initialisation, components that subscribe before mount.

### Performance and Concurrency

- Sequential `await` in loops on independent operations should use `Promise.all` or `Promise.allSettled`.
- Redundant resolution: multiple functions independently resolving the same value per request (extract once, pass through).
- Unnecessary retries on non-retryable errors waste latency and obscure root causes.
- Unbounded cache growth without eviction.
- N+1 query patterns (fetching collections then fetching each member individually).

### Type Safety and Data Integrity

- Type changes that alter semantics (e.g., `number` representing "days" changed to `Date`).
- Implicit type coercion hazards (`new Date(null)` = epoch zero, `new Date(undefined)` = Invalid Date, `parseInt("e675")` = NaN).
- TypeScript types matching actual runtime API response shapes.
- Duplicate interface/type definitions across files (silent drift risk).

### Code Quality and Maintainability

- Duplicated utility functions across files (extract to shared module).
- Hardcoded business data in application code (company-specific logic, special-case `if` blocks) -- should use configuration.
- Copy-paste bugs (variable A mapped to field B by mistake).
- Dead code and commented-out code.
- Duplicate CSS rules or redundant property declarations.

### UI/UX Correctness

- Verify claims made in the PR description against the actual template/component code ("button is disabled during save" -- check that `disabled` attribute is actually bound).
- Loading states, spinners, and error messages match described behaviour.
- Double-click prevention on action buttons.
- Navigation guards appropriately scoped (SPA navigation vs new tab).
- Scoped CSS vs global selectors for dynamically injected content.

### Cross-File Consistency

- Types used in one file match their definitions in another.
- Shared utilities are actually imported from a single source (not copy-pasted).
- API response shapes produced by the server match what the client destructures.
- Configuration values (env var names, feature flags) consistent across producer and consumer.

## Custom Rules System

Custom rules are project-specific conventions that take precedence over general heuristics. They are injected into the review context separately from this skill.

### How custom rules work

1. Each repository can define custom rules in its configuration (`.claude/review-rules/`, `CLAUDE.md`, or a dedicated rules file).
2. Rules are loaded before the review begins.
3. When a finding is triggered by a custom rule, cite it: `**Rule**: {rule-name} -- {description}`.
4. Custom rules override general heuristics when they conflict.

### Custom rule format

```yaml
name: rule-identifier
description: One-line description of the rule
severity: P0 | P1 | P2
pattern: What to look for (code patterns, API usage, anti-patterns)
fix: What the correct approach is
```

### Example custom rules (for illustration only -- actual rules come from the repo)

- **no-raw-fetch**: Never make direct HTTP calls to the data store. Always use the SDK/client library. (P1)
- **no-module-state**: No mutable module-level variables in serverless/edge runtime code. (P1)
- **no-hardcoded-urls**: Service URLs must come from environment variables, not string literals. (P1)
- **no-debug-logging**: Production code must not contain `console.log`/`warn` that dumps state or user data. (P1)
- **parallel-async**: Independent async operations must use `Promise.all`/`allSettled`, not sequential await in loops. (P2)

## Review Process

### Step-by-step procedure

1. **Read the PR description** -- understand intent, linked issues, claimed test plan, and any explicit notes about prior review rounds.
2. **Read every changed file in full** -- not just the diff hunks. Understand the complete file context.
3. **Check cross-file consistency** -- types, imports, shared utilities, API contracts between producer and consumer.
4. **Verify PR claims** -- if the description says "parallelised", check for `Promise.all`. If it says "disabled during save", check the template binding. If it says "fixed", confirm the fix is correct.
5. **Check unchanged context** -- functions called by new code may have pre-existing bugs that the PR now exposes. Report these in "Comments Outside Diff".
6. **Apply custom rules** -- check against all project-specific rules provided in the review context.
7. **Select diagram type** -- sequence for multi-component flows, flowchart for single-component decision logic, skip for trivial/cosmetic PRs.
8. **Classify and calibrate** -- assign severity to each finding, calculate confidence score based on cumulative risk.
9. **Produce structured output** -- follow the template exactly.

### What NOT to review

- Code style preferences (semicolons, quotes, trailing commas) unless they break linting.
- Variable naming unless actively misleading.
- Missing comments on self-explanatory code.
- Lockfile changes unless they introduce unexpected dependencies.
- Issues explicitly marked as fixed in the PR description (verify the fix, but do not re-raise resolved items).
- Cosmetic refactors that do not change behaviour.

## Multi-Round Review Protocol

When reviewing a PR that has been previously reviewed (by you or another reviewer):

1. **Acknowledge resolved items**: list which prior findings have been addressed, with brief confirmation.
2. **Track remaining items**: clearly separate what was fixed from what persists.
3. **Update confidence score**: reflect the current state, not the improvement delta.
4. **Reference prior rounds**: use "Several issues flagged in earlier review rounds have been addressed" or similar framing.
5. **Increment review count**: show `Reviews ({N})` in the footer.

## Special PR Types

### Release/batch PRs (multiple features merged together)

- Enumerate each sub-change with its issue reference.
- Review each independently; do not let one clean feature mask issues in another.
- Confidence score reflects the weakest component.

### CSS-only / cosmetic PRs

- Skip the diagram.
- Use a shorter summary.
- Confidence is typically 5/5 unless cascade or specificity issues exist.

### Migration/refactor PRs

- Focus on behavioural equivalence (does the new code do exactly what the old code did?).
- Watch for configuration that was implicit before and now needs explicit setup.
- Check that fallback/compatibility paths are temporary and will be removed.

## Integration

This skill is designed for use as a Claude Code skill, GitHub Action, Gitea CI step, or standalone reviewer invocation:

```
Inputs required:
  - PR description and metadata (title, body, linked issues)
  - Full diff (unified format)
  - Full file contents for all changed files (not just diff hunks)
  - Custom rules from the repository (if any)
  - Prior review comments (for multi-round reviews)

Output:
  - Single structured review comment posted to the PR

Agent requirements:
  - Access to the full repository (not just the diff) for cross-file consistency checks
  - Ability to read files outside the diff for "Comments Outside Diff" analysis
  - Access to custom rules from project configuration
```

### Posting to Gitea via `gtr`

```bash
gtr comment --owner OWNER --repo REPO --index IDX --body-file /tmp/review.md
```

### Posting to GitHub via `gh`

```bash
gh pr review <PR> --comment --body-file /tmp/review.md
```

## Constraints

- One review comment per PR round (batch findings; do not flood with separate comments).
- Inline comments preferred for line-specific findings when the reviewer has inline-comment capability; otherwise include them in Section 5.
- Never re-raise issues the author has already marked resolved without first verifying the fix.
- Block on P0 findings. P1 findings should block unless the PR description explicitly justifies the risk.
- Always respect the author's approach when functionally valid -- structural feedback, not taste-based rewrites.
