# Configuration Management for AI Systems: Why Context Is a Controlled Variable

*By Alex Mikhalev | February 2026*

---

AI systems are not traditional software. They behave probabilistically. Their outputs change when prompts change, when models update, when training data shifts, when domain definitions evolve. Traditional configuration management -- designed for deterministic codebases with stable interfaces -- cannot govern this.

The result is predictable: semantic drift goes undetected, artefacts contradict each other across lifecycle stages, informal commitments bypass governance, and nobody can trace how a domain entity in a prompt specification relates to the business scenario that motivated it.

This article describes a formal approach to AI-enabled Configuration Management (CM) that treats **context as a controlled architectural variable** -- not an ambient condition you hope stays stable.

---

## The Problem: Context Entropy

Every AI-enabled program faces the same forces:

**Probabilistic behaviour.** The same prompt may produce different outputs across model versions. Configuration management must track not just what was deployed, but what behaviour was baselined and whether current behaviour still conforms.

**Evolving prompts and models.** Prompt specifications are not static. They evolve as domain understanding deepens, as model capabilities change, and as edge cases surface. Without versioning and baselining, you cannot reconstruct why the system behaved a certain way at a given point in time.

**Shifting domain definitions.** Commercial pressure causes domain models to drift. A term that meant one thing in Discovery means something slightly different by the time Design is complete. If nobody catches this, downstream artefacts inherit the ambiguity.

**Artefact proliferation.** A typical AI program produces: business scenarios, domain models, process models, data schemas, API contracts, AI use cases, UX flows, prompt specifications, model specifications, and risk registers. These artefacts reference each other, depend on each other, and contradict each other -- often silently.

**Informal commitments.** A conversation in a meeting creates an expectation. That expectation becomes an assumption. The assumption becomes a feature. The feature was never formally scoped, never traced to a requirement, never assessed for impact. This is how scope expands without anyone noticing.

Traditional CM handles file versioning and build reproducibility. AI-enabled CM must handle **semantic versioning**: tracking not just what changed, but what it *means* that it changed.

---

## Five Principles of AI-Enabled Configuration Management

### 1. Context is a controlled architectural variable

Context is not something you "manage" informally. It has structure. It has versions. It can be baselined, frozen, and reconciled. When you treat context with the same discipline as source code, you gain the ability to detect when it drifts and to halt progression when integrity is violated.

### 2. AI augments human authority; it does not replace it

AI agents can scan for contradictions, compute impact chains, and detect drift. They cannot approve changes, accept risk, or override governance. Every automated action must have a human authority boundary. The Configuration Control Board (CCB) decides; the AI agent informs.

### 3. Entropy is reduced through baselining and reconciliation

Left unmanaged, artefacts diverge. Terminology drifts. Schemas misalign. The CM system reduces this entropy through two mechanisms: **baselining** (freezing a known-good state at stage-gate boundaries) and **reconciliation** (verifying all artefacts reference the same canonical definitions before progression is allowed).

### 4. Progression halts when semantic integrity is violated

This is the hard rule. If the domain model reconciliation fails, the gate does not pass. If cross-artefact consistency scores exceed the threshold, deployment is blocked. If a prompt specification references a deprecated entity, the change request is required before proceeding. No exceptions without named authority and documented risk acceptance.

### 5. Operational mechanisms, not philosophical descriptions

Every principle must be implementable. "Ensure consistency" is not a mechanism. "Compute pairwise semantic variance scores across all baselined artefacts and flag any pair scoring above 0.3" is a mechanism. The specification demands the latter.

---

## The Architecture: Control Surfaces, Agents, and Gates

### Control Surfaces

The CM system defines 10 **control surfaces** -- managed boundaries across which configuration integrity must be maintained:

| # | Control Surface | Governance Level |
|---|----------------|-----------------|
| 1 | Domain Model | L4 -- Controlled |
| 2 | Business Scenarios | L3 -- Approved |
| 3 | Process Models | L3 -- Approved |
| 4 | Data Schema | L4 -- Controlled |
| 5 | API Contracts | L4 -- Controlled |
| 6 | AI Use Cases | L3 -- Approved |
| 7 | UX Flows | L3 -- Approved |
| 8 | Prompt Specifications | L4 -- Controlled |
| 9 | Model Specifications | L4 -- Controlled |
| 10 | Risk Registers | L3 -- Approved |

Each surface is independently versioned, baselined at stage-gate boundaries, and frozen after gate approval. Frozen surfaces cannot be modified without a formal Change Request.

The critical insight: **prompt specifications and model specifications receive the same L4-controlled governance as API contracts and data schemas.** They are not second-class configuration items.

### AI Agents

Five AI agents operate as an augmentation layer under human authority:

