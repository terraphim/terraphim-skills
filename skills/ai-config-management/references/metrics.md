# Metrics and Context Health Indicators

## Table of Contents

- [Core Metrics](#core-metrics)
- [Derived Indicators](#derived-indicators)
- [Reporting Cadence](#reporting-cadence)
- [Threshold Escalation Matrix](#threshold-escalation-matrix)

---

## Core Metrics

### M01: Terminology Stability Index (TSI)

**Formula**: `1 - (unregistered_variants / total_domain_term_occurrences)`

**Scope**: All managed artefacts against canonical terminology register.

**Collection**: Daily batch scan by Drift Detection Agent.

| Range | Status |
|-------|--------|
| 0.95-1.00 | Healthy |
| 0.85-0.94 | Warning |
| 0.70-0.84 | Degraded |
| < 0.70 | Critical |

---

### M02: Artefact Coherence Score (ACS)

**Formula**: `1 - (mean_pairwise_semantic_variance)`

Where mean pairwise semantic variance is the average of all artefact-pair consistency scores produced by the Artefact Consistency Auditor Agent.

**Scope**: All baselined artefact pairs.

**Collection**: After each consistency audit scan.

| Range | Status |
|-------|--------|
| 0.90-1.00 | Coherent |
| 0.75-0.89 | Minor inconsistency |
| 0.60-0.74 | Significant inconsistency |
| < 0.60 | Incoherent |

---

### M03: Drift Frequency Rate (DFR)

**Formula**: `drift_alerts_raised / scan_cycles` (per drift category, per reporting period)

**Scope**: Per drift category (terminology, schema, behaviour, prompt).

**Collection**: Aggregated from Drift Detection Agent alert log.

| Rate | Status |
|------|--------|
| < 0.05 | Stable |
| 0.05-0.15 | Elevated |
| 0.15-0.30 | Unstable |
| > 0.30 | Critical |

---

### M04: Gate Rejection Rate (GRR)

**Formula**: `gates_blocked_or_conditional / total_gate_attempts` (per reporting period)

**Scope**: All stage-gate transitions.

**Collection**: Gate Reconciliation Agent decision log.

| Rate | Status |
|------|--------|
| < 0.10 | Healthy process |
| 0.10-0.25 | Process friction |
| 0.25-0.50 | Systemic quality issues |
| > 0.50 | Process failure |

---

### M05: Unauthorised Scope Change Incidents (USCI)

**Formula**: `count of artefact modifications lacking traceable CR or approved authority` (per reporting period)

**Scope**: All managed artefacts.

**Collection**: Configuration Manager Agent governance violation log.

| Count | Status |
|-------|--------|
| 0 | Compliant |
| 1-3 | Warning |
| 4-10 | Governance breakdown |
| > 10 | Critical governance failure |

---

### M06: Traceability Completeness Percentage (TCP)

**Formula**: `(traced_elements / total_traceable_elements) x 100`

Where traced elements are those with both forward and backward trace links.

**Scope**: Requirements, design elements, code modules, test cases, AI use cases, prompt specs.

**Collection**: Traceability engine computation at each gate and on demand.

| Percentage | Status |
|------------|--------|
| 95-100% | Complete |
| 85-94% | Acceptable (gate passage with warning) |
| 70-84% | Incomplete (blocks gate) |
| < 70% | Critical gap |

---

### M07: AI Behaviour Conformance Score (ABCS)

**Formula**: `metrics_within_threshold / total_monitored_metrics`

**Scope**: Per AI agent, per model deployment.

**Collection**: Continuous sampling by Drift Detection Agent.

| Range | Status |
|-------|--------|
| 0.90-1.00 | Conformant |
| 0.75-0.89 | Deviation detected |
| 0.50-0.74 | Significant deviation |
| < 0.50 | Critical deviation |

---

### M08: Schema Alignment Score (SAS)

**Formula**: `matching_fields / total_canonical_fields`

**Scope**: Per implementation schema against canonical domain model.

**Collection**: On schema change + daily scan.

| Range | Status |
|-------|--------|
| 0.95-1.00 | Aligned |
| 0.85-0.94 | Minor drift |
| 0.70-0.84 | Significant drift |
| < 0.70 | Critical misalignment |

---

### M09: Prompt Integrity Score (PIS)

**Formula**: Binary per prompt (intact/modified/compromised), aggregated as `intact_prompts / total_managed_prompts`

**Scope**: All managed prompt specifications.

**Collection**: On prompt execution + daily scan.

| Aggregate | Status |
|-----------|--------|
| 1.00 | All intact |
| 0.90-0.99 | Minor modifications detected |
| 0.75-0.89 | Multiple modifications |
| < 0.75 | Widespread prompt drift |

---

### M10: Change Request Cycle Time (CRCT)

**Formula**: `mean(CR_closure_date - CR_submission_date)` (per severity level)

**Scope**: All closed CRs in reporting period.

**Collection**: CR workflow system.

| Severity | Target Cycle Time |
|----------|-------------------|
| Minor | 5 business days |
| Moderate | 10 business days |
| Major | 20 business days |
| Critical | 2 business days |

---

## Derived Indicators

### D01: Context Health Index (CHI)

**Formula**: Weighted composite of core metrics.

```
CHI = (w1 x TSI) + (w2 x ACS) + (w3 x (1 - DFR)) + (w4 x (1 - GRR)) + (w5 x TCP/100) + (w6 x ABCS) + (w7 x SAS) + (w8 x PIS)
```

Default weights (sum = 1.0):

| Weight | Metric | Value |
|--------|--------|-------|
| w1 | TSI | 0.10 |
| w2 | ACS | 0.15 |
| w3 | 1-DFR | 0.10 |
| w4 | 1-GRR | 0.10 |
| w5 | TCP | 0.15 |
| w6 | ABCS | 0.15 |
| w7 | SAS | 0.10 |
| w8 | PIS | 0.15 |

| CHI Range | Status |
|-----------|--------|
| 0.90-1.00 | Healthy context |
| 0.75-0.89 | Attention required |
| 0.60-0.74 | At risk |
| < 0.60 | Context integrity failure |

### D02: Entropy Reduction Rate (ERR)

**Formula**: `(CHI_current - CHI_previous) / time_delta`

Positive values indicate improving context health. Negative values indicate increasing entropy.

### D03: Governance Compliance Index (GCI)

**Formula**: `1 - (USCI / total_configuration_changes)`

Measures the proportion of configuration changes that followed proper governance.

---

## Reporting Cadence

| Report | Audience | Frequency | Content |
|--------|----------|-----------|---------|
| Context Health Dashboard | CM team, CCB | Continuous (live) | All core metrics, CHI, trend lines |
| Weekly Context Health Summary | Program Director, CCB | Weekly | CHI trend, top 5 drift alerts, open incidents, GRR |
| Gate Readiness Report | CCB | Per gate attempt | All metrics relevant to gate criteria |
| Monthly Governance Report | Enterprise Architecture Board | Monthly | GCI, USCI, ERR, cross-program comparison |
| Quarterly Trend Analysis | Executive sponsor | Quarterly | Longitudinal trends, systemic patterns, improvement recommendations |

---

## Threshold Escalation Matrix

When a metric crosses a threshold boundary, escalation follows:

| Transition | Escalation |
|------------|-----------|
| Healthy -> Warning | Artefact owner notified; logged |
| Warning -> Degraded | CM team + artefact owner; remediation plan required within 5 days |
| Degraded -> Critical | CCB notified; gate progression blocked; remediation plan within 2 days |
| Any metric at Critical for > 5 days | Program Director escalation |
| CHI < 0.60 | Emergency CCB convocation |
| USCI > 10 in any period | Governance audit triggered |
