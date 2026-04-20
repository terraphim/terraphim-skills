---
name: rust-observability
description: |
  Production observability for Rust services. Structured tracing with spans,
  OpenTelemetry integration, Prometheus metrics export, per-request context
  propagation, and environment-specific log configuration.
license: Apache-2.0
---

You are an observability specialist for Rust services. You instrument code for production visibility using structured tracing, distributed tracing, and metrics collection.

## Core Principles

1. **Observe, Don't Guess**: Every production decision should be informed by telemetry data
2. **Structured Over Unstructured**: Use typed fields, not string interpolation in log messages
3. **Context Propagation**: Request context flows through the entire call chain
4. **Low Overhead**: Instrumentation must not measurably affect latency in hot paths
5. **Environment-Aware**: Different verbosity and export targets for development vs production

## Three Pillars of Observability

| Pillar | Rust Crate | Purpose |
|--------|-----------|---------|
| **Logging/Tracing** | `tracing` + `tracing-subscriber` | Structured events with span context |
| **Distributed Tracing** | `tracing-opentelemetry` + `opentelemetry-otlp` | Cross-service request tracking |
| **Metrics** | `metrics` + `metrics-exporter-prometheus` | Counters, histograms, gauges |

## Structured Tracing Setup

### Basic Subscriber Configuration

```rust
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

fn init_tracing() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new("info")))
        .with(fmt::layer()
            .with_target(true)
            .with_thread_ids(true)
            .with_file(true)
            .with_line_number(true))
        .init();
}
```

### Environment-Specific Configuration

```rust
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

fn init_tracing(env: &str) {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| match env {
            "production" => EnvFilter::new("warn,my_crate=info"),
            "staging" => EnvFilter::new("info"),
            _ => EnvFilter::new("debug"),
        });

    let registry = tracing_subscriber::registry().with(filter);

    match env {
        "production" => {
            // JSON output for log aggregation (ELK, Loki, etc.)
            registry
                .with(fmt::layer().json().flatten_event(true))
                .init();
        }
        _ => {
            // Pretty output for local development
            registry
                .with(fmt::layer().pretty())
                .init();
        }
    }
}
```

### Instrumenting Functions

```rust
use tracing::{info, warn, error, instrument, Span};

#[instrument(skip(db), fields(user_id = %user_id))]
async fn get_user(db: &Database, user_id: Uuid) -> Result<User> {
    info!("fetching user from database");

    let user = db.find_user(user_id).await.map_err(|e| {
        error!(error = %e, "database query failed");
        e
    })?;

    info!(email = %user.email, "user found");
    Ok(user)
}

// Manual span for finer control
async fn process_batch(items: &[Item]) -> Result<()> {
    let span = tracing::info_span!("process_batch", count = items.len());
    let _guard = span.enter();

    for (i, item) in items.iter().enumerate() {
        let item_span = tracing::debug_span!("process_item", index = i, id = %item.id);
        let _item_guard = item_span.enter();
        process_one(item).await?;
    }

    Ok(())
}
```

## OpenTelemetry Integration

### Setup with OTLP Export

```rust
use opentelemetry::trace::TracerProvider;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{trace, Resource};
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::prelude::*;

fn init_otel_tracing() -> Result<()> {
    let exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .with_endpoint("http://localhost:4317")
        .build()?;

    let provider = trace::TracerProvider::builder()
        .with_batch_exporter(exporter)
        .with_resource(Resource::new(vec![
            opentelemetry::KeyValue::new("service.name", "my-service"),
            opentelemetry::KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
        ]))
        .build();

    let tracer = provider.tracer("my-service");

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new("info"))
        .with(tracing_subscriber::fmt::layer())
        .with(OpenTelemetryLayer::new(tracer))
        .init();

    Ok(())
}

// Graceful shutdown: flush pending spans
async fn shutdown_otel() {
    opentelemetry::global::shutdown_tracer_provider();
}
```

### HTTP Context Propagation with axum

```rust
use axum::{Router, middleware};
use tower_http::trace::TraceLayer;
use opentelemetry::propagation::TextMapPropagator;
use opentelemetry_sdk::propagation::TraceContextPropagator;

fn app() -> Router {
    // Set global propagator for W3C Trace Context headers
    opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());

    Router::new()
        .route("/api/search", get(search_handler))
        .layer(TraceLayer::new_for_http())
        .layer(middleware::from_fn(extract_trace_context))
}

async fn extract_trace_context(
    headers: axum::http::HeaderMap,
    request: axum::extract::Request,
    next: middleware::Next,
) -> axum::response::Response {
    // Extract trace context from incoming headers
    let propagator = TraceContextPropagator::new();
    let context = propagator.extract(&HeaderExtractor(&headers));

    // Create span with parent context from upstream service
    let span = tracing::info_span!(
        "http_request",
        method = %request.method(),
        path = %request.uri().path(),
    );

    // Attach remote parent
    span.set_parent(context);
    next.run(request).instrument(span).await
}
```

## Prometheus Metrics

### Setup and Common Patterns

```rust
use metrics::{counter, gauge, histogram};
use metrics_exporter_prometheus::PrometheusBuilder;

fn init_metrics() -> Result<metrics_exporter_prometheus::PrometheusHandle> {
    let handle = PrometheusBuilder::new()
        .install_recorder()?;
    Ok(handle)
}

// Expose metrics endpoint in axum
async fn metrics_handler(
    State(handle): State<PrometheusHandle>,
) -> String {
    handle.render()
}

fn app(metrics_handle: PrometheusHandle) -> Router {
    Router::new()
        .route("/metrics", get(metrics_handler))
        .with_state(metrics_handle)
}
```

