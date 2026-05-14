---
name: terraphim-rlm
description: |
  Recursive Language Model (RLM) orchestration for secure code execution with feedback loops.
  Provides isolated Firecracker VMs, session management, budget tracking, and knowledge graph validation.
  Use when executing LLM-generated code safely, running recursive query loops, or validating commands against a knowledge graph.
license: MIT
---

# Terraphim RLM

Use this skill when working with Recursive Language Model (RLM) orchestration for secure code execution.

## Overview

Terraphim RLM executes LLM-generated code in isolated environments with feedback loops. It's designed for agents that need to safely execute code, run recursive queries with validation, and maintain session state across operations.

**Key Capabilities:**
- Isolated code execution (Firecracker VMs, Docker, or E2B backends)
- Recursive LLM loops: generate code → execute → feedback → repeat
- Knowledge graph validation of commands
- Session management with snapshots and rollback
- Budget tracking (tokens, time, recursion depth)

## Architecture

```
TerraphimRlm (public API)
    ├── SessionManager (VM affinity, context, snapshots, extensions)
    ├── QueryLoop (command parsing, execution, result handling)
    ├── BudgetTracker (token counting, time tracking, depth limits)
    └── KnowledgeGraphValidator (term matching, retry, strictness)

ExecutionEnvironment trait (pluggable)
    ├── FirecrackerExecutor (primary, full VM isolation)
    ├── DockerExecutor (container isolation with gVisor)
    ├── E2bExecutor (cloud-hosted Firecracker)
    └── LocalExecutor (local process execution, no isolation)
```

## For Humans

### Quick Start (Rust)

```rust
use terraphim_rlm::{TerraphimRlm, RlmConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = RlmConfig::default();
    let rlm = TerraphimRlm::new(config).await?;

    // Create session
    let session = rlm.create_session().await?;

    // Execute Python code
    let result = rlm.execute_code(&session.id, "print('Hello from RLM!')").await?;
    println!("Output: {}", result.stdout);

    // Execute full query with feedback loop
    let query_result = rlm.query(&session.id, "Calculate first 10 fibonacci numbers").await?;
    println!("Result: {:?}", query_result.result);

    // Create snapshot for rollback
    let snapshot = rlm.create_snapshot(&session.id, "checkpoint_1").await?;

    // Clean up
    rlm.destroy_session(&session.id).await?;
    Ok(())
}
```

### Prerequisites

**Rust crate (terraphim_rlm):**

```toml
# Cargo.toml
[dependencies]
terraphim_rlm = { path = "../terraphim-ai/crates/terraphim_rlm", features = ["full"] }
```

**System requirements:**
- Linux with KVM for Firecracker (or Docker for container backend)
- Python interpreter in VM image
- Optional: gVisor for enhanced container isolation

### Local Backend (No Isolation)

For development/testing, use `BackendType::Local` to execute code directly on the host without VM isolation:

```rust
use terraphim_rlm::{RlmConfig, BackendType, TerraphimRlm};

let config = RlmConfig {
    backend_preference: vec![BackendType::Local],
    ..Default::default()
};

let rlm = TerraphimRlm::new(config).await?;
let session = rlm.create_session().await?;

// Code runs directly on host - NO ISOLATION
let result = rlm.execute_code(&session.id, "print('Hello!')").await?;
```

**Warning**: Local backend provides NO isolation. Code runs with same permissions as the RLM process. Use only for:
- Development/testing
- Trusted code
- Quick prototyping without VM overhead

### MCP Integration

RLM exposes MCP tools for integration with AI agents:

| Tool | Description |
|------|-------------|
| `rlm_code` | Execute Python code in isolated VM |
| `rlm_bash` | Execute bash commands in isolated VM |
| `rlm_query` | Full recursive query loop |
| `rlm_context` | Get/set context variables |
| `rlm_snapshot` | Create/restore snapshots |
| `rlm_status` | Get session status |

## For AI Agents

### Detecting RLM Availability

```bash
# Check if terraphim_rlm crate is available
# Look for the crate in the project
if [ -d "crates/terraphim_rlm" ]; then
    echo "terraphim_rlm crate found"
fi

# Check for MCP server with RLM support
if command -v terraphim_mcp_server >/dev/null 2>&1; then
    # Note: Current MCP server may not include RLM tools
    echo "MCP server available"
fi
```

### Session Workflow

```rust
// 1. Create RLM instance
let rlm = TerraphimRlm::new(config).await?;

// 2. Create session (isolated execution context)
let session = rlm.create_session().await?;
let session_id = session.id;

// 3. Execute code (direct, no feedback)
let code_result = rlm.execute_code(&session_id, "import math; print(math.pi)").await?;
assert!(code_result.stdout.contains("3.14"));

// 4. Execute command (bash in VM)
let cmd_result = rlm.execute_command(&session_id, "ls -la").await?;

// 5. Run full query (recursive loop with LLM)
let query = rlm.query(&session_id, "What is the square root of 65536?").await?;
// Query loop: LLM → parse command → execute → feedback → LLM → ... → FINAL

// 6. Create snapshot (rollback point)
let snapshot = rlm.create_snapshot(&session_id, "before_experiment").await?;

// 7. Set context variable (accessible via FINAL_VAR in code)
rlm.set_context_variable(&session_id, "project_root", "/workspace")?;

// 8. Restore if needed
rlm.restore_snapshot(&session_id, &snapshot.id).await?;

// 9. Clean up
rlm.destroy_session(&session_id).await?;
```

