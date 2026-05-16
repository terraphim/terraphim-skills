# Swarm Demo

Demonstrates the `terraphim-rlm` skill in action: a single Python script,
invoked via `rlm_code`, that orchestrates roughly ten parallel sub-queries
over the knowledge graph using capability-based routing.

## What it shows

- `rlm_code` as orchestration substrate (code is the control-flow language)
- Capability-routed `rlm_query` calls -- no hardcoded models
- Fan-out + reconcile pattern from `decomposition-patterns.md`
- Reading `concepts_matched` from `terraphim-agent search --robot`
- Honest budget checks via `rlm_status`

## How to run

1. Ensure the `terraphim_rlm` MCP server is registered with your Claude
   Code session (see terraphim-ai `QUICKSTART.md`).
2. From a session with the `terraphim-rlm` skill active, hand the file
   `swarm.py` to the model and ask:

   > Run the swarm demo against the role "Rust Engineer" with the query
   > "async cancellation patterns".

3. The model should call `rlm_code` with the contents of `swarm.py` and
   the two parameters, then report the reconciled output and budget
   consumed.

## Expected behaviour

- One `rlm_status` call at the start
- One `terraphim-agent search --robot --format json` to seed the query list
- About 8-10 parallel `rlm_query` calls inside the sandbox
- One `rlm_query` for reconciliation
- One `rlm_status` call at the end with delta reported to the user

## Why this is a useful eval

It exercises every load-bearing claim in the skill:
- "Code as orchestration substrate"
- "Capability-based routing"
- "Decomposition pattern -> fan-out + reduce"
- "End-of-session budget reporting"

If the model hardcodes a model name, the eval fails. If it forgets
`rlm_status`, the eval fails. If it tries `rlm_snapshot` on a Local
backend, the eval fails.
