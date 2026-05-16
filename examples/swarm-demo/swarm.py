"""
Swarm demo for the terraphim-rlm skill.

Run from inside an rlm_code call. The MCP bridge exposes:
  - rlm_query(prompt: str, timeout_ms: int | None = None) -> str
  - rlm_status() -> dict
  - rlm_context_get(key: str) -> str | None
  - rlm_context_set(key: str, value: str) -> None

No model names are hardcoded; prompts use capability-trigger keywords so
the terraphim_router (CostOptimized strategy over tier docs) picks the
provider.
"""

import asyncio
import json
import os
import subprocess


def kg_seed(role: str, query: str) -> list[str]:
    """Seed sub-queries by reading the KG via terraphim-agent --robot."""
    out = subprocess.run(
        [
            "terraphim-agent",
            "search",
            "--role",
            role,
            "--robot",
            "--format",
            "json",
            query,
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    envelope = json.loads(out)
    concepts = envelope.get("concepts_matched", [])
    if not concepts:
        return [query]
    return [f"Expand on '{c}' in the context of: {query}" for c in concepts[:10]]


async def fanout(sub_prompts: list[str]) -> list[str]:
    """Run focused sub-queries in parallel.

    Each prompt is phrased to trigger FastThinking via the keyword router.
    No model parameter -- the router picks from implementation tier.
    """

    async def one(p: str) -> str:
        focused = f"In two paragraphs, summarise: {p}"
        return rlm_query(prompt=focused, timeout_ms=30_000)  # noqa: F821

    return await asyncio.gather(*(one(p) for p in sub_prompts))


def reconcile(results: list[str], original_query: str) -> str:
    """Carefully reconcile sub-results -- triggers DeepThinking via router."""
    joined = "\n\n---\n\n".join(f"[{i}] {r}" for i, r in enumerate(results))
    prompt = (
        f"Carefully reconcile the following sub-results into one coherent "
        f"answer to the original query: {original_query!r}. Surface any "
        f"contradictions between sub-results explicitly.\n\n{joined}"
    )
    return rlm_query(prompt=prompt, timeout_ms=60_000)  # noqa: F821


def main(role: str, query: str) -> str:
    start = rlm_status()  # noqa: F821
    print(f"[start] backend={start.get('backend')} budget={start.get('tokens_remaining')}")

    rlm_context_set("query", query)  # noqa: F821

    sub_prompts = kg_seed(role, query)
    print(f"[seed] {len(sub_prompts)} sub-queries from KG")

    results = asyncio.run(fanout(sub_prompts))
    rlm_context_set("sub_results", json.dumps(results))  # noqa: F821

    verdict = reconcile(results, query)
    rlm_context_set("verdict", verdict)  # noqa: F821

    end = rlm_status()  # noqa: F821
    delta = start.get("tokens_remaining", 0) - end.get("tokens_remaining", 0)
    print(f"[end] consumed={delta} tokens, sub_results stored in rlm_context")
    return verdict


if __name__ == "__main__":
    import sys

    role_arg = sys.argv[1] if len(sys.argv) > 1 else "Rust Engineer"
    query_arg = sys.argv[2] if len(sys.argv) > 2 else "async cancellation patterns"
    print(main(role_arg, query_arg))