**AI Configuration Manager Agent** -- Orchestrates baseline creation, enforces governance rules, maintains the artefact registry. Can autonomously block non-compliant submissions. Cannot approve changes or override freezes.

**Artefact Consistency Auditor Agent** -- Continuously validates semantic consistency across all managed artefacts. Produces pairwise consistency scores and contradiction reports. Cannot modify artefact content.

**Drift Detection Agent** -- Monitors four categories of drift (terminology, domain schema, AI behaviour, prompt) against baselined profiles. Raises alerts when scores cross thresholds. Cannot modify baselines or accept drift as intentional.

**Impact Analysis Agent** -- Computes the full impact chain of proposed changes: direct impacts, transitive impacts, domain model impacts, AI behaviour impacts. Generates alternative options scored by semantic disruption. Cannot approve changes.

**Gate Reconciliation Agent** -- Executes comprehensive reconciliation checks at stage-gate boundaries. Produces gate readiness reports with pass/warn/fail per criterion. Cannot approve gate passage.

The pattern: agents **propose, analyse, and alert**. Humans **approve, override, and authorise**.

### Stage-Gate Control

Every stage-gate transition triggers a reconciliation protocol:

1. Domain model reconciliation (do all artefacts reference the current canonical version?)
2. Cross-artefact consistency validation (are pairwise scores below threshold?)
3. Contradiction detection scan (are there mutually exclusive constraints?)
4. Traceability graph completeness check (can every requirement trace to a test?)
5. Drift detection scan (has anything drifted since last baseline?)
6. Open incident review (are there unresolved configuration incidents?)

Gate progression follows strict rules:

| Condition | Action |
|-----------|--------|
| All checks pass | Progression approved |
| Warnings only | Progression with documented risk acceptance |
| Any failure | Progression blocked |
| Failure with override | Named authority sign-off + risk register entry |

---

## Drift Detection: The Four Categories

Drift is the silent killer of AI program integrity. The CM system defines four categories, each with distinct detection mechanisms:

### Terminology Drift

The canonical terminology register (derived from the domain model) is scanned against all artefact content. Unregistered variants are flagged. The **Terminology Stability Index (TSI)** measures health:

```
TSI = 1 - (unregistered_variants / total_domain_term_occurrences)
```

TSI below 0.85 triggers a warning. Below 0.70 triggers mandatory remediation before the next gate.

### Domain Schema Drift

Implementation schemas (database DDL, API contracts, message formats) are diffed against the canonical domain model. Missing fields, type mismatches, cardinality violations, and naming divergence are detected. The **Schema Alignment Score (SAS)** quantifies the gap.

### AI Behavioural Drift

Model outputs are sampled and compared against baselined behaviour profiles (output format distribution, confidence distributions, response length, boundary test results). Statistical divergence triggers investigation. The **AI Behaviour Conformance Score (ABCS)** tracks conformance. Below 0.75 triggers an incident.

### Prompt Drift

The effective prompt (post-variable-resolution) is hashed at execution time and compared against the baselined prompt hash. Any mismatch is flagged. Context window truncation events are detected separately. Prompt drift is binary -- it either matches or it does not.

---

## Metrics: Measuring Context Health

The CM system defines a **Context Health Index (CHI)** -- a weighted composite of 10 core metrics:

| Metric | What It Measures |
|--------|-----------------|
| TSI | Terminology stability across artefacts |
| ACS | Artefact coherence (mean pairwise consistency) |
| DFR | Drift frequency rate (alerts per scan cycle) |
| GRR | Gate rejection rate (blocked or conditional gates) |
| USCI | Unauthorised scope change incidents |
| TCP | Traceability completeness percentage |
| ABCS | AI behaviour conformance |
| SAS | Schema alignment with domain model |
| PIS | Prompt integrity (baselined vs deployed) |
| CRCT | Change request cycle time |

CHI above 0.90 indicates healthy context. Below 0.60 triggers an emergency CCB convocation.

The **Entropy Reduction Rate (ERR)** tracks whether context health is improving or degrading over time:

```
ERR = (CHI_current - CHI_previous) / time_delta
```

Positive ERR means the CM system is working. Negative ERR means entropy is winning.

---

## Change Control: The Formal Path

Every change to a baselined or frozen artefact follows a formal workflow:

1. **CR submission** -- requestor, justification, affected artefacts, urgency
2. **Impact analysis** -- automated computation of direct and transitive impacts, plus domain model and AI behaviour impacts
3. **CCB review** -- approve, reject, defer, or request modification
4. **Implementation** -- tracked against the CR
5. **Verification** -- re-run consistency and reconciliation checks
6. **Closure** -- baseline updated, CR archived

Approval authority scales with impact:

| Change Type | Authority |
|-------------|-----------|
| Minor (metadata, non-semantic) | Artefact owner |
| Moderate (semantic, single artefact) | CCB delegate |
| Major (cross-artefact, domain model) | Full CCB |
| Critical (baseline re-creation, stage regression) | Program Director |

