# Judge System Architecture: Four-Eyes Content Quality for AI Agents

**Status**: Phase A (Advisory) in production; Phase B (Blocking) pending calibration
**Date**: 2026-02-21
**Repo**: terraphim/terraphim-skills
**Related issues**: #17 (Epic), #18-#23 (Phases 1-5 + Validation)

---

## Problem Statement

Autonomous AI agents contributing to knowledge repositories create a governance gap: every unreviewed commit is a latent trust erosion. Manual review of all agent outputs does not scale. Binary pass/fail gates are too coarse to produce actionable improvement signals.

The judge system implements the **Four-Eyes Principle** adapted from financial controls: the LLM that authors content must never be the LLM that judges it.

## System Overview

Three deployment phases, each building on the previous:

| Phase | Trigger | Models | Behaviour | Status |
|-------|---------|--------|-----------|--------|
| **A: Advisory** | git pre-push | Single (Cerebras llama-3.3-70b) | Logs verdicts, always exit 0 | Production since 2026-02-15 |
| **B: Blocking** | git pre-push | Single (same as A) | exit 1 on NO-GO verdicts | Pending KPI validation |
| **C: Task-Boundary** | Task completion | 3-tier (gpt-5-nano / kimi-k2.5-free / gpt-5.1-codex-mini) | Multi-iteration with improvement loop | Implemented, not deployed |

---

## Rubric: Three KLS Dimensions

All phases share the same rubric derived from the KLS (Krogstie-Lindland-Sindre) quality framework:

| Dimension | Question | Criteria |
|-----------|----------|----------|
| **Semantic** (S) | Does it accurately represent the domain? | Factual correctness, domain terminology, no contradictions |
| **Pragmatic** (P) | Does it enable the intended decisions/actions? | Actionable, useful, addresses the task goal |
| **Syntactic** (X) | Is it internally consistent and well-structured? | Format compliance, structural completeness, no broken references |

### Scoring Scale (1-5)

| Score | Meaning |
|-------|---------|
| 1 | Poor -- major issues, blocks use |
| 2 | Below Standard -- significant gaps |
| 3 | Adequate -- meets minimum bar |
| 4 | Good -- clear, useful, few issues |
| 5 | Excellent -- exemplary, no issues |

### Verdict Thresholds

**Phase A/B (pre-push hook)**:
- **GO**: All scores >= 3
- **NO-GO**: Any score < 3
- **UNDETERMINED**: Judge lacks confidence or returns invalid response

**Phase C (task-boundary judge)** -- see `skills/judge/SKILL.md`:
- **accept**: All dimensions >= 3 AND average >= 3.5
- **improve**: Any dimension < 3 OR average < 3.5, but all >= 2
- **reject**: Any dimension < 2
- **escalate**: Models disagree on accept vs reject

---

## Phase A: Advisory Mode (Current Production)

**Deployed**: 2026-02-15 on linux-small-box
**Hook**: `cto-executive-system/automation/judge/pre-push-judge.sh` (196 lines)
**Model**: Cerebras llama-3.3-70b via Terraphim LLM proxy (`http://127.0.0.1:3456`)
**Prompt**: `cto-executive-system/automation/judge/judge-prompt.txt`
**Latency**: ~370ms per evaluation
**Cost**: ~$0.001/evaluation

### Behaviour

1. Intercepts every `git push` containing agent commits (committer = "OpenClaw Agent")
2. Filters to `.md` files in watched paths: `research/`, `knowledge/`, `nimbalyst-local/plans/`
3. Concatenates file contents, substitutes into rubric prompt
4. Calls Terraphim LLM proxy with `jq -Rs` escaped payload
5. Parses verdict JSON from OpenAI-compatible chat completion response
6. Strips markdown code fences if present, compacts with `jq -c`
7. Appends verdict record to `~/.openclaw/judge-verdicts/YYYY-MM-DD.jsonl`
8. **Always exits 0** -- push is never blocked

### Error Handling (Crash-Proof Observer)

Every error path exits 0:

| Error | Behaviour |
|-------|-----------|
| `TERRAPHIM_API_KEY` not set | Skip evaluation, exit 0 |
| Proxy timeout / connection error | Log UNDETERMINED verdict, exit 0 |
| Judge returns invalid JSON | Log UNDETERMINED verdict, exit 0 |
| Judge prompt file missing | Log UNDETERMINED verdict, exit 0 |
| No agent commits in push | Skip silently, exit 0 |
| No evaluable `.md` files | Skip silently, exit 0 |

