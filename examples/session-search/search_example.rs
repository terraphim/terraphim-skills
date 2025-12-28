//! Example: Semantic Search over Claude Code Sessions
//!
//! This example demonstrates how to use terraphim_sessions for
//! knowledge graph-enriched search over AI coding assistant history.
//!
//! # Prerequisites
//!
//! Add to Cargo.toml:
//! ```toml
//! [dependencies]
//! terraphim_sessions = { version = "0.1", features = ["cla-full", "enrichment"] }
//! tokio = { version = "1", features = ["full"] }
//! anyhow = "1.0"
//! ```
//!
//! # Running
//!
//! ```bash
//! cargo run --example search_example
//! ```

use anyhow::Result;

// Uncomment when using as actual example in terraphim-ai:
// use terraphim_sessions::{
//     SessionService, ImportOptions, SessionEnricher, EnrichmentConfig,
//     search_by_concept, find_related_sessions,
// };

#[tokio::main]
async fn main() -> Result<()> {
    println!("=== Terraphim Session Search Example ===\n");

    // Example 1: Basic Session Import and Search
    basic_search().await?;

    // Example 2: Concept-Based Search
    concept_search().await?;

    // Example 3: Find Related Sessions
    related_sessions().await?;

    // Example 4: Session Statistics
    session_statistics().await?;

    Ok(())
}

/// Example 1: Import sessions and perform full-text search
async fn basic_search() -> Result<()> {
    println!("--- Example 1: Basic Search ---\n");

    // Pseudo-code (uncomment with real dependencies):
    //
    // let service = SessionService::new();
    //
    // // Detect available sources
    // let sources = service.detect_sources();
    // for source in &sources {
    //     println!("Found source: {} ({:?})", source.id, source.status);
    // }
    //
    // // Import sessions
    // let options = ImportOptions::default().with_limit(100);
    // let sessions = service.import_all(&options).await?;
    // println!("Imported {} sessions", sessions.len());
    //
    // // Search for a query
    // let results = service.search("rust async").await;
    // println!("\nFound {} sessions matching 'rust async':", results.len());
    //
    // for session in results.iter().take(5) {
    //     println!("  - {}: {} messages",
    //         session.id,
    //         session.message_count()
    //     );
    //     if let Some(title) = &session.title {
    //         println!("    Title: {}", title);
    //     }
    //     if let Some(path) = &session.metadata.project_path {
    //         println!("    Project: {}", path);
    //     }
    // }

    println!("(Demo mode - see code comments for real implementation)\n");
    println!("Steps:");
    println!("  1. Create SessionService");
    println!("  2. Detect sources (claude-code, cursor, aider)");
    println!("  3. Import sessions with ImportOptions");
    println!("  4. Search with service.search(\"query\")");
    println!();

    Ok(())
}

/// Example 2: Search using knowledge graph concepts
async fn concept_search() -> Result<()> {
    println!("--- Example 2: Concept-Based Search ---\n");

    // Pseudo-code (uncomment with real dependencies):
    //
    // // Configure enrichment with knowledge graph
    // let config = EnrichmentConfig {
    //     thesaurus_path: "docs/src/kg/".into(),
    //     min_confidence: 0.8,
    // };
    //
    // let enricher = SessionEnricher::new(config)?;
    //
    // // Enrich sessions with concepts
    // let mut enriched_sessions = Vec::new();
    // for session in &sessions {
    //     let enriched = enricher.enrich(session)?;
    //     enriched_sessions.push(enriched);
    // }
    //
    // // Search by concept
    // let concept_results = search_by_concept(&enriched_sessions, "error handling")?;
    //
    // println!("Sessions mentioning 'error handling' concepts:");
    // for result in concept_results.iter().take(5) {
    //     println!("  - Session: {}", result.session.id);
    //     println!("    Matched concepts:");
    //     for concept in &result.concepts {
    //         println!("      {} ({} occurrences, confidence: {:.2})",
    //             concept.term,
    //             concept.occurrences.len(),
    //             concept.confidence
    //         );
    //     }
    // }

    println!("(Demo mode - see code comments for real implementation)\n");
    println!("Concept search finds sessions that discuss a topic,");
    println!("even if they don't contain the exact phrase.");
    println!();
    println!("Example: searching for 'error handling' also finds:");
    println!("  - Sessions discussing Result<T, E>");
    println!("  - Sessions using anyhow or thiserror");
    println!("  - Sessions implementing custom error types");
    println!();

    Ok(())
}

