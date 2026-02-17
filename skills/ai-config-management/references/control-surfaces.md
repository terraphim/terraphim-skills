# Control Surfaces and Baselines

## Table of Contents

- [Control Surface Registry](#control-surface-registry)
- [Baseline Rules Per Surface](#baseline-rules-per-surface)
- [Freeze Conditions](#freeze-conditions)
- [Re-Baselining Protocol](#re-baselining-protocol)
- [Version Trace Model](#version-trace-model)

---

## Control Surface Registry

Each major artefact type is a **control surface** -- a managed boundary across which configuration integrity must be maintained. The system treats each surface as an independently versioned, baselined, and governed entity with defined relationships to other surfaces.

| # | Control Surface | Artefact Type ID | Primary Owner | Governance Level |
|---|----------------|-------------------|---------------|-----------------|
| 1 | Domain Model | `domain_model` | Domain Architect | L4-controlled |
| 2 | Business Scenarios | `business_scenario` | Business Analyst | L3-approved |
| 3 | Process Models | `process_model` | Process Engineer | L3-approved |
| 4 | Data Schema | `data_schema` | Data Architect | L4-controlled |
| 5 | API Contracts | `api_contract` | API Owner / Integration Architect | L4-controlled |
| 6 | AI Use Cases | `ai_use_case` | AI Product Owner | L3-approved |
| 7 | UX Flows | `ux_flow` | UX Lead | L3-approved |
| 8 | Prompt Specifications | `prompt_spec` | AI Engineer / Prompt Engineer | L4-controlled |
| 9 | Model Specifications | `model_spec` | ML Engineer / AI Architect | L4-controlled |
| 10 | Risk Registers | `risk_register` | Risk Manager | L3-approved |

---

## Baseline Rules Per Surface

### 1. Domain Model

- **Baseline trigger**: Stage-gate transition or CCB-approved domain model release
- **Baseline content**: Entity definitions, relationship schema, event taxonomy, enumeration values, version metadata
- **Dependencies**: All other surfaces depend on this; domain model baseline change triggers re-validation cascade
- **Minimum baseline frequency**: Once per lifecycle stage

### 2. Business Scenarios

- **Baseline trigger**: Stage-gate transition (Discovery -> Define) or business scenario approval
- **Baseline content**: Scenario narratives, actor definitions, trigger conditions, expected outcomes, domain entity references
- **Dependencies**: Domain Model (entity references), AI Use Cases (scenario-to-use-case mapping)
- **Minimum baseline frequency**: Once per stage; updated when scope changes are approved

### 3. Process Models

- **Baseline trigger**: Design stage completion or process model approval
- **Baseline content**: Process definitions (BPMN or equivalent), decision points, integration points, SLA definitions
- **Dependencies**: Domain Model, Business Scenarios, API Contracts
- **Minimum baseline frequency**: Once per stage from Define onward

### 4. Data Schema

- **Baseline trigger**: Design stage completion or data schema release
- **Baseline content**: Entity-relationship diagrams, field definitions, constraints, indexes, migration scripts
- **Dependencies**: Domain Model (must conform), API Contracts (must align)
- **Minimum baseline frequency**: Once per stage from Design onward; additional baselines for migration events

### 5. API Contracts

- **Baseline trigger**: Design stage completion or API version release
- **Baseline content**: OpenAPI/AsyncAPI specifications, authentication schemes, rate limits, error codes, versioning policy
- **Dependencies**: Domain Model (entity alignment), Data Schema (payload alignment)
- **Minimum baseline frequency**: Per API version release

### 6. AI Use Cases

- **Baseline trigger**: Define stage completion or use case approval
- **Baseline content**: Use case description, input/output specifications, success criteria, boundary conditions, domain entity references, associated prompt specs
- **Dependencies**: Domain Model, Business Scenarios, Prompt Specifications
- **Minimum baseline frequency**: Once per stage from Define onward

### 7. UX Flows

- **Baseline trigger**: Design stage completion or UX review approval
- **Baseline content**: Screen flows, interaction patterns, accessibility requirements, content specifications, API integration points
- **Dependencies**: API Contracts (integration), Business Scenarios (user journeys)
- **Minimum baseline frequency**: Once per stage from Design onward

### 8. Prompt Specifications

- **Baseline trigger**: Design stage completion, model version change, or prompt engineering review
- **Baseline content**: Prompt text, variable definitions, model target, expected output format, guard rails, test cases, domain model version reference
- **Dependencies**: Domain Model (terminology), Model Specifications (compatibility), AI Use Cases (behaviour alignment)
- **Minimum baseline frequency**: Per prompt version; mandatory re-baseline on model version change

### 9. Model Specifications

- **Baseline trigger**: Model selection, model version update, or model retraining
- **Baseline content**: Model identifier, version, provider, capability boundaries, training data reference, benchmark results, deployment constraints, approved contexts
- **Dependencies**: Training data configuration, Prompt Specifications (compatibility)
- **Minimum baseline frequency**: Per model version; mandatory re-baseline on retraining

### 10. Risk Registers

- **Baseline trigger**: Stage-gate transition or significant risk event
- **Baseline content**: Risk items (description, likelihood, impact, mitigation, owner, status), risk scoring methodology, threshold definitions
- **Dependencies**: All surfaces (risks may reference any artefact)
- **Minimum baseline frequency**: Once per stage; updated on risk events or CR approvals

---

## Freeze Conditions

A control surface enters **frozen** state when:

1. It has been baselined at a stage-gate boundary
2. The stage gate has been approved by CCB
3. No open CRs exist against the surface

While frozen:

- No modifications permitted without an approved CR
- Read access unrestricted
- Automated scans continue (drift detection, consistency auditing)
- Any detected modification without CR triggers a configuration breach incident

### Freeze Exceptions

| Exception | Authority | Condition |
|-----------|-----------|-----------|
| Emergency fix | Program Director | Critical production incident; CR created retrospectively within 24 hours |
| Regulatory mandate | Compliance Officer + CCB | External regulatory requirement with documented mandate |
| Security vulnerability | Security Officer + CCB | Active security threat requiring immediate remediation |

All exceptions are logged and reviewed at the next CCB meeting.

---

## Re-Baselining Protocol

When a frozen baseline must be updated:

1. **CR Approval**: An approved CR authorising the change must exist
2. **Impact Analysis**: Impact Analysis Agent has completed analysis; results reviewed by CCB
3. **Implementation**: Changes applied to artefact content
4. **Reconciliation**: Domain model reconciliation executed; consistency checks passed
5. **Validation**: Affected test cases re-executed; traceability verified
6. **New Baseline**: New baseline created with:
   - Incremented version number
   - Reference to originating CR
   - Delta from previous baseline
   - Updated dependency references
7. **Supersession**: Previous baseline marked `superseded` (not deleted)
8. **Notification**: All dependent surface owners notified of re-baseline
9. **Cascade Check**: Dependent surfaces assessed for required updates

---

## Version Trace Model

Every baselined artefact carries a version trace:

```
version_trace:
  artefact_id:          ART-{type}-{sequence}
  version:              {major}.{minor}.{patch}
  baseline_id:          BL-{sequence}
  created:              ISO 8601 timestamp
  author:               Named individual
  authority:            Approving authority (role + name)
  cr_reference:         CR-{sequence} (null for initial baseline)
  supersedes:           Previous baseline_id (null for initial)
  domain_model_version: DM-{version}
  content_hash:         SHA-256 of artefact content
  dependency_snapshot:  List of (artefact_id, version) pairs for all dependencies
  stage:                Lifecycle stage at baseline creation
  status:               baselined | frozen | superseded
```

### Version Numbering Convention

- **Major**: Semantic change (entity added/removed, relationship changed, interface modified)
- **Minor**: Content enrichment within existing semantic boundaries
- **Patch**: Correction of errors without semantic change

### Trace Relationships

```
Baseline N (frozen)
  |
  +-- superseded by --> Baseline N+1 (via CR-xxx)
  |                       |
  |                       +-- depends on --> [dependency baselines]
  |
  +-- depends on --> [dependency baselines at time of freeze]
```

All trace relationships are immutable once recorded. Historical traces enable reconstruction of any past configuration state.
