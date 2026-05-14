# AI Agent Roles and Responsibilities

## Table of Contents

- [Agent Architecture Overview](#agent-architecture-overview)
- [1. AI Configuration Manager Agent](#1-ai-configuration-manager-agent)
- [2. Artefact Consistency Auditor Agent](#2-artefact-consistency-auditor-agent)
- [3. Drift Detection Agent](#3-drift-detection-agent)
- [4. Impact Analysis Agent](#4-impact-analysis-agent)
- [5. Gate Reconciliation Agent](#5-gate-reconciliation-agent)
- [Common Agent Governance Rules](#common-agent-governance-rules)

---

## Agent Architecture Overview

All AI agents operate as **augmentation layers** under human authority. No agent has autonomous decision-making power over configuration state. Agents propose, analyse, and alert; humans approve, override, and authorise.

```
Human Authority Layer
  |
  +-- Configuration Control Board (CCB)
  |     |
  |     +-- AI Configuration Manager Agent
  |     +-- Gate Reconciliation Agent
  |
  +-- CM Team
  |     |
  |     +-- Artefact Consistency Auditor Agent
  |     +-- Drift Detection Agent
  |
  +-- Change Analysts
        |
        +-- Impact Analysis Agent
```

---

## 1. AI Configuration Manager Agent

**Purpose**: Orchestrate configuration control activities, maintain baseline registry, enforce governance rules.

### Inputs

| Input | Source | Format |
|-------|--------|--------|
| Artefact submissions | Development teams | Artefact package (content + metadata) |
| Change Requests | CR workflow | CR record (structured) |
| Stage-gate trigger | Project lifecycle | Gate transition event |
| Governance policy | CM authority | Policy configuration file |
| Domain model updates | Domain modelling team | Versioned domain model |

### Outputs

| Output | Consumer | Format |
|--------|----------|--------|
| Baseline records | All agents, CM team | Baseline manifest (JSON/YAML) |
| Configuration status reports | CCB, Program Director | Structured report |
| Governance violation alerts | CCB, artefact owners | Alert notification |
| Artefact registry updates | All agents | Registry delta event |
| Audit log entries | Compliance team | Immutable log records |

### Decision Authority

| Action | Authority Level |
|--------|----------------|
| Create baseline record | Autonomous (within policy rules) |
| Flag governance violation | Autonomous |
| Block non-compliant submission | Autonomous |
| Approve CR | NOT PERMITTED -- routes to human authority |
| Override freeze | NOT PERMITTED -- requires CCB authority |
| Modify governance policy | NOT PERMITTED -- requires CM authority |

### Human Override Rules

- Any autonomous action can be overridden by CCB or CM lead
- Override requires: named authority, written justification, risk register entry
- Overrides are logged as configuration events with full audit trail
- Repeated overrides of the same rule trigger escalation to Program Director

### Audit Logging Requirements

- Log every state transition of every managed artefact
- Log every governance check result (pass/warn/fail)
- Log every baseline creation and modification
- Log every human override with authority chain
- Retention: minimum 7 years or per regulatory requirement

---

## 2. Artefact Consistency Auditor Agent

**Purpose**: Continuously validate semantic consistency across all managed artefacts.

### Inputs

| Input | Source | Format |
|-------|--------|--------|
| Artefact content | Baseline registry | Artefact content + metadata |
| Canonical domain model | Domain model registry | Versioned domain model |
| Consistency rules | CM policy | Rule definitions (configurable) |
| Terminology register | Domain governance | Term-definition pairs |
| Previous audit results | Audit history | Historical scores |

### Outputs

| Output | Consumer | Format |
|--------|----------|--------|
| Consistency matrix | CM team, CCB | Pairwise score matrix |
| Contradiction report | Artefact owners, CM team | Itemised contradiction list |
| Terminology variance report | Domain governance team | Variant list with scores |
| Trend analysis | CM team | Score trend over time |
| Remediation recommendations | Artefact owners | Prioritised action list |

### Decision Authority

| Action | Authority Level |
|--------|----------------|
| Execute consistency scan | Autonomous (scheduled or triggered) |
| Score artefact pairs | Autonomous |
| Flag contradictions | Autonomous |
| Recommend remediation | Autonomous (recommendation only) |
| Modify artefact content | NOT PERMITTED |
| Accept risk on contradiction | NOT PERMITTED -- requires human authority |

### Human Override Rules

- Humans may suppress specific contradiction flags with documented justification
- Suppressed flags are tracked separately and reviewed at each gate
- Suppression expires at the next stage-gate boundary unless renewed

### Audit Logging Requirements

- Log every scan execution with scope, duration, and results summary
- Log every contradiction detected with severity and affected artefacts
- Log every suppression with authority and justification
- Log trend data for longitudinal analysis

---

## 3. Drift Detection Agent

**Purpose**: Monitor and alert on semantic, terminological, behavioural, and schema drift across the managed configuration.

### Inputs

| Input | Source | Format |
|-------|--------|--------|
| Current artefact state | Baseline registry | Artefact content snapshots |
| Baselined artefact state | Baseline archive | Frozen baseline content |
| AI model outputs | Model deployment | Output samples/logs |
| Behavioural profiles | Model registry | Baselined behaviour metrics |
| Domain model | Domain model registry | Current canonical model |
| Terminology register | Domain governance | Canonical term definitions |

### Outputs

| Output | Consumer | Format |
|--------|----------|--------|
| Drift alerts | CM team, CCB, artefact owners | Categorised alert (terminology/schema/behaviour/domain) |
| Drift severity score | Gate Reconciliation Agent | Numeric score per category |
| Drift trend report | CM team, Program Director | Longitudinal trend data |
| Stability indices | Metrics dashboard | TSI, schema alignment %, behaviour conformance % |
| Incident triggers | Incident management | Incident creation event (for high-severity drift) |

### Decision Authority

| Action | Authority Level |
|--------|----------------|
| Execute drift scan | Autonomous (continuous or scheduled) |
| Calculate drift scores | Autonomous |
| Raise drift alerts | Autonomous |
| Trigger incident for high severity | Autonomous (within configured thresholds) |
| Modify baselines | NOT PERMITTED |
| Adjust drift thresholds | NOT PERMITTED -- requires CM authority |
| Accept drift as intentional | NOT PERMITTED -- requires human authority + CR |

### Human Override Rules

- Drift thresholds can only be modified by CM authority with documented rationale
- Intentional drift (e.g., planned terminology change) must be registered as a CR before the change, not retroactively
- False positive alerts can be suppressed per-instance with justification; pattern suppression requires CM authority

### Audit Logging Requirements

- Log every scan with timestamp, scope, and per-category results
- Log every alert raised with severity, category, and affected elements
- Log every threshold modification with authority
- Log every suppression with justification
- Retain drift trend data for minimum 12 months

---

## 4. Impact Analysis Agent

**Purpose**: Compute and present the full impact chain of proposed or detected changes.

### Inputs

| Input | Source | Format |
|-------|--------|--------|
| Change Request | CR workflow | CR record with proposed change detail |
| Traceability graph | Traceability engine | Directed graph of element relationships |
| Baseline registry | CM system | Current and historical baselines |
| Domain model | Domain model registry | Canonical model with relationships |
| Dependency maps | Build/deployment system | Artefact dependency graph |

### Outputs

| Output | Consumer | Format |
|--------|----------|--------|
| Impact report | CCB, CR requestor, CM team | Structured report (direct + transitive impacts) |
| Risk assessment | CCB, Risk manager | Impact-severity matrix |
| Alternative analysis | CCB | Scored option comparison |
| Effort estimate | Project management | Estimated scope of change |
| Affected artefact list | Artefact owners | Notification list |

### Decision Authority

| Action | Authority Level |
|--------|----------------|
| Compute impact chain | Autonomous |
| Score impact severity | Autonomous |
| Generate alternatives | Autonomous |
| Recommend preferred alternative | Autonomous (recommendation only) |
| Approve change | NOT PERMITTED -- routes to CCB |
| Modify scope of analysis | NOT PERMITTED -- scope set by CR |

### Human Override Rules

- Humans may request expanded or narrowed analysis scope
- Alternative recommendations are advisory; selection is human authority only
- Impact severity scores may be overridden by CCB with documented rationale

### Audit Logging Requirements

- Log every impact analysis with CR reference, scope, and results
- Log every alternative generated with scoring rationale
- Log every human override of severity scores
- Link all logs to the originating CR

---

## 5. Gate Reconciliation Agent

**Purpose**: Execute comprehensive reconciliation checks at stage-gate boundaries and produce gate readiness assessments.

### Inputs

| Input | Source | Format |
|-------|--------|--------|
| Gate definition | Lifecycle model | Gate criteria, required artefacts, thresholds |
| Artefact registry | CM system | All managed artefacts with status |
| Consistency results | Artefact Consistency Auditor | Latest consistency matrix |
| Drift results | Drift Detection Agent | Latest drift scores |
| Traceability status | Traceability engine | Completeness percentages |
| Open CRs | CR workflow | List of open CRs with status |
| Open incidents | Incident system | List of open incidents |

### Outputs

| Output | Consumer | Format |
|--------|----------|--------|
| Gate readiness report | CCB | Structured checklist with pass/warn/fail per criterion |
| Reconciliation evidence pack | CCB, Compliance | Aggregated evidence from all checks |
| Block/proceed recommendation | CCB | Advisory recommendation with rationale |
| Deficiency list | Artefact owners, CM team | Itemised list of gaps with remediation guidance |
| Gate decision record | Audit trail | Decision, authority, conditions, timestamp |

### Decision Authority

| Action | Authority Level |
|--------|----------------|
| Execute all gate checks | Autonomous |
| Produce readiness report | Autonomous |
| Recommend block/proceed | Autonomous (recommendation only) |
| Approve gate passage | NOT PERMITTED -- requires CCB authority |
| Grant override/waiver | NOT PERMITTED -- requires CCB or Program Director |
| Modify gate criteria | NOT PERMITTED -- requires lifecycle governance authority |

### Human Override Rules

- Gate passage decision is exclusively human (CCB or designated authority)
- CCB may approve with conditions (documented as risk acceptance)
- Conditional approval must specify: conditions, deadline, responsible party, consequence of non-compliance
- Override of a `fail` status requires escalation path per FR-C05

### Audit Logging Requirements

- Log complete gate check execution with all input data references
- Log every criterion result (pass/warn/fail) with supporting evidence
- Log the gate decision (approved/blocked/conditional) with authority
- Log all conditions attached to conditional approvals
- Log condition fulfilment or violation at subsequent checkpoints

---

## Common Agent Governance Rules

### Separation of Duties

- No single agent may both propose and approve a configuration change
- Agents that detect issues (Drift Detection, Consistency Auditor) must not also remediate them
- The Configuration Manager Agent orchestrates but does not override other agents' findings

### Fail-Safe Behaviour

- If an agent cannot complete its analysis, it shall report `incomplete` (not `pass`)
- `incomplete` status blocks gate progression the same as `fail`
- Agent failures shall be logged as operational incidents

### Inter-Agent Communication

- Agents communicate through the shared baseline registry and event bus
- No direct agent-to-agent modification of state
- All inter-agent data exchange is logged and auditable

### Human Escalation Triggers

Any agent shall escalate to human authority when:

- A decision exceeds its authority level
- Contradictory results are produced by multiple agents
- An anomaly falls outside configured detection rules
- Resource constraints prevent timely analysis completion