### Morning Triage

**Script**: `cto-executive-system/automation/triage/scan-judge-verdicts.sh`

Runs as part of the morning automation pipeline on Mac. SSHes to linux-small-box, reads JSONL verdict logs from the last 7 days, counts GO/NO-GO/UNDETERMINED, surfaces flagged items (NO-GO and UNDETERMINED) with commit SHA, file paths, and findings for human review.

### Verdict Record Format (Phase A)

```json
{
  "commit": "abc12345...",
  "timestamp": "2026-02-15T10:30:00Z",
  "author": "OpenClaw Agent",
  "judge_model": "fastest",
  "files_evaluated": ["research/signal.md"],
  "scores": {"semantic": 4, "pragmatic": 5, "syntactic": 5},
  "verdict": "GO",
  "findings": "Content meets all quality thresholds",
  "revision_suggestions": []
}
```

### Installation

```bash
# On linux-small-box (where agent pushes originate)
cd /path/to/cto-executive-system
ln -sf $(git rev-parse --show-toplevel)/automation/judge/pre-push-judge.sh .git/hooks/pre-push

# Required env var -- set in ~/.profile AND ~/.config/environment.d/
# (not just ~/.bashrc -- SSH non-interactive shells skip .bashrc)
export TERRAPHIM_API_KEY="your-proxy-auth-key"
```

---

## Phase B: Blocking Mode

**Status**: Ready for deployment, pending KPI validation from Phase A data
**Original target**: 2026-03-03 (2 weeks after Phase A deployment)

### What Changes

A single behavioural change in the production pre-push hook (`cto-executive-system/automation/judge/pre-push-judge.sh`): instead of always exiting 0, it exits 1 on NO-GO verdicts, which tells git to abort the push.

```
Phase A:  verdict == NO-GO    -> log verdict, exit 0  (push proceeds)
Phase B:  verdict == NO-GO    -> log verdict, exit 1  (push blocked)
          verdict == GO       -> log verdict, exit 0  (push proceeds)
          verdict == UNDETERMINED -> log verdict, exit 0  (push proceeds)
```

The agent or operator must fix the flagged content and retry the push.

### Prerequisites

Phase B must not be enabled until all thresholds are met over a minimum 2-week calibration period of Phase A data:

| KPI | Threshold | Why |
|-----|-----------|-----|
| **False positive rate** | < 10% | Too many false NO-GO verdicts and operators will remove the hook |
| **False negative rate** | < 5% | Judge must catch genuinely poor content |
| **GO rate** | 70-90% | Below 70% suggests rubric too strict or agent instructions need tuning |
| **UNDETERMINED rate** | < 15% | Too many unknowns means model/rubric cannot handle the domain |
| **Proxy availability** | > 95% | In blocking mode, a down proxy must not block pushes |
| **Median latency** | < 30s | Push latency must stay tolerable |

### Analysing Calibration Data

Run on linux-small-box where verdict logs are stored:

```bash
cd ~/.openclaw/judge-verdicts

# Verdict distribution
cat *.jsonl | jq -r '.verdict' | sort | uniq -c | sort -rn

# False positive candidates: NO-GO verdicts to manually review
cat *.jsonl | jq -c 'select(.verdict == "NO-GO")' | head -20

# UNDETERMINED breakdown
cat *.jsonl | jq -r 'select(.verdict == "UNDETERMINED") | .findings' | sort | uniq -c

# Proxy availability: count timeouts
cat *.jsonl | jq -r 'select(.findings | test("timeout|unavailable"; "i")) | .timestamp' | wc -l

# Total evaluations
cat *.jsonl | wc -l
```

### Implementation Changes

Four changes to `cto-executive-system/automation/judge/pre-push-judge.sh`:

**1. Add emergency bypass (top of script, after configuration)**:

```bash
# Phase B: Allow emergency bypass
if [ "${GIT_JUDGE_SKIP:-}" = "1" ]; then
  echo "[judge] GIT_JUDGE_SKIP=1 -- bypassing judge evaluation" >&2
  exit 0
fi
```

**2. Track NO-GO state (before the main loop)**:

```bash
had_nogo="false"
```

**3. Set flag on NO-GO verdict (inside the verdict check)**:

