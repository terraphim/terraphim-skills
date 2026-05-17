# Judge: Usage Guide

A practical "how do I run this" guide for the judge skill. For *why* the judge exists and how it's built, see [`judge-system-architecture.md`](judge-system-architecture.md), [`design-judge-v2.md`](design-judge-v2.md), and [`research-judge-v2.md`](research-judge-v2.md).

**Status**: production-ready as of v1.4.2 + PR #73 fixes. Default models verified live on 2026-05-17.

---

## Quick start

Evaluate one file:

```bash
automation/judge/run-judge.sh \
  --task-id "demo" \
  --description "What this task was supposed to do" \
  path/to/output.md
```

Exit code tells you what happened:

| Code | Meaning |
|------|---------|
| `0` | Verdict was `SAFE_TO_COMMIT` (or `SAFE_TO_DEPLOY_AFTER_RUNTIME_CHECK`, or `INSUFFICIENT_EVIDENCE` after the deep judge ran) |
| `1` | Verdict was `BLOCK` or `FIX_FIRST` and the run terminated -- you should not ship |
| `2` | Human review required (deep judge failed, both judges said FIX_FIRST, etc.). The review block is printed to stdout |

The verdict object is appended to `automation/judge/verdicts.jsonl` as one line of JSON.

---

## What gets installed

```
automation/judge/
  run-judge.sh             # main runner -- this is what you invoke
  pre-push-judge.sh        # git pre-push hook wrapper
  handle-disagreement.sh   # fallback / human-override handler
  setup-judge-kg.sh        # optional: installs KG files for terraphim-agent
  opencode-judge.json      # opencode config used by run-judge.sh
  verdict-schema.json      # JSON schema for verdict records
  verdicts.jsonl           # append-only log of every verdict produced
  kg/                      # rubric vocabulary for terraphim-agent enrichment
```

The skill definition (loaded by Claude Code / OpenCode) lives at `skills/judge/SKILL.md`. The `automation/judge/` scripts are what actually run.

---

## Prerequisites

| Tool | Required for | Install |
|------|-------------|---------|
| `opencode` | All judge invocations | <https://opencode.ai> |
| `bash` 4+, `python3`, `jq` | All judge invocations | system package manager |
| `gh` (optional) | `JUDGE_CREATE_ISSUES=1` mode in `handle-disagreement.sh` | <https://cli.github.com> |
| `terraphim-agent` (optional) | KG-based term enrichment in verdict reasoning | `cargo install terraphim-agent` |

Without `terraphim-agent` the judge runs perfectly -- you just lose one line of enrichment per verdict ("Matched N rubric terms"). The script is fail-open.

---

## Common invocations

### Single file

```bash
automation/judge/run-judge.sh \
  --task-id "issue-42" \
  --description "Add OAuth2 login flow" \
  --acceptance "User can log in with Google; tokens stored encrypted" \
  src/auth/oauth.rs
```

### Multiple files

```bash
automation/judge/run-judge.sh \
  --task-id "PR-128" \
  --description "Refactor payment service" \
  src/payments/charge.rs src/payments/refund.rs tests/payments_test.rs
```

### Custom verdict log location

```bash
automation/judge/run-judge.sh \
  --task-id "audit-2026-05" \
  --output /var/log/judge/may-verdicts.jsonl \
  audit-target.md
```

### All options

```
-t, --task-id      Task identifier (default: "unknown") -- shows up in verdict JSON
-d, --description  What the task was meant to accomplish -- fed to the model
-a, --acceptance   Acceptance criteria -- fed to the model
-c, --config       opencode config path (default: automation/judge/opencode-judge.json)
-o, --output       Verdict JSONL output (default: automation/judge/verdicts.jsonl)
-h, --help         Show built-in help
```

---

## Reading verdicts

Each line of `verdicts.jsonl` is a complete verdict per [`verdict-schema.json`](../automation/judge/verdict-schema.json). The fields you usually care about:

```bash
tail -1 automation/judge/verdicts.jsonl | jq '{
  task_id, verdict, average, judge_tier,
  scores, reasoning, improvements
}'
```

The five verdicts mean:

| Verdict | When | Action |
|---------|------|--------|
| `SAFE_TO_COMMIT` | All dimensions >= 3, average >= 3.5 | Ship it |
| `SAFE_TO_DEPLOY_AFTER_RUNTIME_CHECK` | All dimensions >= 3 but deploy needs runtime verification | Ship, then run smoke test in prod-like env |
| `FIX_FIRST` | Any dimension < 3 but all >= 2 | Address the issues in `improvements[]`, then re-judge |
| `BLOCK` | Any dimension < 2, or security/data/deploy risk flagged | Do not ship; fundamental rework needed |
| `INSUFFICIENT_EVIDENCE` | Judge could not reach a reliable verdict | Provide more context (acceptance criteria, related files) and re-run |

