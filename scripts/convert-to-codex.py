#!/usr/bin/env python3
"""
Convert terraphim-claude-skills to codex-skills format.

Key differences:
- Skills: Identical format (direct copy)
- Agents: Convert `tools:` (comma-separated) to `allowed-tools:` (YAML array)
- Infrastructure: Flatten nested structure to top-level skills
- Plugin metadata: Not needed for Codex (skip .claude-plugin/)

Usage:
    python scripts/convert-to-codex.py [--dry-run]
"""

import argparse
import os
import re
import shutil
from pathlib import Path
from typing import Tuple

# Paths
SCRIPT_DIR = Path(__file__).parent
SOURCE_DIR = SCRIPT_DIR.parent  # terraphim-claude-skills
TARGET_DIR = SOURCE_DIR.parent / "codex-skills"

# Files/dirs to skip
SKIP_PATTERNS = [
    ".git",
    ".claude",
    ".claude-plugin",
    ".sessions",
    ".DS_Store",
    "__pycache__",
    "crates",
    "scripts",
]


def parse_frontmatter(content: str) -> Tuple[dict, str]:
    """Extract YAML frontmatter and body from markdown content."""
    if not content.startswith("---"):
        return {}, content

    # Find the closing ---
    end_match = re.search(r"\n---\n", content[3:])
    if not end_match:
        return {}, content

    frontmatter_str = content[4:end_match.start() + 3]
    body = content[end_match.end() + 4:]

    # Simple YAML parsing for our specific format
    frontmatter = {}
    current_key = None
    current_value = []
    in_multiline = False

    for line in frontmatter_str.split("\n"):
        # Check if this is a new top-level key (not indented, has colon)
        is_new_key = ":" in line and not line.startswith(" ") and not line.startswith("\t")

        if is_new_key:
            # Save previous key if exists
            if current_key:
                frontmatter[current_key] = "\n".join(current_value).strip()

            key, value = line.split(":", 1)
            current_key = key.strip()
            value = value.strip()

            if value == "|":
                in_multiline = True
                current_value = []
            else:
                current_value = [value]
                in_multiline = False
        elif in_multiline and (line.startswith("  ") or line.startswith("\t") or line.strip() == ""):
            # Continue multiline value only if indented or empty
            current_value.append(line.lstrip() if line.strip() else "")
        elif current_key and not in_multiline:
            # Non-multiline continuation - shouldn't happen in our format
            pass

    # Save last key
    if current_key:
        frontmatter[current_key] = "\n".join(current_value).strip()

    return frontmatter, body


def convert_tools_to_allowed_tools(tools_str: str) -> list:
    """Convert comma-separated tools string to list."""
    if not tools_str:
        return []
    return [t.strip() for t in tools_str.split(",") if t.strip()]


def format_frontmatter_codex(frontmatter: dict, body: str) -> str:
    """Format frontmatter for Codex format (agents)."""
    lines = ["---"]

    # Name first
    if "name" in frontmatter:
        lines.append(f"name: {frontmatter['name']}")

    # Description with multiline
    if "description" in frontmatter:
        lines.append("description: |")
        for desc_line in frontmatter["description"].split("\n"):
            lines.append(f"  {desc_line}")

    # Convert tools to allowed-tools array
    if "tools" in frontmatter:
        tools = convert_tools_to_allowed_tools(frontmatter["tools"])
        lines.append("allowed-tools:")
        for tool in tools:
            lines.append(f"  - {tool}")

    lines.append("---")
    lines.append("")

    return "\n".join(lines) + body


def copy_skill(src: Path, dst: Path, dry_run: bool = False) -> bool:
    """Copy a skill file directly (no conversion needed)."""
    dst.parent.mkdir(parents=True, exist_ok=True)

    if dry_run:
        print(f"  [DRY-RUN] Would copy: {src} -> {dst}")
        return True

    shutil.copy2(src, dst)
    return True


def convert_agent(src: Path, dst: Path, dry_run: bool = False) -> bool:
    """Convert agent file from Claude Code to Codex format."""
    content = src.read_text()
    frontmatter, body = parse_frontmatter(content)

    if not frontmatter:
        print(f"  [WARN] No frontmatter found in {src}")
        if not dry_run:
            shutil.copy2(src, dst)
        return False

    # Convert to Codex format
    new_content = format_frontmatter_codex(frontmatter, body)

    dst.parent.mkdir(parents=True, exist_ok=True)

    if dry_run:
        print(f"  [DRY-RUN] Would convert: {src} -> {dst}")
        if "tools" in frontmatter:
            tools = convert_tools_to_allowed_tools(frontmatter["tools"])
            print(f"    tools: {frontmatter['tools'][:50]}...")
            print(f"    -> allowed-tools: {tools[:3]}...")
        return True

    dst.write_text(new_content)
    return True


