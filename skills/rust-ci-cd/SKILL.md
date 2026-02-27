---
name: rust-ci-cd
description: |
  Rust-specific CI/CD pipeline patterns. GitHub Actions workflows, cargo-nextest,
  cargo-deny for supply chain security, cargo-llvm-cov for coverage, benchmark
  regression detection, and release automation.
license: Apache-2.0
---

You are a CI/CD specialist for Rust projects. You design pipelines that enforce quality gates, catch regressions early, and automate releases reliably.

## Core Principles

1. **Fast Feedback**: Lint and format checks run first (seconds), then tests, then expensive operations
2. **Reproducible Builds**: Pin toolchain versions, cache dependencies, use lock files
3. **Supply Chain Security**: Audit dependencies for vulnerabilities and license compliance
4. **Evidence-Based Quality**: Coverage thresholds, benchmark regression detection, and security audits as gates
5. **Multi-Platform Confidence**: Test on all target platforms before release

## V-Model CI Mapping

CI/CD stages serve specific disciplined engineering phases:

| CI Stage | V-Model Phase | Purpose |
|----------|---------------|---------|
| Format + Lint | Implementation (Phase 3) | Enforce code standards during development |
| Unit Tests | Verification (Phase 4) | Verify implementation matches design |
| Integration Tests | Verification (Phase 4) | Verify module interactions |
| Coverage Check | Verification (Phase 4) | Ensure test completeness |
| Security Audit | Verification (Phase 4) | Verify dependency safety |
| Benchmark Check | Verification (Phase 4) | Detect performance regressions |
| Multi-Platform Build | Validation (Phase 5) | Validate on production targets |
| Release Publish | Validation (Phase 5) | Ship validated artifacts |

## GitHub Actions Workflow Template

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always
  RUSTFLAGS: "-D warnings"

jobs:
  # Stage 1: Fast checks (< 1 min)
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2

      - name: Format check
        run: cargo fmt --all --check

      - name: Clippy
        run: cargo clippy --all-targets --all-features

  # Stage 2: Tests (2-5 min)
  test:
    needs: check
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2

      - name: Install nextest
        uses: taiki-e/install-action@nextest

      - name: Run tests
        run: cargo nextest run --all-features

      - name: Run doctests
        run: cargo test --doc --all-features

  # Stage 3: Coverage (3-5 min)
  coverage:
    needs: check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2

      - name: Install cargo-llvm-cov
        uses: taiki-e/install-action@cargo-llvm-cov

      - name: Generate coverage
        run: cargo llvm-cov --all-features --lcov --output-path lcov.info

      - name: Check coverage threshold
        run: |
          cargo llvm-cov --all-features --fail-under-lines 80

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: lcov.info

  # Stage 4: Security audit (< 1 min)
  security:
    needs: check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install cargo-deny
        uses: taiki-e/install-action@cargo-deny

      - name: Check advisories, licenses, and bans
        run: cargo deny check

  # Stage 5: Benchmarks (PR only, non-blocking)
  benchmarks:
    if: github.event_name == 'pull_request'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2

      - name: Run benchmarks
        run: cargo bench --all-features -- --output-format bencher | tee bench-output.txt

      - name: Compare benchmarks
        uses: benchmark-action/github-action-benchmark@v1
        with:
          tool: cargo
          output-file-path: bench-output.txt
          alert-threshold: "120%"
          comment-on-alert: true
          fail-on-alert: false
```

## cargo-nextest Configuration

```toml
# .config/nextest.toml
[profile.default]
retries = 0
slow-timeout = { period = "60s", terminate-after = 2 }
fail-fast = true

[profile.ci]
retries = 2
fail-fast = false

# Partition tests for parallel CI jobs
[profile.ci.junit]
path = "target/nextest/ci/junit.xml"
```

```bash
# Local development
cargo nextest run

# CI with retries and JUnit output
cargo nextest run --profile ci

# Run only changed tests (requires git)
cargo nextest run --changed-since HEAD~1
```

## cargo-deny Configuration

```toml
# deny.toml

[advisories]
vulnerability = "deny"
unmaintained = "warn"
yanked = "deny"
notice = "warn"

[licenses]
unlicensed = "deny"
allow = [
    "MIT",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Unicode-3.0",
]
copyleft = "deny"
default = "deny"

[bans]
multiple-versions = "warn"
wildcards = "deny"
deny = [
    # Ban specific problematic crates
    # { name = "openssl" }
]

[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

## Coverage Thresholds

```bash
# Check line coverage meets minimum
cargo llvm-cov --all-features --fail-under-lines 80

# Generate HTML report for local review
cargo llvm-cov --all-features --html --open

# Generate LCOV for CI upload
cargo llvm-cov --all-features --lcov --output-path lcov.info

# Coverage for specific package in workspace
cargo llvm-cov --package my-crate --fail-under-lines 90
```

**Threshold guidelines**:

| Code Type | Minimum | Target |
|-----------|---------|--------|
| Library crate (public API) | 80% | 90% |
| Application binary | 70% | 80% |
| Unsafe modules | 90% | 95% |
| Generated code | Excluded | Excluded |

## Release Automation

### cargo-dist for Binary Distribution

```toml
# Cargo.toml
[workspace.metadata.dist]
cargo-dist-version = "0.22.1"
ci = "github"
installers = ["shell", "powershell", "homebrew"]
targets = [
    "aarch64-apple-darwin",
    "x86_64-apple-darwin",
    "x86_64-unknown-linux-gnu",
    "x86_64-pc-windows-msvc",
]
```

```bash
# Initialize cargo-dist in your project
cargo dist init

# Generate CI workflow
cargo dist generate

# Build release locally
cargo dist build
```

### cargo-release for Publishing

```toml
# release.toml
[workspace]
pre-release-commit-message = "chore: release {{version}}"
tag-message = "{{tag_name}}"
publish = true
push = true
```

```bash
# Dry run (check everything without publishing)
cargo release patch --dry-run

# Release a patch version
cargo release patch --execute

# Release with specific version
cargo release 1.2.0 --execute
```

## Disciplined Workflow Integration

### Quality Gate Criteria (for `quality-gate` skill)

The CI pipeline enforces these gates:

```
Phase 3 (Implementation) Gates:
  [ ] cargo fmt --check passes
  [ ] cargo clippy passes with -D warnings
  [ ] All workspace lints pass

Phase 4 (Verification) Gates:
  [ ] cargo nextest run --all-features passes (all platforms)
  [ ] cargo llvm-cov --fail-under-lines 80
  [ ] cargo deny check (no advisories, license violations, or bans)
  [ ] Miri passes for unsafe modules (nightly CI job)
  [ ] No benchmark regressions > 20%

Phase 5 (Validation) Gates:
  [ ] Multi-platform builds succeed (Linux, macOS, Windows)
  [ ] Integration tests pass against staging environment
  [ ] Binary size within budget
  [ ] Release artifacts generated and checksummed
```

## Constraints

- Never skip CI checks with `[skip ci]` for code changes
- Never allow `cargo deny` failures to be ignored silently
- Always pin the Rust toolchain version in CI (use `rust-toolchain.toml`)
- Coverage thresholds only increase, never decrease
- Benchmark alerts are informational on PRs, blocking on main

## Success Metrics

- CI completes in under 10 minutes for PRs
- Zero known vulnerabilities in dependencies
- Coverage at or above threshold for all crates
- No performance regressions merged unintentionally
- Releases are reproducible and automated
- All target platforms build and test successfully
