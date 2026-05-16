# Budget Defaults

`terraphim_rlm` sessions carry a dual budget: tokens and wall-clock time.
Defaults are set by the crate's `BudgetConfig` and can be overridden
per-session.

## Reading the budget

```
rlm_status
```

Returns at minimum: `tokens_remaining`, `tokens_consumed`, `time_remaining_ms`,
plus active VMs/containers and recent tool calls.

## Default thresholds

- **20% remaining**: surface a warning to the user; ask whether to continue,
  raise the budget, or descope.
- **5% remaining**: stop spawning new subtasks; finish in-flight work and
  return.
- **Exhausted**: subsequent `rlm_query` calls fail. Do not catch and retry;
  surface to the user.

## Setting budgets per session

Budget is set when the session is created (outside the skill's scope --
either by config or by the application that initialised the RLM). If the
user needs more headroom, they re-create the session with a larger budget.

## Why dual budget

- Token budget alone misses runaway loops in `rlm_code` that consume
  wall-clock without consuming LLM tokens
- Time budget alone misses LLM-heavy decomposition that fits in the time
  window but blows the spend cap

Both bound the blast radius of a misbehaving recursion.
