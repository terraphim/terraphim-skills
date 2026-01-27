# [ARCHIVED] Terraphim Claude Skills

> **This repository has been archived.** All skills have been consolidated into the canonical [terraphim/terraphim-skills](https://github.com/terraphim/terraphim-skills) repository.

## Migration

Use the new unified installation:

```bash
# Install via skills.sh (recommended)
npx skills add terraphim/terraphim-skills

# Or install specific skills
npx skills add terraphim/terraphim-skills --skill architecture --skill implementation
```

The skills CLI installs to all supported agents including Claude Code.

### Claude Code Plugin Marketplace (Alternative)

```bash
# Add the Terraphim marketplace
claude plugin marketplace add terraphim/terraphim-skills

# Install the engineering skills plugin
claude plugin install terraphim-engineering-skills@terraphim-skills
```

## Why the change?

- **Single source of truth**: One canonical repository for all platforms
- **skills.sh compatibility**: Easy installation via `npx skills add`
- **Automatic updates**: Stay current across all coding agents
- **Reduced maintenance**: No sync issues between repos

## New Repository

All 32+ engineering skills are now available at:

**[terraphim/terraphim-skills](https://github.com/terraphim/terraphim-skills)**

---

*This repository is kept for historical reference only. No new updates will be made here.*