### Query Loop Behavior

The query loop implements recursive self-improvement:

```
User prompt
    │
    ▼
┌─────────────────┐
│   LLM generates  │
│   command/code   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ KG validation    │──── Invalid ───▶ Block & retry
└────────┬────────┘
         │ Valid
         ▼
┌─────────────────┐
│   Execute in     │
│   isolated VM    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Capture stdout, │
│   stderr, exit   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Feed back to   │◀───┐ (loop)
│   LLM for review │    │
└────────┬────────┘    │
         │             │
         ▼             │
    FINAL answer       │
         │             │
         ▼             │
    Return result ─────┘ (max depth or FINAL)
```

### Configuration

```rust
use terraphim_rlm::{RlmConfig, BackendType, KgStrictness, SessionModel};

let config = RlmConfig {
    // Backend preference (tries in order, falls back)
    backend_preference: vec![
        BackendType::Firecracker,
        BackendType::Docker,
        BackendType::E2b,
    ],

    // Model for LLM bridge
    session_model: SessionModel::Gpt4,

    // Budget limits
    max_tokens: 100_000,
    time_budget_ms: 300_000,
    max_recursion_depth: 10,
    max_snapshots_per_session: 10,

    // Knowledge graph validation
    kg_validation: true,
    kg_strictness: KgStrictness::Medium,
    kg_allowlist: vec![
        "pypi.org".to_string(),
        "github.com".to_string(),
    ],

    // E2B cloud backend (optional)
    e2b_api_key: None,

    // DNS security
    dns_allowlist: vec![
        "pypi.org".to_string(),
        "github.com".to_string(),
        "raw.githubusercontent.com".to_string(),
    ],
};
```

### Error Handling

```rust
match rlm.create_session().await {
    Ok(session) => { /* use session */ }
    Err(RlmError::NoBackendAvailable { tried }) => {
        eprintln!("No execution backend available. Tried: {:?}", tried);
        // Fall back to alternative approach
    }
    Err(RlmError::BudgetExceeded { budget_type, spent, limit }) => {
        eprintln!("{} budget exceeded: {} / {}", budget_type, spent, limit);
        // Handle budget exhaustion
    }
    Err(RlmError::SessionNotFound(id)) => {
        eprintln!("Session not found: {}", id);
    }
    Err(e) => return Err(e.into()),
}
```

## MCP Tools Reference

### rlm_code

Execute Python code in the isolated VM.

```json
{
  "tool": "rlm_code",
  "arguments": {
    "code": "import math; print(f'Pi = {math.pi}')",
    "session_id": "optional-session-id",
    "timeout_ms": 30000
  }
}
```

Response:
```json
{
  "stdout": "Pi = 3.141592653589793\n",
  "stderr": "",
  "exit_code": 0
}
```

### rlm_bash

Execute bash commands in the isolated VM.

```json
{
  "tool": "rlm_bash",
  "arguments": {
    "command": "echo 'Hello from VM'",
    "session_id": "optional-session-id"
  }
}
```

### rlm_query

Full recursive query loop with LLM feedback.

```json
{
  "tool": "rlm_query",
  "arguments": {
    "prompt": "Calculate the first 10 fibonacci numbers",
    "session_id": "optional-session-id"
  }
}
```

### rlm_context

Get or set context variables (persist for session lifetime).

```json
{
  "tool": "rlm_context",
  "arguments": {
    "action": "set",
    "key": "project_root",
    "value": "/workspace",
    "session_id": "optional-session-id"
  }
}
```

### rlm_snapshot

Create or restore snapshots for rollback.

```json
{
  "tool": "rlm_snapshot",
  "arguments": {
    "action": "create",
    "name": "checkpoint_before_refactor",
    "session_id": "optional-session-id"
  }
}
```

### rlm_status

Get session status including budget usage.

```json
{
  "tool": "rlm_status",
  "arguments": {
    "session_id": "session-id"
  }
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| NoBackendAvailable | Install KVM kernel module (Linux), use Docker backend, or use Local backend |
| SessionNotFound | Create new session with `create_session()` |
| BudgetExceeded | Reduce scope or increase limits in config |
| Python import error | VM image missing module - use `pip install` in code |
| KVM permission denied | Add user to kvm group: `sudo usermod -aG kvm $USER` |
| Need quick execution | Use `BackendType::Local` for development without VM overhead |

## Integration with OpenCode

For OpenCode agents to use RLM:

1. **Via MCP**: Start `terraphim_mcp_server` with RLM tools when available
2. **Via Rust code**: Import `terraphim_rlm` as a dependency in Rust agent code
3. **Via CLI wrapper**: Shell out to a future `terraphim-rlm` CLI (not yet implemented)

Current limitation: RLM is a library crate without a standalone binary. MCP server integration is the recommended path for agent tool exposure.

## Related Skills

- `terraphim-hooks` - Knowledge graph text replacement
- `implementation` - For integrating RLM into Rust projects
- `testing` - For testing RLM integration
