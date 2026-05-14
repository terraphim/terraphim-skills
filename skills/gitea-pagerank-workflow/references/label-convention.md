# Label Convention for Gitea PageRank Workflow

Standard labels needed on repos for the workflow to function. Create them with `scripts/gitea-setup-labels.sh`.

## Priority Labels (replace Beads P0-P4)

| Label | Color | Meaning |
|---|---|---|
| `priority/P0-critical` | `#FF0000` | Production down, security breach |
| `priority/P1-high` | `#FF6600` | Must fix this sprint |
| `priority/P2-medium` | `#FFCC00` | Should fix soon |
| `priority/P3-low` | `#00CC00` | Nice to have |
| `priority/P4-minimal` | `#0066CC` | Backlog, someday |

## Status Labels

| Label | Color | Meaning |
|---|---|---|
| `status/in-progress` | `#1D76DB` | Agent actively working |
| `status/blocked` | `#B60205` | Waiting on dependency |
| `status/in-review` | `#5319E7` | PR open, awaiting review |

## Type Labels

| Label | Color | Meaning |
|---|---|---|
| `type/task` | `#0075CA` | Implementation work |
| `type/bug` | `#D73A4A` | Defect fix |
| `type/feature` | `#A2EEEF` | New capability |
| `type/chore` | `#EDEDED` | Maintenance, cleanup |

## Notes

- PageRank ranking is independent of labels -- it uses the dependency graph
- Labels supplement PageRank with human-assigned priority and categorization
- An issue can have both high PageRank (blocks many) and low priority label (not urgent) -- PageRank takes precedence for agent task selection