---

## Pre-push hook

Run the judge automatically on every `git push`. Two installation styles:

### As a real git hook

```bash
ln -sf ../../automation/judge/pre-push-judge.sh .git/hooks/pre-push
```

The hook diffs `HEAD @{u}`, filters to source files (`.md .rs .py .ts .js .json .toml .yaml .yml .sh`), and runs the judge on each. Exit `1` blocks the push; bypass with `git push --no-verify` if you genuinely need to.

### As a Claude Code PreToolUse hook

In `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash(git push:*)",
      "hooks": [{
        "type": "command",
        "command": "automation/judge/pre-push-judge.sh"
      }]
    }]
  }
}
```

---

## Overriding the models

Defaults are picked because they were verified live; they're not religious. Override via environment:

```bash
JUDGE_QUICK_MODEL="opencode/gpt-5.1-codex-mini" \
JUDGE_DEEP_MODEL="opencode/kimi-k2.6" \
JUDGE_TIEBREAKER_MODEL="opencode/claude-haiku-4-5" \
  automation/judge/run-judge.sh --task-id "demo" output.md
```

| Env var | Default | Default rationale |
|---------|---------|-------------------|
| `JUDGE_QUICK_MODEL` | `opencode/gpt-5-nano` | Fast, low latency, accurate enough for screening |
| `JUDGE_DEEP_MODEL` | `opencode/deepseek-v4-flash-free` | Free, reasoning-capable, returns clean JSON |
| `JUDGE_TIEBREAKER_MODEL` | `opencode/gpt-5.1-codex-mini` | Independent provider lineage to break quick/deep ties |

Discover available model names with `opencode models | grep -i free`.

---

## When a verdict needs a human

Three things can trigger fallback: deep judge fails twice, both quick and deep return `FIX_FIRST`, or tiebreaker disagrees with both. The judge then calls `automation/judge/handle-disagreement.sh`.

### Default behaviour (safe)

The handler prints a "Judge review needed" block to stdout. This is the default because the judge often runs inside repos it shouldn't be filing tickets against (typical hit: smoke-testing inside an unrelated project).

### Opt in to auto-issue creation

When you *want* a tracked issue in the current repo:

```bash
JUDGE_CREATE_ISSUES=1 automation/judge/run-judge.sh ...
```

Requires `gh` authenticated to a repo with issue permissions. Labels the issue `JUDGE-DISAGREEMENT`, `JUDGE-REJECTED`, `JUDGE-TIMEOUT`, or `JUDGE-PARSE-ERROR` depending on the cause.

### Logging a human override

After human review, append the decision to the verdict log:

```bash
automation/judge/handle-disagreement.sh \
  --task-id "issue-42" \
  --override accept     # or reject
```

This writes a record with `model: "human"`, `human_override: true`, so audits can distinguish machine and human verdicts.

---

## Optional: terraphim-agent KG enrichment

When `terraphim-agent` is installed, the runner does a quick lookup against the judge KG so each verdict reasoning can be tagged with how many rubric terms it referenced (`[terraphim] Matched N rubric terms in reasoning`). One-time setup:

```bash
bash automation/judge/setup-judge-kg.sh

# Verify
terraphim-agent search "factual correctness and actionability" --limit 5
```

This copies five KG files (`judge-semantic.md`, `judge-pragmatic.md`, `judge-syntactic.md`, `judge-verdicts.md`, `judge-checklist.md`) to `~/.config/terraphim/kg/`, configures the "LLM Enforcer" role, and verifies it can resolve rubric terminology.

Skip this if you don't have `terraphim-agent` -- the judge runs fine without it. The enrichment is purely a verdict-annotation aid.

---

## Verdict log analysis

The `verdicts.jsonl` file is append-only; one verdict per line. Useful one-liners:

```bash
# How many verdicts have I produced this month?
jq -r '.timestamp' automation/judge/verdicts.jsonl \
  | grep "^2026-05" | wc -l

# Which tasks hit human fallback?
jq -r 'select(.human_override == true) | "\(.timestamp)  \(.task_id)  \(.verdict)"' \
  automation/judge/verdicts.jsonl

# Average score per dimension across all my verdicts
jq -s '
  map(.scores) |
  {
    semantic:  (map(.semantic)  | add / length),
    pragmatic: (map(.pragmatic) | add / length),
    syntactic: (map(.syntactic) | add / length)
  }
' automation/judge/verdicts.jsonl

# Verdicts where quick and deep disagreed (tiebreaker fired)
jq -r 'select(.round == 3) | "\(.task_id)  consensus=\(.consensus)  final=\(.verdict)"' \
  automation/judge/verdicts.jsonl
```

