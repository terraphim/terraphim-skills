---
name: kg-rlm-ingest
description: |
  Distil long research outputs, sandboxed analyses, or completed RLM
  sessions into role-scoped concepts and persist them into Terraphim's
  knowledge graph by writing markdown into the role's haystack directory.
  Use whenever the user says "ingest this", "save to KG", "remember this
  for future sessions", finishes a long research run worth preserving, or
  wants concepts extracted from a transcript. This is a WRITE skill -- for
  read-only lookup use `local-knowledge`; for retrospective session
  browsing use `session-search`. The thesaurus cache flushes automatically
  after KG markdown edits (Refs terraphim-ai #945), so newly ingested
  concepts become searchable on the next `terraphim-agent search` call.
license: Apache-2.0
---

# KG-RLM Ingest

## When to use

- A research or analysis output has lasting value across sessions
- The user explicitly asks to commit findings to the KG
- An RLM session has finished and its successful artefacts should outlive
  the chat
- An ADF agent produced a report worth promoting to durable knowledge

Do NOT use for:

- Quick lookups -- that is `local-knowledge`
- Reviewing what was discussed last week -- that is `session-search`
- Ephemeral state -- keep it in `rlm_context` and let it expire
- Sensitive material (credentials, PII) -- flag and stop

## Why

Findings that stay in chat history vanish; findings written to the KG
become searchable across all future Terraphim-integrated sessions and feed
the Aho-Corasick automata used for role-based retrieval. Ingestion is the
bridge between transient reasoning and durable knowledge.

## Pipeline

1. **Identify role**: which Terraphim role does this content belong to?
   The standard set is Terraphim Engineer, Rust Engineer, Personal
   Assistant, System Operator, Context Engineering Author, Default. If
   the role is not obvious from the user's request, ask -- writing into
   the wrong haystack causes search drift.

2. **Distil**: use `rlm_query` with a prompt that triggers `FastThinking`
   plus `Documentation` (the router will pick a cheap tactical model from
   the implementation tier). The prompt should produce:

   - A list of concepts (one per heading)
   - Synonyms or aliases per concept
   - Source citations (file paths, URLs, session IDs)
   - A short paragraph per concept explaining the finding

   See `references/concept-extraction.md` for the prompt template.

3. **Dedupe**: for each proposed concept, run
   `terraphim-agent search --role <role> --robot --format json "<concept>"`.
   Read the `concepts_matched` field (Refs terraphim-ai #1486) and the
   document list. If a near-match exists, prefer extending the existing
   note over creating a new one.

4. **Write**: append to (or create under) the role's KG path or haystack
   directory. The KG path is the role's
   `kg.knowledge_graph_local.path` from `terraphim-agent config show`
   (e.g. `~/.config/terraphim/kg/publishing/<role-topic>/`). Haystack
   paths come from the role's `haystacks` array. Concept files belong
   in the **KG path** (thesaurus source); free-text content can live in
   haystacks. Use the `Write` tool. Follow the existing markdown
   convention (heading, short paragraph, `synonyms::` line). Inspect a
   few neighbours before writing.

5. **Verify indexing**:
   `terraphim-agent --format json search --role <role> "<new concept>"`
   should return the new note (note: response shape is
   `.data.results`/`.data.total_matches`, not top-level). The thesaurus
   cache flushes automatically after KG markdown edits when
   **terraphim_server is running** (Refs terraphim-ai #945, commit
   `bf1b7f11c`). The **offline `terraphim-agent` CLI uses a separately
   cached automata** that does not auto-flush; verification via the
   offline CLI may return empty even when the write succeeded. Two
   reliable verification paths:
   - Start `terraphim_server` and re-run the search via the server API
   - Restart any running terraphim-agent processes that have a stale
     thesaurus loaded
   If both paths return empty for a concept that was written, the
   markdown is malformed or the path is wrong -- surface the actual
   diagnostic, do not claim success.

6. **Issue link**: if this ingest advances or closes a Gitea issue,
   `gtr comment --owner <O> --repo <R> --index <IDX> --body "Ingested to KG: <path>"`.

## Anti-patterns

- Ingesting unverified speculation -- only commit successful, validated
  outputs
- Writing into a role's haystack the user has not authorised
- Overwriting an existing concept rather than extending it
- Skipping the dedupe step -- KG pollution is hard to undo
- Ingesting sensitive material -- flag and stop

## When to stop

If the user has not confirmed the role and concept list within two
exchanges, stop and ask. The cost of asking once is much lower than the
cost of cleaning up a polluted KG.

## CLI-first principle

Every step uses an existing CLI:

- Distillation: `rlm_query` (MCP)
- Dedupe + verify: `terraphim-agent search --robot --format json`
- Write: `Write` tool against haystack path
- Issue link: `gtr comment`

Do not invent ingest endpoints; do not POST to atomic-server directly --
the haystack indexer handles that.
