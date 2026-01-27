# Terraphim Claude Skills - Operating Philosophy

> "Essentialism is about doing the right things. Effortless is about doing them in the right way."
> -- Greg McKeown

## Essentialism + Effortless Operating System

This workspace operates on two complementary principles:

### 1. Essentialism: The Disciplined Pursuit of Less
Focus over breadth. The vital few over the trivial many.

### 2. Effortless: Making Essential Work Easy
Don't push harder--find the easier path.

---

## The Three Essential Questions (Pre-Flight Check)

Before any significant work, answer:

1. **Inspiration**: Does this energize or drain?
2. **Leverage**: Does this use unique strengths?
3. **Value**: Does this meet a real need?

If < 2 of 3: likely non-essential. Challenge it.

---

## Operating Rules

### The 90% Rule
If it's not a clear YES (90%+ fit), it's a NO.

### Warren Buffett's 5/25 Rule
1. List up to 25 goals/priorities
2. Circle the top 5
3. The remaining 20 become your **AVOID AT ALL COST** list

### Effortless Inversion
For every problem: **"What if this could be easy?"**
Design the simplest path, not the most impressive.

---

## Phase-Gated Development

| Phase | McKeown | Skill | Output |
|-------|---------|-------|--------|
| 1 | EXPLORE | disciplined-research | Research Document |
| 1.5 | EVALUATE | disciplined-quality-evaluation | KLS Assessment |
| 2 | ELIMINATE | disciplined-design | Implementation Plan |
| 2.5 | CLARIFY | disciplined-specification | Edge Cases |
| 3 | EXECUTE | disciplined-implementation | Working Code |
| 4 | VERIFY | disciplined-verification | Test Evidence |
| 5 | VALIDATE | disciplined-validation | UAT Sign-off |

---

## Quality Gates

```yaml
document_quality_gate:
  minimum_dimension_score: 3
  minimum_average_score: 3.5
  blocking: true

essentialism_check:
  enabled: true
  require_vital_few_alignment: true
  max_scope_items: 5
```

---

## Code Quality: Simple Over Easy

| Prefer | Over |
|--------|------|
| Fewer files with clear purpose | Many files with scattered logic |
| Explicit, readable code | Clever, compact code |
| Composition | Deep inheritance |
| Clear contracts | Hidden dependencies |
| Delete code | Comment out code |

---

## Anti-Patterns to Eliminate

- **Undisciplined Pursuit of More**: Adding without removing
- **Heroic Effort**: Pushing through vs. removing obstacles
- **Saying Yes by Default**: Every YES to non-essential = NO to essential
- **Over-Engineering**: Building for hypotheticals
- **Scope Creep**: Expanding without explicit approval

---

## LLM Coding Discipline (Karpathy Principles)

Four principles for reducing common LLM coding mistakes, integrated into the disciplined-* skills:

| Principle | Skill Integration |
|-----------|-------------------|
| **Think Before Coding**: Surface assumptions, present interpretations | disciplined-research |
| **Simplicity First**: Minimum code, nothing speculative | disciplined-design |
| **Surgical Changes**: Touch only what you must | disciplined-implementation |
| **Goal-Driven Execution**: Define success criteria, loop until verified | disciplined-implementation |

*Attribution: Derived from Andrej Karpathy's observations on LLM limitations.*

---

## Daily Practice

### Before Starting Work
- What is the ONE essential thing?
- What must I eliminate or say no to?

### After Completing Work
- Did I focus on the vital few?
- What made work effortless vs. effortful?

---

## Resources

- [Tim Ferriss #786: Essentialism with Greg McKeown](https://tim.blog/2025/01/09/personal-reboot-greg-mckeown/)
- *Essentialism: The Disciplined Pursuit of Less* by Greg McKeown
- *Effortless: Make It Easier to Do What Matters Most* by Greg McKeown
- [Karpathy Guidelines for LLM Coding](https://github.com/forrestchang/andrej-karpthy-skills) by Andrej Karpathy
