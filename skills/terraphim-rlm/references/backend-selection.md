# Backend Selection

The `terraphim_rlm` crate ships three execution backends. The active one is
chosen at crate build time via Cargo features (`firecracker-backend`,
`docker-backend`, default Local) and at runtime via configuration.

## Capability matrix

| Capability | Local | Docker | Firecracker |
|---|---|---|---|
| Run Python | Yes | Yes | Yes |
| Run bash | Yes | Yes | Yes |
| Honour `timeout_ms` | Yes (Refs #870) | Yes | Yes |
| `kill_on_drop` reap | Yes (Refs #870) | Yes | Yes |
| Per-session state | No | Yes (container) | Yes (VM) |
| Snapshots | `NotSupported` | Limited (restart only) | Full state versioning |
| Isolation strength | Process only | Container | Hardware-virtualised |
| Linux required | No | No | Yes |
| Network policy | Host network | Configurable | Configurable |

## When to pick which

- **Local** (default on Mac, fully supported for non-snapshot work):
  development, fast iteration, in-session sandboxed scripts, decomposition,
  KG-grounded sub-queries, fan-out + reconcile. Process-level isolation
  with timeout enforcement and kill_on_drop reaping. Cheapest. The only
  capability missing is `rlm_snapshot` -- if a task does not need
  branching, Local is the right pick.
- **Docker**: portable across Mac and Linux. Stronger isolation than
  Local. Good for client-facing demos or moderately untrusted input.
  Snapshots are container-restart only, not arbitrary state versioning.
- **Firecracker**: bigbox, overnight ADF agents, anything touching
  arbitrary user-supplied code. Full VM state versioning. Required for
  branch-and-merge patterns (`rlm_snapshot` + restore).

## Backend discovery

Call `rlm_status`. The response includes the active backend name. Make
backend-dependent decisions (snapshot vs. linear, parallelism limits) from
the live status response, not from assumptions.

## Snapshot honesty (Refs terraphim-ai #870)

Before PR #870, LocalExecutor fabricated a SnapshotId for snapshot
operations that did nothing. As of v2026.05.16, LocalExecutor returns
`RlmError::NotSupported`. Treat this as a clear signal: do not retry; redesign.