```bash
if [ "$verdict" = "NO-GO" ]; then
  had_nogo="true"
  findings=$(echo "$judge_result" | jq -r '.findings // "no details"' 2>/dev/null)
  echo "[judge] Findings: $findings"
fi
```

**4. Replace final `exit 0` with conditional blocking**:

```bash
# Replace the unconditional: exit 0
if [ "$had_nogo" = "true" ]; then
  echo "[judge] BLOCKED: Content did not pass quality check." >&2
  echo "[judge] Fix the flagged issues and push again." >&2
  echo "[judge] Emergency override: GIT_JUDGE_SKIP=1 git push" >&2
  exit 1
fi
exit 0
```

Note: UNDETERMINED verdicts do **not** set `had_nogo`. Proxy errors, timeouts, and parse failures degrade to advisory behaviour, never to blocking. This preserves the crash-proof observer principle from Phase A.

### Safety Mechanisms

| Mechanism | Purpose |
|-----------|---------|
| `GIT_JUDGE_SKIP=1` | Emergency bypass env var |
| `git push --no-verify` | Git's built-in hook bypass |
| Timeout -> exit 0 | Proxy failures degrade to advisory |
| UNDETERMINED -> exit 0 | Uncertain verdicts do not block |
| Morning triage continues | Human oversight remains regardless of mode |

### Rollback

```bash
# Option 1: Remove the hook entirely
rm .git/hooks/pre-push

# Option 2: Revert to Phase A
# Change the final block to: exit 0 (remove the had_nogo conditional)
```

### Operational Runbook

**Enabling Phase B**:

1. Run calibration analysis on linux-small-box (commands above)
2. Verify all KPI thresholds are met
3. Apply the 4 code changes to the production pre-push hook
4. Test with a deliberate low-quality push to confirm blocking works
5. Test with `GIT_JUDGE_SKIP=1 git push` to confirm override works
6. Monitor morning triage for 48 hours for unexpected blocks

**If false positives spike**:

1. Review recent NO-GO verdicts: correct rejections or judge errors?
2. If judge errors: refine rubric prompt or check if model behaviour changed
3. If model changed: `curl https://api.cerebras.ai/v1/models` to verify model name
4. Temporary mitigation: revert to Phase A while investigating

**If proxy goes down**:

- Pushes proceed (UNDETERMINED -> exit 0). No developer workflow disruption.
- Fix proxy: `sudo systemctl restart terraphim-llm-proxy` on linux-small-box
- Verify: `curl http://127.0.0.1:3456/v1/models`

---

## Phase C: Multi-Model Task-Boundary Judge

**Status**: Implemented in this repo, not yet wired to runtime
**Runner**: `automation/judge/run-judge.sh` (597 lines, v2)
**Skill definition**: `skills/judge/SKILL.md`
**Disagreement handler**: `automation/judge/handle-disagreement.sh` (220 lines)
**Agent hook template**: `automation/judge/terraphim-agent-hook.toml`

Phase C adds a deeper review layer at the **task completion boundary** (not push time), using multiple models for independent evaluation.

### 3-Tier Model Architecture

| Tier | Model | Role | Timeout |
|------|-------|------|---------|
| Quick | `opencode/gpt-5-nano` (Zen free) | Rapid pass/fail screening | 45s |
| Deep | `opencode/kimi-k2.5-free` (Zen free) | Thorough evaluation with improvements | 60s |
| Tiebreaker | `opencode/gpt-5.1-codex-mini` (Copilot free) | Resolve accept/reject disagreement | 45s |

Three different model families (GPT-5 / Kimi / Codex) for genuine independence. All free tier. Config: `automation/judge/opencode-judge.json`.

### Multi-Iteration Protocol

```
Round 1: Quick judge (gpt-5-nano, truncated to 4000 chars)
   |
   +-- accept --> DONE (exit 0)
   +-- reject --> handle-disagreement.sh --reason persistent-reject (exit 1)
   +-- improve --> proceed to Round 2

Round 2: Deep judge (kimi-k2.5-free, full content)
   |
   +-- accept --> DONE (exit 0)
   +-- reject --> handle-disagreement.sh --reason persistent-reject (exit 1)
   +-- improve (both rounds) --> handle-disagreement.sh --reason disagreement (exit 2)
   |
   Quick accept + Deep reject, OR Quick reject + Deep accept:
   --> proceed to Round 3 (tiebreaker)

Round 3: Tiebreaker (gpt-5.1-codex-mini, full content + prior verdicts)
   |
   +-- accept --> DONE (exit 0, consensus: majority or unanimous)
   +-- reject --> handle-disagreement.sh --reason persistent-reject (exit 1)
   +-- other --> handle-disagreement.sh --reason disagreement (exit 2)
```

