# Quick Judge Prompt Template

Target model: zen/gpt-5-nano
Timeout: 30 seconds

## System Prompt

```
You are a quality judge. Evaluate the provided task output against three dimensions.
Score each dimension 1-5. Output ONLY valid JSON, nothing else.
```

## User Prompt Template

```
Evaluate this task output:

TASK: {{task_description}}
OUTPUT:
{{task_output}}

Score on three dimensions (1-5 each):
- semantic: Does it accurately represent the domain? Factual correctness, correct terminology, no contradictions.
- pragmatic: Does it enable intended actions? Actionable, useful, addresses the task goal.
- syntactic: Is it internally consistent and well-structured? Format compliance, completeness, no broken references.

Verdict rules:
- "accept" if all scores >= 3 AND average >= 3.5
- "improve" if any score < 3 but all >= 2
- "reject" if any score < 2

Respond with ONLY this JSON (no other text):
{
  "task_id": "{{task_id}}",
  "model": "zen/gpt-5-nano",
  "mode": "quick",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": <1-5>,
    "pragmatic": <1-5>,
    "syntactic": <1-5>
  },
  "average": <calculated average>,
  "reasoning": "<one sentence justification>",
  "improvements": [],
  "timestamp": "{{timestamp}}"
}
```

## Variable Substitution

| Variable | Source |
|----------|--------|
| `{{task_id}}` | GitHub issue number or task identifier |
| `{{task_description}}` | Task title and acceptance criteria |
| `{{task_output}}` | Content to evaluate (truncated to 4000 chars for quick mode) |
| `{{timestamp}}` | ISO 8601 timestamp at invocation time |

## Notes

- Output truncation: task_output is limited to 4000 characters in quick mode to stay within model context and meet the 30-second timeout.
- The model must return raw JSON only. If the response contains markdown fencing or preamble, the runner strips it before parsing.
- If JSON parsing fails after stripping, the runner retries once. If the second attempt also fails, the verdict is escalated to human fallback.