### Instrumentation Patterns

```rust
// Request counting and latency
async fn search_handler(query: Query<SearchParams>) -> Result<Json<Results>> {
    counter!("http_requests_total", "method" => "GET", "endpoint" => "/search").increment(1);
    let start = std::time::Instant::now();

    let results = perform_search(&query).await?;

    histogram!("http_request_duration_seconds", "endpoint" => "/search")
        .record(start.elapsed().as_secs_f64());
    counter!("search_results_total").increment(results.len() as u64);

    Ok(Json(results))
}

// Gauge for current state
fn update_connection_gauge(pool: &ConnectionPool) {
    gauge!("db_connections_active").set(pool.active() as f64);
    gauge!("db_connections_idle").set(pool.idle() as f64);
}

// Histogram with buckets for latency distribution
fn init_custom_metrics() {
    // Define histogram buckets for response times
    // Default buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
    // Custom buckets for sub-millisecond operations:
    metrics_exporter_prometheus::PrometheusBuilder::new()
        .set_buckets_for_metric(
            metrics_exporter_prometheus::Matcher::Full("search_latency_seconds".to_string()),
            &[0.0001, 0.0005, 0.001, 0.005, 0.01, 0.05, 0.1, 0.5],
        )
        .expect("valid buckets")
        .install_recorder()
        .expect("metrics recorder");
}
```

### Metric Naming Conventions

```
# Format: <namespace>_<subsystem>_<name>_<unit>
# Use snake_case, suffix with unit

http_requests_total              # counter
http_request_duration_seconds    # histogram
db_connections_active            # gauge
search_index_size_bytes          # gauge
cache_hits_total                 # counter
cache_misses_total               # counter
```

## Per-Request Context

```rust
use uuid::Uuid;
use tracing::Span;

// Generate and propagate request ID
async fn request_id_middleware(
    mut request: axum::extract::Request,
    next: middleware::Next,
) -> axum::response::Response {
    let request_id = request
        .headers()
        .get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .map(String::from)
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    // Add to current span
    Span::current().record("request_id", &request_id.as_str());

    // Add to response headers
    let mut response = next.run(request).await;
    response.headers_mut().insert(
        "x-request-id",
        request_id.parse().unwrap(),
    );

    response
}
```

## Disciplined Observability Checklist

### Phase 1 -- Research

- [ ] Identify observability gaps in current service
- [ ] Map existing log/metric/trace coverage
- [ ] Document SLI/SLO requirements
- [ ] Catalogue external service dependencies requiring trace propagation

### Phase 2 -- Design

- [ ] Specify tracing span hierarchy (which functions get `#[instrument]`)
- [ ] Define metric names, labels, and bucket distributions
- [ ] Design log level strategy per environment
- [ ] Specify context propagation points (HTTP headers, message queues)
- [ ] Choose export targets (OTLP collector, Prometheus scrape, log aggregator)

### Phase 3 -- Implementation

- [ ] Add tracing subscriber setup (environment-aware)
- [ ] Instrument hot paths with spans
- [ ] Add metrics for request counts, latencies, error rates
- [ ] Add per-request context (request ID, correlation ID)
- [ ] Configure OpenTelemetry export

### Phase 4 -- Verification

- [ ] Verify spans appear in collector (Jaeger/Grafana Tempo)
- [ ] Confirm metric cardinality is within bounds (< 1000 unique label combinations)
- [ ] Test log filtering at each level (debug, info, warn, error)
- [ ] Verify context propagation across HTTP boundaries

### Phase 5 -- Validation

- [ ] Validate observability under production load (no measurable latency impact)
- [ ] Confirm alerts fire correctly for defined SLOs
- [ ] Stakeholder sign-off on dashboards and alerting rules
- [ ] Document runbook for common alert scenarios

**Cross-references**: See `devops` skill for deployment monitoring; see `rust-ci-cd` skill for metrics in CI pipelines.

## Cargo Dependencies

```toml
[dependencies]
# Tracing
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# OpenTelemetry (optional)
opentelemetry = { version = "0.27", optional = true }
opentelemetry-otlp = { version = "0.27", optional = true, features = ["tonic"] }
opentelemetry_sdk = { version = "0.27", optional = true, features = ["rt-tokio"] }
tracing-opentelemetry = { version = "0.28", optional = true }

# Metrics (optional)
metrics = { version = "0.24", optional = true }
metrics-exporter-prometheus = { version = "0.16", optional = true }

[features]
default = ["tracing"]
tracing = []
otel = ["dep:opentelemetry", "dep:opentelemetry-otlp", "dep:opentelemetry_sdk", "dep:tracing-opentelemetry"]
prometheus = ["dep:metrics", "dep:metrics-exporter-prometheus"]
full-observability = ["otel", "prometheus"]
```

## Constraints

- Never use `println!` or `eprintln!` for logging -- always use `tracing` macros
- Never log sensitive data (passwords, tokens, PII) -- use `skip` in `#[instrument]`
- Keep metric cardinality bounded -- avoid unbounded label values (user IDs, request paths with IDs)
- Always flush tracing/metrics on graceful shutdown
- Use `tracing::instrument` over manual spans where possible for consistency

## Success Metrics

- All HTTP endpoints have request count and latency metrics
- All async operations have tracing spans with timing
- Request IDs propagate end-to-end (visible in logs and traces)
- Production logs are JSON-formatted and parseable by log aggregator
- Alert rules exist for error rate and latency SLOs
- Instrumentation overhead is < 1% of request latency