Maximum 3 model calls. Wall-clock budget: 180 seconds. Each round retries once on empty response.

### Key Implementation Details

**File-based prompt delivery** (`run-judge.sh:write_prompt_file`): Prompts are written to temp files and piped to opencode via stdin. Task files are attached via `--file` flags. This eliminates shell escaping issues with special characters in file content.

**Score normalization** (`run-judge.sh:validate_and_normalize`): Handles both flat (`{"semantic":N}`) and nested (`{"scores":{"semantic":N}}`) formats from different models. Computes average if missing. Validates ranges (1-5).

**JSON extraction** (`run-judge.sh:extract_verdict_json`): Strips markdown fencing, attempts full-text JSON parse, falls back to regex search for `{"verdict":...}` objects.

**Terraphim integration** (`run-judge.sh:terraphim_check`): Optional. When `terraphim-cli` is available, runs `terraphim-cli find` on the judge's reasoning text to identify matched rubric terms from the KG thesaurus. Fail-open: works without terraphim.

### Disagreement Handler

`automation/judge/handle-disagreement.sh` handles human fallback:

1. Extracts verdict history for the task from `verdicts.jsonl`
2. Builds a scores comparison table
3. Creates a GitHub issue: `[JUDGE-DISAGREEMENT] Review needed: <task>`
4. Sends MCP Agent Mail notification to CTO mailbox (best-effort, `http://100.106.66.7:8765/api/`)
5. Supports human override: `--override accept` or `--override reject` appends a `human_override: true` record

### Running the Task-Boundary Judge

```bash
./automation/judge/run-judge.sh \
  --task-id "issue-42" \
  --description "Evaluate knowledge base article" \
  --acceptance "Must include domain terminology and actionable recommendations" \
  path/to/file1.md path/to/file2.rs

# Exit codes: 0 (accepted), 1 (rejected), 2 (human fallback needed)
```

### Human Override

```bash
./automation/judge/handle-disagreement.sh \
  --task-id "issue-42" \
  --override accept  # or reject
```

### Verdict Record Format (Phase C)

See `automation/judge/verdict-schema.json` (JSON Schema 2020-12) for the full specification.

```json
{
  "task_id": "issue-42",
  "model": "opencode/gpt-5-nano",
  "mode": "quick",
  "verdict": "accept",
  "scores": {"semantic": 4, "pragmatic": 4, "syntactic": 5},
  "average": 4.33,
  "reasoning": "Justification for scores",
  "improvements": [],
  "timestamp": "2026-02-17T14:30:00Z",
  "round": 1,
  "judge_tier": "quick",
  "previous_rounds": [],
  "consensus": null,
  "human_override": null
}
```

### Terraphim Integration (Optional)

```bash
# Install judge KG files and configure LLM Enforcer role
bash automation/judge/setup-judge-kg.sh

# Verify
terraphim-cli thesaurus --limit 50
terraphim-cli find "factual correctness and actionability"
```

KG thesaurus files in `automation/judge/kg/`:

| File | Normalized Term | Content |
|------|----------------|---------|
| `judge-semantic.md` | semantic | 14 synonyms (factual correctness, domain accuracy, ...) |
| `judge-pragmatic.md` | pragmatic | 15 synonyms (actionable, useful, practical, ...) |
| `judge-syntactic.md` | syntactic | 15 synonyms (internally consistent, well-structured, ...) |
| `judge-verdicts.md` | verdict | 11 terms (accept, improve, reject, escalate, ...) |
| `judge-checklist.md` | judge checklist | 11 terms (scores, reasoning, improvements, ...) |

### Future: terraphim-agent Integration

`automation/judge/terraphim-agent-hook.toml` is a template for wiring the judge into terraphim-agent's task completion flow:

```toml
[hooks]
post_task_complete = "automation/judge/run-judge.sh --task-id {task_id} ..."
```