def sync_skills(source: Path, target: Path, dry_run: bool = False) -> dict:
    """Sync all skills from source to target."""
    stats = {"copied": 0, "skipped": 0, "flattened": 0}

    skills_src = source / "skills"
    skills_dst = target / "skills"

    if not skills_src.exists():
        print(f"[ERROR] Skills directory not found: {skills_src}")
        return stats

    for skill_dir in skills_src.iterdir():
        if skill_dir.name in SKIP_PATTERNS or not skill_dir.is_dir():
            continue

        # Handle infrastructure subdirectory (flatten)
        if skill_dir.name == "infrastructure":
            for infra_skill in skill_dir.iterdir():
                if not infra_skill.is_dir():
                    continue

                # Find skill file (SKILL.md or skill.md)
                skill_file = None
                for name in ["SKILL.md", "skill.md"]:
                    if (infra_skill / name).exists():
                        skill_file = infra_skill / name
                        break

                if skill_file:
                    dst = skills_dst / infra_skill.name / "SKILL.md"
                    print(f"  [FLATTEN] {skill_file.relative_to(source)} -> {dst.relative_to(target)}")
                    copy_skill(skill_file, dst, dry_run)

                    # Copy other files in the skill directory
                    for other_file in infra_skill.iterdir():
                        if other_file.is_file() and other_file.name not in ["SKILL.md", "skill.md"]:
                            other_dst = skills_dst / infra_skill.name / other_file.name
                            copy_skill(other_file, other_dst, dry_run)
                        elif other_file.is_dir():
                            # Copy subdirectories (examples, research, etc.)
                            other_dst = skills_dst / infra_skill.name / other_file.name
                            if not dry_run:
                                shutil.copytree(other_file, other_dst, dirs_exist_ok=True)
                            else:
                                print(f"  [DRY-RUN] Would copy dir: {other_file} -> {other_dst}")

                    stats["flattened"] += 1
            continue

        # Regular skill directory
        skill_file = None
        for name in ["SKILL.md", "skill.md"]:
            if (skill_dir / name).exists():
                skill_file = skill_dir / name
                break

        if skill_file:
            dst = skills_dst / skill_dir.name / "SKILL.md"
            copy_skill(skill_file, dst, dry_run)

            # Copy other files in the skill directory
            for other_file in skill_dir.iterdir():
                if other_file.is_file() and other_file.name not in ["SKILL.md", "skill.md"]:
                    other_dst = skills_dst / skill_dir.name / other_file.name
                    copy_skill(other_file, other_dst, dry_run)
                elif other_file.is_dir():
                    # Copy subdirectories (examples, research, etc.)
                    other_dst = skills_dst / skill_dir.name / other_file.name
                    if not dry_run:
                        shutil.copytree(other_file, other_dst, dirs_exist_ok=True)
                    else:
                        print(f"  [DRY-RUN] Would copy dir: {other_file} -> {other_dst}")

            stats["copied"] += 1
        else:
            print(f"  [SKIP] No SKILL.md found in {skill_dir}")
            stats["skipped"] += 1

    return stats


def sync_agents(source: Path, target: Path, dry_run: bool = False) -> dict:
    """Sync and convert all agents from source to target."""
    stats = {"converted": 0, "skipped": 0}

    agents_src = source / "agents"
    agents_dst = target / "agents"

    if not agents_src.exists():
        print(f"[WARN] Agents directory not found: {agents_src}")
        return stats

    for agent_file in agents_src.glob("*.md"):
        dst = agents_dst / agent_file.name
        if convert_agent(agent_file, dst, dry_run):
            stats["converted"] += 1
        else:
            stats["skipped"] += 1

    return stats


def sync_docs(source: Path, target: Path, dry_run: bool = False) -> dict:
    """Sync documentation files."""
    stats = {"copied": 0}

    # Copy docs directory
    docs_src = source / "docs"
    docs_dst = target / "docs"

    if docs_src.exists():
        if not dry_run:
            shutil.copytree(docs_src, docs_dst, dirs_exist_ok=True)
        print(f"  [COPY] docs/ directory")
        stats["copied"] += 1

    # Copy individual doc files
    for doc_file in ["lessons-learned.md", "RIGHT_SIDE_OF_V.md", "HANDOVER.md"]:
        src = source / doc_file
        dst = target / doc_file
        if src.exists():
            if not dry_run:
                shutil.copy2(src, dst)
            print(f"  [COPY] {doc_file}")
            stats["copied"] += 1

    return stats


def main():
    parser = argparse.ArgumentParser(description="Convert terraphim-skills to codex-skills format")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--source", type=Path, default=SOURCE_DIR, help="Source directory (terraphim-claude-skills)")
    parser.add_argument("--target", type=Path, default=TARGET_DIR, help="Target directory (codex-skills)")
    args = parser.parse_args()

    source = args.source.resolve()
    target = args.target.resolve()

    print(f"{'[DRY-RUN] ' if args.dry_run else ''}Converting terraphim-skills to codex-skills format")
    print(f"  Source: {source}")
    print(f"  Target: {target}")
    print()

    if not source.exists():
        print(f"[ERROR] Source directory not found: {source}")
        return 1

    if not target.exists():
        print(f"[ERROR] Target directory not found: {target}")
        return 1

    # Sync skills
    print("=== Syncing Skills ===")
    skill_stats = sync_skills(source, target, args.dry_run)
    print(f"  Copied: {skill_stats['copied']}, Flattened: {skill_stats['flattened']}, Skipped: {skill_stats['skipped']}")
    print()

    # Convert agents
    print("=== Converting Agents ===")
    agent_stats = sync_agents(source, target, args.dry_run)
    print(f"  Converted: {agent_stats['converted']}, Skipped: {agent_stats['skipped']}")
    print()

    # Sync docs
    print("=== Syncing Documentation ===")
    doc_stats = sync_docs(source, target, args.dry_run)
    print(f"  Copied: {doc_stats['copied']}")
    print()

    print("=== Summary ===")
    print(f"  Skills: {skill_stats['copied']} copied, {skill_stats['flattened']} flattened")
    print(f"  Agents: {agent_stats['converted']} converted")
    print(f"  Docs: {doc_stats['copied']} copied")

    if args.dry_run:
        print("\n[DRY-RUN] No changes were made. Run without --dry-run to apply changes.")
    else:
        print("\nConversion complete!")

    return 0


if __name__ == "__main__":
    exit(main())
