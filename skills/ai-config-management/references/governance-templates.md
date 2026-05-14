# Governance Templates

## Table of Contents

- [RACI/RASIC Matrix Template](#racirasic-matrix-template)
- [Change Request Template](#change-request-template)
- [Gate Readiness Checklist Template](#gate-readiness-checklist-template)
- [Incident Record Template](#incident-record-template)
- [Risk Register Entry Template](#risk-register-entry-template)
- [Decision Container Template](#decision-container-template)
- [Baseline Manifest Template](#baseline-manifest-template)
- [Context Health Report Template](#context-health-report-template)

---

## RACI/RASIC Matrix Template

Use RASIC when supportive and consultative distinctions matter. Use RACI when simpler governance suffices.

```
| Activity | Role 1 | Role 2 | Role 3 | Agent 1 | Agent 2 |
|----------|--------|--------|--------|---------|---------|
| [activity] | R/A/S/I/C | ... | ... | ... | ... |
```

**Legend**:
- **R** (Responsible): Performs the work
- **A** (Accountable): Approves and is ultimately answerable (one per activity)
- **S** (Supportive): Provides resources or assistance
- **I** (Informed): Kept informed of progress/outcome
- **C** (Consulted): Provides input before action

**Rules**:
- Every activity must have exactly one **A**
- AI agents may be **R** or **S** but never **A**
- **A** must always be a human role

---

## Change Request Template

```yaml
cr_id:                CR-{sequence}
title:                [Concise description of proposed change]
type:                 minor | moderate | major | critical
status:               submitted | under_review | approved | rejected | deferred | implemented | verified | closed
requestor:
  name:               [Name]
  role:               [Role]
  date:               [ISO 8601]

justification:        [Why this change is needed]
affected_artefacts:
  - artefact_id:      [ART-xxx]
    impact_type:      direct | transitive
affected_baselines:
  - baseline_id:      [BL-xxx]

urgency:              routine | urgent | emergency
risk_assessment:      [Brief risk statement]

impact_analysis:
  analysis_id:        [Reference to Impact Analysis Agent output]
  direct_impacts:     [Count]
  transitive_impacts: [Count]
  domain_impacts:     [Count]
  ai_impacts:         [Count]

disposition:
  decision:           approved | rejected | deferred | modify_and_resubmit
  authority:          [Name and role]
  date:               [ISO 8601]
  conditions:         [Any conditions attached]
  risk_acceptance:    [If overriding a warning/failure]

implementation:
  implementor:        [Name]
  started:            [ISO 8601]
  completed:          [ISO 8601]

verification:
  reconciliation:     pass | fail
  consistency_check:  pass | fail
  traceability_check: pass | fail
  verifier:           [Name]
  date:               [ISO 8601]

closure:
  closed_by:          [Name]
  date:               [ISO 8601]
  new_baseline_id:    [BL-xxx]
```

---

## Gate Readiness Checklist Template

```yaml
gate_id:              GATE-{from}-{to}-{seq}
requested_by:         [Name and role]
date_requested:       [ISO 8601]

stage_from:           [Current stage]
stage_to:             [Target stage]

checks:
  domain_reconciliation:
    status:           pass | warn | fail | incomplete
    details:          [Summary]
    agent:            Gate Reconciliation Agent

  artefact_consistency:
    status:           pass | warn | fail | incomplete
    coherence_score:  [ACS value]
    contradictions:   [Count]
    agent:            Artefact Consistency Auditor Agent

  drift_scan:
    terminology:
      status:         pass | warn | fail
      tsi:            [Value]
    schema:
      status:         pass | warn | fail
      sas:            [Value]
    behaviour:
      status:         pass | warn | fail
      abcs:           [Value]
    prompt:
      status:         pass | warn | fail
      pis:            [Value]
    agent:            Drift Detection Agent

  traceability:
    status:           pass | warn | fail
    completeness:     [TCP value]%
    gaps:             [Count of untraceable elements]

  open_change_requests:
    count:            [Number]
    deferred_with_approval: [Number]
    status:           pass | fail

  open_incidents:
    count:            [Number]
    high_severity:    [Number]
    status:           pass | warn | fail

  required_artefacts:
    present:          [Count]
    missing:          [List]
    status:           pass | fail

overall_recommendation: proceed | proceed_with_conditions | block
conditions:           [If conditional, list conditions]
deficiencies:         [If blocked, list deficiencies]

decision:
  outcome:            approved | conditional | blocked
  authority:          [Name and role]
  date:               [ISO 8601]
  conditions:         [If conditional]
  risk_acceptance:    [If overriding warnings]
```

---

## Incident Record Template

```yaml
incident_id:          INC-{sequence}
timestamp:            [ISO 8601]
severity:             low | medium | high | critical
type:                 ai_behavioural | configuration_breach | governance_violation | system_failure
status:               open | investigating | contained | remediated | closed

detection:
  detected_by:        [Agent name or human]
  detection_method:   [Scan type, alert, manual observation]

description:          [What happened]

affected:
  artefacts:
    - artefact_id:    [ART-xxx]
  agents:
    - agent_id:       [Agent identifier]
  baselines:
    - baseline_id:    [BL-xxx]

containment:
  action:             [What was done to contain]
  by:                 [Who/what performed containment]
  timestamp:          [ISO 8601]

investigation:
  root_cause:         [Identified root cause]
  contributing_factors: [List]
  investigator:       [Name]

remediation:
  action:             [What was done to fix]
  cr_reference:       [CR-xxx if applicable]
  by:                 [Who performed remediation]
  timestamp:          [ISO 8601]

verification:
  reconciliation:     pass | fail
  drift_scan:         pass | fail
  verifier:           [Name]
  timestamp:          [ISO 8601]

closure:
  closed_by:          [Name]
  date:               [ISO 8601]
  lessons_learned:    [Key takeaways]
  preventive_actions: [What will prevent recurrence]
```

---

## Risk Register Entry Template

```yaml
risk_id:              RSK-{sequence}
title:                [Concise risk statement]
category:             governance | technical | operational | compliance | ai_specific
status:               identified | assessed | mitigated | accepted | closed

description:          [Detailed risk scenario]

assessment:
  likelihood:         1-5  # 1=Rare, 5=Almost certain
  impact:             1-5  # 1=Negligible, 5=Catastrophic
  risk_score:         [likelihood x impact]

mitigation:
  strategy:           avoid | reduce | transfer | accept
  controls:           [List of planned controls]
  owner:              [Name and role]
  target_date:        [ISO 8601]

residual:
  likelihood:         1-5
  impact:             1-5
  residual_score:     [likelihood x impact]

review:
  last_reviewed:      [ISO 8601]
  next_review:        [ISO 8601]
  review_trigger:     [Condition prompting re-assessment]

traces_to:
  requirements:       [FR-xxx list]
  artefacts:          [ART-xxx list]
  incidents:          [INC-xxx list if materialised]
```

---

## Decision Container Template

```yaml
decision_id:          DCN-{sequence}
title:                [Concise decision statement]
status:               proposed | accepted | superseded | rejected

context:              [Problem statement and constraints]
decision:             [What was decided]
rationale:            [Why this option was chosen]

alternatives:
  - option:           [Description]
    pros:             [List]
    cons:             [List]
    risk_profile:     [Brief risk assessment]

authority:
  decided_by:         [Name and role]
  forum:              [Designated decision forum]
  date:               [ISO 8601]

impacts:
  artefacts:          [ART-xxx list]
  baselines:          [BL-xxx list]
  requirements:       [FR-xxx list]

traces_to:
  requirements:       [Upstream requirements]
  decisions:          [Related decisions]

supersedes:           [DCN-xxx if replacing a previous decision]
review_trigger:       [Conditions that would reopen this decision]
```

---

## Baseline Manifest Template

```yaml
baseline_id:          BL-{sequence}
artefact_id:          ART-{type}-{sequence}
version:              {major}.{minor}.{patch}
status:               baselined | frozen | superseded

created:
  timestamp:          [ISO 8601]
  author:             [Name]
  authority:          [Approving authority]

content:
  hash:               [SHA-256]
  location:           [Storage reference]

provenance:
  cr_reference:       [CR-xxx, null for initial baseline]
  supersedes:         [BL-xxx, null for initial]
  domain_model_ref:   [DM-{version}]
  stage:              [Lifecycle stage at creation]

dependencies:
  - artefact_id:      [ART-xxx]
    baseline_id:      [BL-xxx]
    version:          [x.y.z]

freeze:
  frozen_at:          [ISO 8601, null if not frozen]
  frozen_by:          [Authority, null if not frozen]
  gate_reference:     [GATE-xxx, null if not gate-triggered]
```

---

## Context Health Report Template

```yaml
report_id:            CHR-{sequence}
period:               [Start date] to [End date]
generated:            [ISO 8601]

metrics:
  tsi:                [Value]  # Terminology Stability Index
  acs:                [Value]  # Artefact Coherence Score
  dfr:                [Value]  # Drift Frequency Rate
  grr:                [Value]  # Gate Rejection Rate
  usci:               [Count]  # Unauthorised Scope Change Incidents
  tcp:                [Value]% # Traceability Completeness
  abcs:               [Value]  # AI Behaviour Conformance Score
  sas:                [Value]  # Schema Alignment Score
  pis:                [Value]  # Prompt Integrity Score
  crct:               [Value]  # Change Request Cycle Time (days)

derived:
  chi:                [Value]  # Context Health Index
  err:                [Value]  # Entropy Reduction Rate
  gci:                [Value]  # Governance Compliance Index

trend:
  chi_previous:       [Value]
  chi_delta:          [Value]
  direction:          improving | stable | degrading

alerts:
  total_raised:       [Count]
  by_severity:
    info:             [Count]
    warning:          [Count]
    high:             [Count]
    critical:         [Count]

top_issues:
  - issue:            [Description]
    metric:           [Affected metric]
    severity:         [Level]
    remediation:      [Planned action]

recommendations:      [Prioritised list]
```
