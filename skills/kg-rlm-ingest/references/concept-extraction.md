# Concept Extraction Prompt

Use this prompt template with `rlm_query` to distil source material into
ingest-ready concepts. The capability triggers are `FastThinking` plus
`Documentation`, which routes to the implementation tier and picks a cheap
tactical model.

## Template

```
Summarise and extract concepts from the following content for ingestion
into the Terraphim knowledge graph (role: {ROLE}).

For each concept, produce a markdown section with this exact structure:

# {Concept Name}

synonyms:: {comma-separated aliases}
source:: {file path, URL, or session id}

{One short paragraph explaining the finding, in your own words, grounded
in the source. Use British English. No emoji. Cite specific evidence.}

Constraints:
- One concept per heading
- Concept names are nouns or noun phrases, lower-case-with-hyphens in the
  file name but Title Case in the heading
- Synonyms must be terms a user might actually search for
- If a concept already exists in the KG, name it identically -- do not
  invent new names for known things

Content to distil:

{SOURCE_CONTENT}
```

## Why these constraints

- `synonyms::` is the field the `KeywordRouter` reads to build the
  Aho-Corasick automaton -- without it the concept is unindexed for fuzzy
  matches
- `source::` lets a future search-and-trace verify the claim back to its
  origin
- Title Case headings keep the rendered KG legible; hyphenated filenames
  keep the haystack greppable

## After extraction

Check each generated concept against the existing KG:

```
terraphim-agent search --role {ROLE} --robot --format json "{concept}"
```

Read the `concepts_matched` field. If it contains the concept name (or a
synonym), prefer appending to the existing file under a new subsection
rather than creating a duplicate.
