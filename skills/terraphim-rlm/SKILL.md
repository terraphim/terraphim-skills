---
name: terraphim-rlm
description: |
  Use this skill to delegate any in-session task that needs RLM (Recursive
  Language Model) orchestration: decomposing a multi-file or whole-codebase
  task that would otherwise blow the context window, running budget-bounded
  recursive LLM calls (outer model plans, sub-calls execute), sandboxed
  Python or bash execution with deterministic isolation, fan-out plus
  reconcile patterns across many subtasks, branching exploration via
  snapshots. ALWAYS trigger this skill when the user says any of: "/rlm",
  "use RLM", "decompose with RLM", "RLM swarm", "spawn a sandbox",
  "terraphim_rlm", "rlm_code", "rlm_query", "rlm_bash", "recursive language
  model", "recursive LLM", "budget-tracked decomposition", "fan-out
  reviewers", "process this codebase in chunks", "I keep blowing the
  context window", or whenever they describe a task with more than about
  five interdependent steps over many files. Wraps the rlm_code, rlm_bash,
  rlm_query, rlm_context, rlm_snapshot, and rlm_status MCP tools from the
  terraphim_rlm crate, with capability-based routing via terraphim_router.
  Do NOT use for one-shot edits (call Edit/Read/Bash directly), PR review
  (prefer code-review or structural-pr-review), personal notes lookup
  (prefer local-knowledge), or out-of-session overnight agent dispatch
  (prefer adf-orchestrate).
license: Apache-2.0
---

# Terraphim RLM

## When to use this skill

Pick this skill when at least one is true:

- The task is long-horizon (more than a handful of dependent steps) and
  would benefit from external state rather than chat context
- The user needs sandboxed code or shell execution they can audit
- A subtask needs its own LLM call with its own budget (recursive
  decomposition)
- The task touches a large codebase or dataset that will not fit in one
  context window

Skip this skill when:

- The task is a one-shot edit or simple question -- use Edit, Read, or Bash
  directly
- The user is doing PR review -- prefer `code-review` or
  `structural-pr-review`
- The user is searching personal notes -- prefer `local-knowledge`
- The user wants overnight or background work -- prefer `adf-orchestrate`

## Why this exists

Treating the model's context as a fixed window leads to context rot on long
tasks: earlier work gets summarised badly, instructions drift, and costs
scale quadratically with conversation length. RLM externalises state into a
sandboxed execution environment with an explicit budget, so the model can
decompose, recurse over subproblems, and aggregate results without
forgetting earlier steps or paying for repeated context.

## Prerequisites

The `terraphim_rlm` MCP server must be registered with this Claude Code
session. Verify with a single `rlm_status` call. If the tool is unavailable,
ask the user to register the server (see terraphim-ai QUICKSTART.md). Do not
proceed assuming the tool exists.

## Available MCP tools

| Tool | Purpose |
|---|---|
| `rlm_code` | Run Python in an isolated executor. Returns stdout/stderr/exit. Honours `timeout_ms`. |
| `rlm_bash` | Run bash in an isolated executor. KG-validated before execution. Honours `timeout_ms` and `working_dir`. |
| `rlm_query` | Recursive LLM call inside the session. Consumes from the session budget. |
| `rlm_context` | Get/set named variables persisted in the session. |
| `rlm_snapshot` | Snapshot or restore executor state for branching. Backend-conditional -- see "Backend selection". |
| `rlm_status` | Inspect budget, active executors, recent calls. |

Call `rlm_status` at the start of the task and after every roughly five
tool calls. Surface the real numbers to the user; never fabricate a status
line. The status tool is the source of truth.

## Backend selection

The crate ships three execution backends, all first-class. Pick based on
what the user has available -- the `rlm_status` response includes the
active backend.