---

## Troubleshooting

### "Deep judge returned empty response, retrying..."

Almost always means the default `JUDGE_DEEP_MODEL` is no longer in the opencode catalogue (providers rotate names regularly). Probe what's available:

```bash
opencode models | grep -i free
```

Then re-run with `JUDGE_DEEP_MODEL=opencode/<working-name>` and -- if that model proves stable -- open a small PR updating the default in `automation/judge/run-judge.sh`.

### Script accidentally opened a GitHub issue

Earlier behaviour was unconditional. Since PR #73 the default is stdout-only and you must opt in with `JUDGE_CREATE_ISSUES=1`. If you see a stray issue, you're either running an older revision (pull and re-install) or you set the env var somewhere. Check `env | grep JUDGE`.

### Exit code 0 when I expected fallback

You're probably reading the exit code of a pipeline, not the script. The exit code propagates as the *last* command's:

```bash
# Wrong -- always returns tail's exit
run-judge.sh ... | tail -10
echo $?

# Right
run-judge.sh ... > out.log
echo $?
tail -10 out.log
```

### "MCP Agent Mail notification skipped (server not available)"

Cosmetic. The handler tries to ping a Tailscale-internal MCP Agent Mail server at `http://100.106.66.7:8765`. If you're not on that tailnet it silently skips. Does not affect verdict outcomes.

### terraphim-agent reports "No KG links found"

Run `setup-judge-kg.sh` then `terraphim-agent roles select "LLM Enforcer"`. If still empty, check `~/.config/terraphim/kg/` -- the five `judge-*.md` files should be present.

---

## Integration patterns

### CI (GitHub Actions)

```yaml
- name: Run judge on changed files
  run: |
    git diff --name-only origin/main...HEAD \
      | grep -E '\.(md|rs|py|ts|js|sh)$' \
      | xargs -r automation/judge/run-judge.sh \
          --task-id "PR-${{ github.event.pull_request.number }}" \
          --description "${{ github.event.pull_request.title }}"
  env:
    JUDGE_CREATE_ISSUES: '1'
```

### Disciplined-* workflow

Use the judge as the gate between `disciplined-implementation` and `disciplined-verification`:

```bash
# After Phase 3 produces working code
automation/judge/run-judge.sh \
  --task-id "$ISSUE_ID" \
  --description "$(cat docs/research-$ISSUE_ID.md | head -1)" \
  --acceptance "$(jq -r '.acceptance_criteria' design-$ISSUE_ID.json)" \
  $CHANGED_FILES \
&& invoke-skill disciplined-verification
```

`SAFE_TO_COMMIT` (exit 0) proceeds to verification; anything else short-circuits the pipeline.

---

## Known limitations / follow-ups

- **`verdict-schema.json` has a closed `model` enum** listing the old `opencode/kimi-k2.5-free`. Verdicts produced with the new default `opencode/deepseek-v4-flash-free` are valid JSON but will not validate against the strict schema. Loosen to a `pattern: "^opencode/.+"` in a future PR.
- **`setup-judge-kg.sh` hardcodes the "LLM Enforcer" role.** Should accept `--role` for projects that already have a different role configured.
- **Pre-push hook lacks CI smoke test.** No automated check guards against the hook breaking under future shell or git versions.

---

## Where each file lives (cheat sheet)

| You want to... | Look here |
|----------------|-----------|
| Change defaults (timeouts, truncation, model names) | `automation/judge/run-judge.sh` lines 26-40 |
| Adjust the JSON the model is asked to return | `skills/judge/references/prompt-quick.md` / `prompt-deep.md` |
| Add a new judge dimension | `automation/judge/verdict-schema.json` + both prompt templates + `automation/judge/kg/` |
| Trace what a verdict means | `skills/judge/SKILL.md` -- "Verdict Thresholds" section |
| Understand the multi-iteration protocol | `automation/judge/run-judge.sh` "Main execution" comment block (~line 400) |
| Override one verdict from the command line | `automation/judge/handle-disagreement.sh --task-id X --override accept` |
| Audit who/what produced a verdict | `automation/judge/verdicts.jsonl` |

---

## See also

- [`skills/judge/SKILL.md`](../skills/judge/SKILL.md) -- the skill definition AI agents load
- [`docs/judge-system-architecture.md`](judge-system-architecture.md) -- system design and rubric rationale
- [`docs/design-judge-v2.md`](design-judge-v2.md) -- v2 design notes (file-based prompts, terraphim integration)
- [`docs/research-judge-v2.md`](research-judge-v2.md) -- research that shaped v2
- [`docs/handover-judge-v2.md`](handover-judge-v2.md) -- handover notes from the v2 build-out
