# RLM Skills Launch — Design and Evaluation Notes

**Date**: 2026-05-16
**Status**: shipped (PR https://git.terraphim.cloud/terraphim/terraphim-skills/pulls/11 merged)
**Parent issue**: https://git.terraphim.cloud/terraphim/terraphim-skills/issues/10

This document records the design choices, eval methodology, and cross-CLI E2E results for the four native RLM skills added in PR #11. Read it before extending or troubleshooting the skills.

## What landed

Four skills wrapping shipped Terraphim primitives:

| Skill | Wraps | Trigger context |
|---|---|---|
| `terraphim-rlm` | `rlm_code`, `rlm_bash`, `rlm_query`, `rlm_context`, `rlm_snapshot`, `rlm_status` MCP tools | In-session sandboxed execution + recursion + budget tracking |
| `adf-orchestrate` | `adf-ctl trigger/status/cancel/agents` CLI | Out-of-session bigbox dispatch via HMAC-signed webhook |
| `kg-rlm-ingest` | `rlm_query` + `terraphim-agent search --robot` + Write to haystack | Persist research output to role-scoped KG |
| `deterministic-rlm-review` | `rlm_query` orchestration with reviewer roles + reconciliation | Multi-perspective adversarial review of large/security-critical changes |

Plus 12 fixture YAMLs (positive/negative/boundary per skill), runnable Python swarm demo, and skill-creator trigger eval sets.

## Design principles

1. **CLI-first**: every skill leverages existing CLIs (`terraphim-agent`, `adf-ctl`, `gtr`) and shipped MCP tools. No invented commands.

2. **Capability-based routing, no hardcoded models**: skill prompts use `Capability` enum keywords (DeepThinking, FastThinking, CodeGeneration, SecurityAudit, Performance, etc.) so `terraphim_router` picks the model from tier docs at `docs/taxonomy/routing_scenarios/adf/{planning,implementation,review}_tier.md`. Tier docs are the single source of truth.

3. **Three first-class backends**: Local (default on Mac), Docker, Firecracker. Local is fully supported for `rlm_code`/`rlm_bash`/`rlm_query`/`rlm_context`/`rlm_status`; only `rlm_snapshot` returns `NotSupported` (Refs terraphim-ai PR #870).

4. **Disambiguation against neighbours**: each description explicitly states when to use it over `code-review`, `local-knowledge`, `session-search`, `quality-gate`, `structural-pr-review`. Negatives 8/8 perfect in live eval.

5. **Exact invocations near the top**: after a haiku regression invented `adf-ctl agent start --overnight`, we added an "Exact invocation -- do not invent subcommands" section at the top of `adf-orchestrate/SKILL.md` listing the four canonical commands and explicit anti-list.

## Eval methodology

### Live eval (`scripts/run-skill-evals.ts`)

YAML fixtures with `trigger_signals.{all_of,any_of,none_of}` patterns. Negatives use `none_of` (must NOT appear in vanilla Claude's response); positives/boundaries use `all_of` Terraphim-specific anchors (`rlm_status`, `adf-ctl trigger`, `terraphim-agent search`, `rlm_query`).

**v1 baseline** (loose patterns): negatives 4/4, positives passed via word-echo (false confidence).
**v2 baseline** (tightened patterns): negatives **8/8 perfect**; positives correctly fail at the `all_of` gate because the runner spawns `claude -p` without installing the candidate skill.

### Trigger eval (`skill-creator run_loop.py`)

20-query eval per skill, 60/40 train/test split, Opus model, 3 iterations.

| Skill | Test pass | Precision | Recall |
|---|---|---|---|
| terraphim-rlm (v2 description) | 9/14 (64%) | 100% | 17% |
| adf-orchestrate | 8/14 (57%) | 100% | 0% |
| kg-rlm-ingest | 9/14 (64%) | 100% | 17% |
| deterministic-rlm-review | 4/7 (57%) | n/a | n/a |

**Same structural limitation as live eval**: run_loop doesn't install the candidate skill. Near-100% precision proves descriptions disambiguate cleanly; low recall reflects the install gap, not description quality.

### E2E (cross-CLI)

Real proof of triggering requires installing skills via `npx skills add terraphim/terraphim-skills` and running prompts interactively.

**Claude (Opus, with skills installed):** all 4 skills triggered correctly with skill-aware behaviour.
- `terraphim-rlm`: called `rlm_status` first, used `cargo metadata` for cycle detection, proposed fan-out for summaries only
- `adf-orchestrate`: identified correct `adf-ctl trigger` syntax, asked for Gitea repo ref, respected "never implement on bigbox directly" north-star rule
- `kg-rlm-ingest`: refused to fabricate KG content, suggested `terraphim-agent sessions search` from CLAUDE.md guidance
- `deterministic-rlm-review`: refused to fake review of unread code -- *"a confidence score on unread code would be theatre"*

**Opencode (claude-haiku-4-5, with skills installed):** all 4 prompts produced skill-aware output. `kg-rlm-ingest` explicitly logged `→ Skill "terraphim-rlm"`. Initial haiku regression on `adf-orchestrate` (invented `adf-ctl agent start --overnight`) fixed by adding "Exact invocation" section at top of skill body.

**Opencode (kimi-for-coding/k2p6 + k2p5):** `opencode run` hangs in batch mode -- 0 bytes after 5-25 minutes for both `--format default` and `--format json`. Process alive, output never flushed. Same issue with K2P5. This is an **opencode bug**, not a skill bug -- works fine with claude-haiku-4-5. Workaround for future Kimi E2E: interactive TUI or `opencode acp`/`serve` mode.

## Distribution

Install via:

```bash
npx skills add terraphim/terraphim-skills -g
```

Or for development from a local checkout:

```bash
npx skills add /Users/alex/projects/terraphim/terraphim-skills -g -y
```

Skills land in `~/.agents/skills/<name>/` with symlinks into Claude Code, OpenCode, Cline, Codex, Warp, etc.

## Follow-ups (filed on terraphim-ai)

- **#1495** `adf-ctl: add --format json to status + agents subcommands for adf-orchestrate skill parseability` (priority: low)
- **#1496** `Ingest canonical RLM + ADF terminology into ADFAuthor KG haystack` (priority: medium) -- dogfoods `kg-rlm-ingest` to lift terraphim-agent adapter eval recall

## 2026-05-18: LLM Bridge wired

The `rlm_query` stub in `terraphim_rlm::LlmBridge` has been replaced with
real LLM delegation through the orchestrator's routing pipeline (Refs
terraphim-ai PR #880, issue #1744).

- `LlmBridge::query()` now delegates to `terraphim_service::llm::LlmClient`
  when configured, or returns `RlmError::LlmNotConfigured` without one.
- The orchestrator injects the client via `TerraphimRlm::set_llm_client()`,
  reusing its existing provider health, budget tracking, and fallback
  routing (Ollama free local → OpenRouter cheap cloud → proxy).
- All three RLM skills (`terraphim-rlm`, `deterministic-rlm-review`,
  `kg-rlm-ingest`) updated with LLM configuration prerequisite sections.

## References

- terraphim-ai v2026.05.16
  - PR #870 -- LocalExecutor honours `timeout_ms`, `kill_on_drop`, snapshot returns `NotSupported`
  - PR #1485 -- `DockerExecutor` for container isolation
  - PR #1486 -- `concepts_matched` in robot-mode search envelope
  - Refs #945 (commit `bf1b7f11c`) -- thesaurus cache flushes after KG markdown edits
- This repo
  - PR #11 -- the four skills
  - Eval baselines in `evals/reports/*-v2.json`
  - Trigger eval sets in `evals/trigger-eval-sets/`
  - Runnable demo in `examples/swarm-demo/`