| Backend | rlm_code / rlm_bash / rlm_query | Snapshots | Notes |
|---|---|---|---|
| Local | Fully supported | Not supported | Default on Mac. Process-level isolation. Honours `timeout_ms` and `kill_on_drop` (Refs terraphim-ai #870). |
| Docker | Fully supported | Limited (container restart) | Portable across Mac and Linux. Stronger isolation than Local. |
| Firecracker | Fully supported | Full VM state versioning | Linux only. Strongest isolation. Default on bigbox. |

Local is fine for the vast majority of in-session work -- decomposition,
fan-out, KG-grounded sub-queries, sandboxed scripts. Only escalate to
Docker/Firecracker when the task genuinely needs branching (snapshots),
stronger isolation (untrusted code), or a Linux-only dependency.

If `rlm_snapshot` is called on Local it returns `RlmError::NotSupported`
honestly -- do not retry; restructure the task to be linear, or ask the
user whether to switch backend.

Details: see `references/backend-selection.md`.

## Capability-based routing -- do not hardcode models

Terraphim ships a capability-based router (`terraphim_router`) that picks
the right model for a task based on its *capability* requirements, not a
hardcoded model name. Passing a `model` parameter to `rlm_query` bypasses
the router and locks the skill to a model that may not exist in the user's
environment.

### Frame `rlm_query` calls by capability, not model

Capabilities are defined in the `Capability` enum
(`crates/terraphim_types/src/capability.rs`):

| Capability | Use when the subtask is... |
|---|---|
| `DeepThinking` | Decomposition, reconciliation, architecture decisions |
| `FastThinking` | Classification, summarisation, simple lookups |
| `CodeGeneration` | Writing a script or function |
| `CodeReview` | Reviewing a diff |
| `Architecture` | System design, ADR drafting |
| `Testing` | Generating test cases |
| `Refactoring` | Mechanical code transforms |
| `Documentation` | Drafting README/rustdoc/markdown |
| `Explanation` | Teaching the user something |
| `SecurityAudit` | Looking for vulnerabilities |
| `Performance` | Optimisation analysis |

Phrase the prompt so the `KeywordRouter` extracts the right capability
(e.g. "carefully design", "implement", "audit for security"). The router
then selects a provider from the tier docs at
`docs/taxonomy/routing_scenarios/adf/{planning,implementation,review}_tier.md`
using the `CostOptimized` strategy. Leave the `model` parameter unset
unless the user has explicitly pinned one.

### Tiers cover capabilities

- Planning tier: `DeepThinking`, `Architecture`
- Implementation tier: `CodeGeneration`, `Refactoring`, `Testing`
- Review tier: `CodeReview`, `SecurityAudit`, `Performance`

A typical swarm spans tiers: planning to decompose, implementation or
review to execute each subtask, planning to reconcile.

## Code as orchestration substrate

The Python sandbox accessed via `rlm_code` can call back into `rlm_query`
and `rlm_bash` through the MCP bridge. This means a single Python script
inside the executor can orchestrate dozens of LLM sub-calls
deterministically -- loops, conditionals, retries, aggregation -- using
code as the control-flow language rather than chained chat prompts.

Use this when the orchestration logic is non-trivial (more than about five
branches, or requires programmatic aggregation, or needs to be replayable).
Example pattern:

```python
# inside rlm_code
tasks = decompose(user_request)               # uses rlm_query with DeepThinking
results = [rlm_query(prompt=focused(t)) for t in tasks]  # FastThinking tier
verdict = rlm_query(prompt=reconcile(results))           # back to DeepThinking
write_context("verdict", verdict)
```

See `references/decomposition-patterns.md` for parallelism guidance and
common patterns.

## Decomposition pattern

For a task that smells too large for one window:

1. Call `rlm_status` -- note budget, backend.
2. Before spawning subtasks, run
   `terraphim-agent learn query "<task keywords>"` to surface prior failed
   attempts; avoid known dead-ends.
3. Pull KG context:
   `terraphim-agent search --role <role> --robot --format json "<query>"`.
   Read the `concepts_matched` field to know which KG concepts grounded
   each hit; pass relevant snippets into subsequent `rlm_query` prompts.
4. Decompose into 2-5 named subtasks; store the plan via `rlm_context`.
5. For each subtask, choose: run inline OR `rlm_query` with a focused
   sub-prompt OR `rlm_code` for programmatic computation. Set
   `timeout_ms` explicitly -- do not rely on defaults.
6. Write each subtask result back to `rlm_context` under a stable key.
7. Aggregate from `rlm_context`. If a subtask failed, retry once with a
   tighter prompt or split further. If budget drops below 20%, surface a
   warning to the user before continuing.

Detailed heuristics: `references/decomposition-patterns.md`.

## Budgets

Default token budget is set by the crate; treat it as a hard ceiling. If
you project an overrun, stop and ask the user to either raise the budget
or descope, rather than silently truncating. Budget tuning:
`references/budget-defaults.md`.

## Failure handling

If a tool call fails:

- Read the error from the tool result; do not guess
- For transient errors (timeout, OOM), retry once with reduced input or
  a higher `timeout_ms`
- For deterministic errors (syntax, missing dependency), fix and retry
- After two failures on the same subtask, surface to the user with full
  error context -- do not silently move on

LocalExecutor honours `timeout_ms` and uses `kill_on_drop`, so timed-out
processes are reaped rather than leaked (Refs terraphim-ai #870).

## CLI-first principle

Prefer existing Terraphim CLIs over reinvention from inside the sandbox:

- KG context: `terraphim-agent search --role <role> --robot --format json`
- Past failures: `terraphim-agent learn query "<pattern>"`
- Gitea issues (every commit must reference one): `gtr ready --owner O --repo R`

Use `--robot --format json` whenever output will be parsed.

## End-of-session

When the task is complete, call `rlm_status` once more and report to the
user: budget consumed, subtasks completed, leftover state worth inspecting.
If the work produced artefacts that should survive the session (research
findings, distilled concepts), consider invoking the `kg-rlm-ingest` skill
to persist them to the knowledge graph.
