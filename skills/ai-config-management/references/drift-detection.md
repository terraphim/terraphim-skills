# Drift Detection Framework

## Table of Contents

- [Drift Categories](#drift-categories)
- [Detection Mechanisms](#detection-mechanisms)
- [Scoring and Thresholds](#scoring-and-thresholds)
- [Alert and Response Protocol](#alert-and-response-protocol)
- [Continuous Monitoring Architecture](#continuous-monitoring-architecture)

---

## Drift Categories

The framework defines four primary drift categories, each with distinct detection mechanisms and severity implications.

### 1. Terminology Drift

**Definition**: Divergence of terms used in artefacts from the canonical terminology register.

**Sources**:
- Natural language variation in authored artefacts
- Stakeholder-introduced synonyms or abbreviations
- Cross-team vocabulary divergence
- Vendor-specific terminology infiltrating domain language

**Risk**: Ambiguity in requirements, misinterpretation of specifications, inconsistent AI behaviour.

### 2. Domain Schema Drift

**Definition**: Structural divergence between implementation schemas and the canonical domain model.

**Sources**:
- Implementation shortcuts (adding fields without domain model update)
- Database migrations not reflected in domain model
- API contract evolution outpacing domain model versioning
- Legacy system integration introducing non-canonical entities

**Risk**: Data inconsistency, integration failures, untraceable data flows.

### 3. AI Behavioural Drift

**Definition**: Deviation of AI agent outputs from baselined behaviour profiles.

**Sources**:
- Model version updates (provider-side or internal)
- Prompt degradation over evolving context
- Training data distribution shift
- Environmental changes (API responses, data formats)

**Risk**: Unpredictable outputs, boundary exceedances, governance violations.

### 4. Prompt Drift

**Definition**: Divergence between prompt specifications as authored and prompts as deployed/executed.

**Sources**:
- Manual prompt edits in deployment without CR
- Template variable resolution producing unintended content
- Context window truncation altering effective prompt
- Prompt chaining introducing uncontrolled intermediate state

**Risk**: Non-reproducible AI behaviour, untraceable decision paths.

---

## Detection Mechanisms

### Terminology Drift Detection

1. **Canonical Register Maintenance**
   - Extract all defined terms from the domain model (entities, events, attributes, enumerations)
   - Maintain a register: `{term, definition, aliases[], status}`
   - Aliases must be explicitly registered; unregistered variants are drift candidates

2. **Artefact Scanning**
   - Parse all textual content in managed artefacts
   - Tokenize and match against canonical register
   - Compute edit distance and semantic similarity for near-matches
   - Flag tokens that are similar to canonical terms but not registered as aliases

3. **Scoring**
   - Per-artefact: count of unregistered variants / total domain term occurrences
   - Cross-artefact: number of distinct unregistered variants for the same canonical term

### Domain Schema Drift Detection

1. **Schema Extraction**
   - Parse data schemas from: database DDL, API contracts (OpenAPI), message formats (AsyncAPI/Protobuf), data models
   - Normalise to a common representation: `{entity, field, type, constraints, relationships}`

2. **Canonical Comparison**
   - Diff extracted schemas against canonical domain model
   - Detect: missing entities, extra entities, type mismatches, missing constraints, relationship divergence

3. **Scoring**
   - Alignment percentage: (matching fields / total canonical fields) x 100
   - Divergence count: number of non-canonical elements in implementation

### AI Behavioural Drift Detection

1. **Behaviour Profile Baselining**
   - At each model/prompt baseline, capture:
     - Output format distribution (JSON structure, field presence)
     - Confidence/probability distributions
     - Response length distribution
     - Boundary test results (what the model refuses/accepts)
     - Latency distribution

2. **Runtime Monitoring**
   - Sample model outputs at configurable rate (default: 10% of production traffic)
   - Compute same metrics as baseline profile
   - Statistical comparison (KL divergence, chi-squared, or equivalent)

3. **Scoring**
   - Per-metric deviation: z-score or percentile rank against baseline distribution
   - Composite drift score: weighted average across all metrics
   - Boundary conformance: binary (within/outside defined boundaries)

### Prompt Drift Detection

1. **Prompt Hash Tracking**
   - Hash the effective prompt (post-variable-resolution) at execution time
   - Compare against baselined prompt hash
   - Flag any mismatch

2. **Template Integrity Verification**
   - Verify prompt templates match baselined versions
   - Check variable resolution logic for consistency
   - Detect context window truncation events

3. **Scoring**
   - Binary: matches baseline (0) or does not (1)
   - Severity: classified by degree of deviation (cosmetic/structural/semantic)

---

## Scoring and Thresholds

### Terminology Stability Index (TSI)

```
TSI = 1 - (unregistered_variants / total_domain_term_occurrences)
```

| TSI Range | Status | Action |
|-----------|--------|--------|
| 0.95 - 1.00 | Healthy | No action |
| 0.85 - 0.94 | Warning | Review and register intentional variants or correct unintentional ones |
| 0.70 - 0.84 | Degraded | Mandatory remediation before next gate |
| < 0.70 | Critical | Immediate terminology reconciliation required |

### Schema Alignment Score (SAS)

```
SAS = matching_fields / total_canonical_fields
```

| SAS Range | Status | Action |
|-----------|--------|--------|
| 0.95 - 1.00 | Aligned | No action |
| 0.85 - 0.94 | Minor drift | CR required for next stage |
| 0.70 - 0.84 | Significant drift | Blocks deployment |
| < 0.70 | Critical misalignment | Blocks all progression |

### AI Behaviour Conformance Score (ABCS)

```
ABCS = metrics_within_threshold / total_monitored_metrics
```

| ABCS Range | Status | Action |
|------------|--------|--------|
| 0.90 - 1.00 | Conformant | No action |
| 0.75 - 0.89 | Deviation detected | Investigation required; incident if boundary metric fails |
| 0.50 - 0.74 | Significant deviation | Model quarantine; immediate incident |
| < 0.50 | Critical deviation | Model suspension; emergency CCB review |

### Prompt Integrity Score (PIS)

| Status | Condition | Action |
|--------|-----------|--------|
| Intact | Hash matches baseline | No action |
| Modified | Hash mismatch, cosmetic change | Warning; CR required |
| Compromised | Hash mismatch, structural/semantic change | Incident; prompt rollback to baseline |

---

## Alert and Response Protocol

### Alert Severity Levels

| Level | Trigger | Response Time | Notification |
|-------|---------|---------------|-------------|
| Info | Score crosses healthy->warning threshold | Next business day | Artefact owner |
| Warning | Score crosses warning->degraded threshold | 24 hours | Artefact owner + CM team |
| High | Score crosses degraded->critical threshold | 4 hours | CCB + artefact owner + CM team |
| Critical | Boundary exceedance or prompt compromise | Immediate | CCB + Program Director + all affected owners |

### Response Actions

1. **Investigate**: Identify root cause of drift
2. **Classify**: Intentional (requires CR) or unintentional (requires remediation)
3. **Contain**: If unintentional, isolate affected artefacts or suspend affected AI components
4. **Remediate**: Apply fixes via CR workflow
5. **Verify**: Re-run drift detection to confirm resolution
6. **Close**: Document resolution and update incident record

---

## Continuous Monitoring Architecture

### Scan Schedule

| Drift Category | Scan Frequency | Trigger Events |
|---------------|----------------|----------------|
| Terminology | Daily (batch) | Artefact submission, domain model update |
| Domain Schema | On change + daily | Schema deployment, API contract update |
| AI Behaviour | Continuous (sampled) | Model deployment, prompt update, anomaly detection |
| Prompt | On execution + daily | Prompt deployment, template update |

### Data Flow

```
Artefact Registry --> Drift Detection Agent --> Alert Engine --> Notification System
       |                      |                      |
       v                      v                      v
  Baseline Archive    Drift Score History    Incident System
                              |
                              v
                     Metrics Dashboard
                     (TSI, SAS, ABCS, PIS)
```

### Retention

- Drift scores: minimum 12 months (for trend analysis)
- Alert records: minimum 7 years (for audit)
- Scan execution logs: minimum 12 months
- Baseline comparisons: retained as long as both baselines exist
