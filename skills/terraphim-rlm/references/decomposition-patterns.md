# Decomposition Patterns

How to break a too-large task into RLM-tractable subtasks. Patterns are
ordered from simplest to most aggressive.

## Pattern 1: Linear decomposition

For tasks with sequential dependencies (e.g. research, then design, then
review).

```
decompose -> [t1, t2, t3]
for t in tasks: result = rlm_query(prompt=t); store in rlm_context
synthesize from rlm_context
```

Use when each step's output feeds the next.

## Pattern 2: Fan-out then reduce

For tasks with independent subqueries (e.g. analysing many files,
reviewing many concerns).

```python
# inside rlm_code
import asyncio
async def run(t):
    return rlm_query(prompt=t)
tasks = decompose(user_request)
results = await asyncio.gather(*(run(t) for t in tasks))
verdict = rlm_query(prompt=reconcile(results))
```

Use when subtasks are independent. Limits: respect the active backend's
concurrency cap (`rlm_status` reports active executors). Don't fan out
past what the budget supports.

## Pattern 3: Recursive decomposition

When a subtask itself is too large, the `rlm_query` answer can include
"split further" -- detect and recurse, bounded by depth.

```python
def solve(task, depth=0):
    if depth > 3 or fits_in_context(task):
        return rlm_query(prompt=task)
    parts = rlm_query(prompt=f"split into 2-3 subtasks: {task}")
    return reconcile([solve(p, depth+1) for p in parts])
```

Bound depth to avoid runaway recursion. Track depth in `rlm_context` if
recursion spans multiple `rlm_code` calls.

## Pattern 4: Branch-and-merge (Firecracker/Docker only)

Try multiple approaches in isolated state, pick the best.

```
snap = rlm_snapshot()
try approach A: result_a = ...
restore snap
try approach B: result_b = ...
pick winner
```

Fails on Local backend with `RlmError::NotSupported` -- do not attempt
without checking `rlm_status` for backend.

## Parallelism limits

Concurrent `rlm_query` calls per session: check `rlm_status` for active
limits. Typical default is 4-8. Exceeding causes queueing, not failure,
but blows wall-clock budget.

## Capability routing per subtask

Phrase each subtask prompt so the `KeywordRouter` extracts the right
capability:

- Decomposition prompt -> "carefully design how to split..." -> `DeepThinking`/`Architecture`
- Per-subtask execution -> "summarise" / "classify" -> `FastThinking`
- Code subtasks -> "implement a function that..." -> `CodeGeneration`
- Review subtasks -> "audit for security" -> `SecurityAudit`
- Reconciliation -> "reconcile the following verdicts..." -> `DeepThinking`

The router (`crates/terraphim_router/src/keyword.rs`) reads the prompt and
picks the tier from `docs/taxonomy/routing_scenarios/adf/`.
