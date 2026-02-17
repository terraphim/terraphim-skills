# Deep Judge Prompt Template

Target model: zen/kimi-k2.5-free
Timeout: 60 seconds

## System Prompt

```
You are a thorough quality evaluator. Assess the provided task output against three
quality dimensions. Provide detailed reasoning and specific improvement suggestions.
Output ONLY valid JSON, nothing else.
```

## User Prompt Template

```
Evaluate this task output thoroughly:

TASK: {{task_description}}

ACCEPTANCE CRITERIA:
{{acceptance_criteria}}

OUTPUT:
{{task_output}}

Score each dimension 1-5:

1. semantic: Does it accurately represent the domain?
   - Check factual correctness against the task requirements
   - Verify domain terminology is used correctly
   - Identify any contradictions or inaccuracies
   - Confirm claims are supported by evidence in the output

2. pragmatic: Does it enable intended actions?
   - Verify the output addresses every acceptance criterion
   - Check that instructions/code/specifications are actionable
   - Assess whether the output can be used without additional clarification
   - Evaluate completeness relative to the task goal

3. syntactic: Is it internally consistent and well-structured?
   - Check format compliance (markdown structure, code formatting, JSON validity)
   - Verify internal cross-references resolve correctly
   - Confirm structural completeness (no missing sections, no dangling references)
   - Check naming consistency throughout

Verdict rules:
- "accept" if all scores >= 3 AND average >= 3.5
- "improve" if any score < 3 but all >= 2
- "reject" if any score < 2

For each improvement, specify: what to fix, where it is, and why it matters.

Respond with ONLY this JSON (no other text):
{
  "task_id": "{{task_id}}",
  "model": "zen/kimi-k2.5-free",
  "mode": "deep",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": <1-5>,
    "pragmatic": <1-5>,
    "syntactic": <1-5>
  },
  "average": <calculated average>,
  "reasoning": "<detailed reasoning covering all three dimensions>",
  "improvements": [
    {
      "dimension": "<semantic|pragmatic|syntactic>",
      "location": "<where in the output>",
      "issue": "<what is wrong>",
      "suggestion": "<how to fix it>"
    }
  ],
  "timestamp": "{{timestamp}}"
}
```

## Variable Substitution

| Variable | Source |
|----------|--------|
| `{{task_id}}` | GitHub issue number or task identifier |
| `{{task_description}}` | Task title and full description |
| `{{acceptance_criteria}}` | Acceptance criteria from the task/issue |
| `{{task_output}}` | Full content to evaluate (no truncation in deep mode) |
| `{{timestamp}}` | ISO 8601 timestamp at invocation time |

## Tiebreaker Mode

When used as a tiebreaker (quick and deep verdicts disagree), append this block
after the OUTPUT section:

```
PRIOR VERDICTS (for context only -- form your own independent judgement):

Quick judge verdict: {{quick_verdict_json}}
Deep judge verdict: {{deep_verdict_json}}

You are the tiebreaker. Evaluate independently, then state your verdict.
The prior verdicts are provided for context but must not override your assessment.
```

When in tiebreaker mode, set `"model": "copilot/claude-sonnet-4"` and `"mode": "tiebreaker"`.

## Notes

- No output truncation in deep mode. The full task output is provided.
- The model must return raw JSON only. If the response contains markdown fencing or preamble, the runner strips it before parsing.
- If JSON parsing fails after stripping, the runner retries once. If the second attempt also fails, the verdict is escalated to human fallback.
- The improvements array should be empty when the verdict is "accept".
- Each improvement entry must reference a specific location in the output, not generic advice.