This is Phase 5 of the original plan (#22). terraphim-agent does not yet support this hook mechanism.

---

## Lessons Learned (Day 1 Deployment, 2026-02-15)

Seven bugs found and fixed during Phase A deployment. Full post-mortem: `cto-executive-system/research/lessons-learned-judge-hook.md`.

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | Git commit amend in pre-push | Push payload computed before hook runs | Switched to JSONL logging |
| 2 | Advisory hook blocks push | `${VAR:?}` exits 1 on unset var with `set -e` | Explicit check with exit 0 fallback |
| 3 | SSH shells miss env vars | Non-interactive shells skip `.bashrc` | Set vars in `.profile` + `environment.d` |
| 4 | Z.ai 429 "Insufficient balance" | Wrong endpoint for Coding Plan keys | Use `/api/coding/paas/v4` |
| 5 | GLM-5 33% timeout rate | Reasoning model chain-of-thought varies | Demote to `think` route only |
| 6 | Pretty JSON breaks JSONL | LLM returns indented JSON | Apply `jq -c` before appending |
| 7 | Cerebras model renamed | `llama3.1-70b` -> `llama-3.3-70b` | Query `/models` endpoint first |

### Design Decisions That Paid Off

1. **Advisory mode first** -- shipped day 1 without workflow disruption; bugs were logging issues, not blockers
2. **Different model for judge vs author** -- Cerebras judges content written by terraphim/thinking; independence prevents score inflation
3. **JSONL over git artifacts** -- no merge conflicts, no repo bloat, trivial SSH-based reading
4. **Proxy-mediated access** -- model changes are config changes on the proxy, not hook code changes
5. **3-dimension rubric** -- "Pragmatic score is 2" is more actionable than "FAIL"

---

## Scaling Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| **A: Advisory** | Single agent, pre-push, morning triage | Production (2026-02-15) |
| **B: Blocking** | Same as A, exit 1 on NO-GO | Pending KPI validation |
| **C: Task-Boundary** | 3-tier multi-model, improvement loop | Implemented, not deployed |
| **D: Multi-Agent** | Multiple agents, peer review, risk-scaled depth | Planned |
| **E: Org-Wide** | Centralized verdict aggregation, Judge-as-a-Service | Speculative |

---

## File Index

### This Repo (terraphim-skills)

| Path | Lines | Purpose |
|------|-------|---------|
| `skills/judge/SKILL.md` | 202 | Skill definition: rubric, protocol, modes |
| `skills/judge/references/prompt-quick.md` | 63 | Quick judge prompt template |
| `skills/judge/references/prompt-deep.md` | 113 | Deep judge prompt template |
| `automation/judge/run-judge.sh` | 597 | Multi-iteration runner (v2) |
| `automation/judge/handle-disagreement.sh` | 220 | GitHub issue creation + human override |
| `automation/judge/pre-push-judge.sh` | 79 | Pre-push hook (terraphim-skills version) |
| `automation/judge/setup-judge-kg.sh` | 61 | KG installation + LLM Enforcer role setup |
| `automation/judge/verdict-schema.json` | 147 | JSON Schema 2020-12 for verdict records |
| `automation/judge/opencode-judge.json` | ~10 | opencode provider config (Zen + Copilot) |
| `automation/judge/terraphim-agent-hook.toml` | 35 | terraphim-agent integration template |
| `automation/judge/verdicts.jsonl` | (grows) | Verdict audit log |
| `automation/judge/kg/judge-*.md` | 5 files | KG thesaurus for rubric terms |
| `docs/design-judge-v2.md` | 348 | v2 design document |
| `docs/research-judge-v2.md` | ~300 | v2 research document |
| `docs/handover-judge-v2.md` | 124 | v2 handover document |

### Production (cto-executive-system)

| Path | Purpose |
|------|---------|
| `automation/judge/pre-push-judge.sh` | Production hook (196 lines, advisory mode) |
| `automation/judge/judge-prompt.txt` | Production rubric prompt |
| `automation/judge/verdict-schema.json` | Production verdict schema |
| `automation/triage/scan-judge-verdicts.sh` | Morning triage reader |
| `research/lessons-learned-judge-hook.md` | Day 1 post-mortem (264 lines) |
| `plans/terraphim-skills-judge.md` | Multi-model judge plan (402 lines) |

### Runtime (linux-small-box)

| Path | Purpose |
|------|---------|
| `~/.openclaw/judge-verdicts/*.jsonl` | Daily verdict logs (append-only) |
| `/etc/terraphim-llm-proxy/config.toml` | Proxy model routing config |
| `/etc/terraphim-llm-proxy/env` | Provider API keys |