The system supports **AI-assisted alternative analysis**: for each CR, the Impact Analysis Agent generates multiple implementation options, scores each on impact scope, risk profile, effort, and semantic coherence, and recommends the alternative with lowest semantic disruption. The human makes the final selection.

---

## Separation of Contexts

One of the most operationally important controls: **technical and commercial channels are isolated**.

Commercial commitments (from account management, sales, or executive conversations) cannot directly modify technical baselines. A formal Change Request is required to translate a commercial commitment into a technical scope change.

Decisions affecting configuration can only be made in designated forums (CCB, Architecture Review Board). Decisions made outside these forums carry no configuration weight. Informal agreements, emails, and verbal commitments are not configuration authority -- unless formalised through a decision container with named authority, traced impacts, and review triggers.

This is not bureaucracy. This is the mechanism that prevents scope creep from conversations that never intended to create scope.

---

## Integration with the ZDP Framework

For programs using the Zestic AI Development Process (ZDP), the CM specification maps naturally to the 6D lifecycle:

- **CM lifecycle stages** align with ZDP stages (Discovery through Drive)
- **CM gate definitions** reference ZDP gate types (PFA, LCO, LCA, IOC, FOC, CLR)
- **Control surface baselines** anchor to ZDP stage-gate boundaries
- **Drift monitoring** feeds into the ZDP Drive stage's continuous learning cycle
- **Epistemic status classification** (from perspective-investigation) enriches gate readiness assessments with Known/Sufficient, Partially Known, Contested, Underdetermined, and Out-of-Scope categories

This integration is optional. The CM specification works standalone for any AI-enabled program, regardless of lifecycle framework. When ZDP is present, the CM system gains the additional governance rigour of the ACGCS framework.

---

## Implementation: Five Phases

The specification recommends a phased implementation:

**Phase 1 -- Foundation**: Artefact registry, baseline creation, freeze logic, version trace model, canonical terminology register. Gate: registry operational, 3+ artefact types under management.

**Phase 2 -- Governance**: CR workflow, Impact Analysis Agent, stage-gate framework, Gate Reconciliation Agent, CCB procedures. Gate: CR workflow end-to-end operational.

**Phase 3 -- Consistency**: Artefact Consistency Auditor Agent, cross-artefact validation engine, traceability graph, bidirectional trace enforcement. Gate: consistency scores computed, traceability > 80%.

**Phase 4 -- AI Governance**: Drift Detection Agent (all 4 categories), prompt/model versioning, behaviour boundary validation. Gate: drift detection operational, AI behaviour baseline established.

**Phase 5 -- Maturity**: Full metrics dashboard (CHI), separation of contexts controls, decision container governance, threshold tuning. Gate: CHI > 0.85, all 10 control surfaces under management.

---

## The Terraphim Skill

The full specification is available as a Terraphim skill: `ai-config-management`. It contains:

- **SKILL.md** -- Workflow, principles, threat table, ZDP integration
- **functional-requirements.md** -- 39 numbered requirements across 9 categories
- **ai-agents.md** -- 5 AI agent definitions with inputs, outputs, decision authority, and human override rules
- **control-surfaces.md** -- 10 control surfaces with baseline rules, freeze conditions, and version trace model
- **drift-detection.md** -- 4 drift categories with detection mechanisms, scoring, and thresholds
- **metrics.md** -- 10 core metrics + 3 derived indicators with escalation matrix
- **deliverable-structure.md** -- 8-section specification template with formatting standards
- **governance-templates.md** -- 8 YAML templates (RACI, CR, gate checklist, incident, risk, decision container, baseline manifest, context health report)

The specification is detailed enough to serve as the basis for implementation planning. It uses formal systems engineering language, numbered requirements (FR-xxx / NFR-xxx), and operational mechanisms rather than philosophical descriptions.

Install it:

```bash
npm skills add terraphim/terraphim-skills
```

Or invoke it directly in Claude Code:

```
/ai-config-management
```

---

## Conclusion

AI systems are not harder to govern than traditional software. They are *differently* governed. The difference is that configuration management must extend from code and infrastructure into semantics: domain models, prompt specifications, model behaviour, terminology, and the relationships between artefacts.

The key shift is treating context as a first-class architectural variable -- versioned, baselined, frozen, reconciled, and traced with the same rigour as any other controlled element. When you do this, entropy stops being an invisible force and becomes a measurable quantity with operational controls.

The alternative -- hoping that artefacts stay consistent, that domain definitions do not drift, that prompt changes do not cascade, and that informal commitments do not create untracked scope -- is not configuration management. It is configuration hope.

Context entropy always increases unless work is done to reduce it. That work is configuration management.