/// Example 3: Find sessions related to a known session
async fn related_sessions() -> Result<()> {
    println!("--- Example 3: Related Sessions ---\n");

    // Pseudo-code (uncomment with real dependencies):
    //
    // // Find a session to use as reference
    // let reference_session = &enriched_sessions[0];
    //
    // // Find related sessions (min 3 shared concepts)
    // let related = find_related_sessions(
    //     &enriched_sessions,
    //     reference_session,
    //     3, // minimum shared concepts
    // )?;
    //
    // println!("Sessions related to '{}':", reference_session.session.id);
    // for (session, shared_concepts) in related.iter().take(5) {
    //     println!("  - {}", session.session.id);
    //     println!("    Shared concepts: {:?}", shared_concepts);
    // }

    println!("(Demo mode - see code comments for real implementation)\n");
    println!("Related sessions share knowledge graph concepts.");
    println!("Use this to find:");
    println!("  - Similar problems you've solved before");
    println!("  - Work in the same domain");
    println!("  - Sessions from the same project");
    println!();

    Ok(())
}

/// Example 4: Generate statistics about your sessions
async fn session_statistics() -> Result<()> {
    println!("--- Example 4: Session Statistics ---\n");

    // Pseudo-code (uncomment with real dependencies):
    //
    // let stats = service.statistics().await;
    //
    // println!("Total sessions: {}", stats.total_sessions);
    // println!("Total messages: {}", stats.total_messages);
    // println!("  User messages: {}", stats.total_user_messages);
    // println!("  Assistant messages: {}", stats.total_assistant_messages);
    // println!();
    // println!("Sessions by source:");
    // for (source, count) in &stats.sessions_by_source {
    //     println!("  {}: {}", source, count);
    // }

    println!("(Demo mode - see code comments for real implementation)\n");
    println!("Statistics provide insights into your AI coding history:");
    println!("  - Total sessions and messages");
    println!("  - Breakdown by source (Claude Code, Cursor, etc.)");
    println!("  - User vs assistant message counts");
    println!();

    Ok(())
}

// Additional utility examples

/// Helper: Print session details
#[allow(dead_code)]
fn print_session_details(/* session: &Session */) {
    // println!("Session: {}", session.id);
    // println!("  Source: {}", session.source);
    // if let Some(title) = &session.title {
    //     println!("  Title: {}", title);
    // }
    // if let Some(path) = &session.metadata.project_path {
    //     println!("  Project: {}", path);
    // }
    // println!("  Messages: {}", session.message_count());
    // if let Some(started) = session.metadata.started_at {
    //     println!("  Started: {}", started);
    // }
}

/// Helper: Export session to markdown
#[allow(dead_code)]
fn export_to_markdown(/* session: &Session */) -> String {
    // let mut md = String::new();
    // md.push_str(&format!("# Session: {}\n\n", session.id));
    //
    // if let Some(title) = &session.title {
    //     md.push_str(&format!("**Title:** {}\n\n", title));
    // }
    //
    // for msg in &session.messages {
    //     let role = match msg.role {
    //         MessageRole::User => "**User:**",
    //         MessageRole::Assistant => "**Assistant:**",
    //         MessageRole::System => "**System:**",
    //     };
    //     md.push_str(&format!("{}\n\n{}\n\n---\n\n", role, msg.content));
    // }
    //
    // md
    String::from("(Demo mode)")
}
