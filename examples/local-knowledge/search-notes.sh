#!/bin/bash
#
# Search personal notes using Terraphim
#
# Usage:
#   ./search-notes.sh "query"
#   ./search-notes.sh --role rust-engineer "query"
#   ./search-notes.sh --stats
#   ./search-notes.sh --roles
#
# Prerequisites:
#   - terraphim-agent built with --features repl-full
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find terraphim-agent
find_agent() {
    if command -v terraphim-agent >/dev/null 2>&1; then
        echo "terraphim-agent"
    elif [ -x "./target/release/terraphim-agent" ]; then
        echo "./target/release/terraphim-agent"
    elif [ -x "$HOME/.cargo/bin/terraphim-agent" ]; then
        echo "$HOME/.cargo/bin/terraphim-agent"
    elif [ -x "$HOME/projects/terraphim/terraphim-ai/target/release/terraphim-agent" ]; then
        echo "$HOME/projects/terraphim/terraphim-ai/target/release/terraphim-agent"
    elif [ -x "../../../terraphim-ai/target/release/terraphim-agent" ]; then
        echo "../../../terraphim-ai/target/release/terraphim-agent"
    else
        echo ""
    fi
}

# Find terraphim-ai directory
find_terraphim_ai() {
    if [ -d "./docs/src/kg" ]; then
        echo "."
    elif [ -d "$HOME/projects/terraphim/terraphim-ai/docs/src/kg" ]; then
        echo "$HOME/projects/terraphim/terraphim-ai"
    elif [ -d "../../../terraphim-ai/docs/src/kg" ]; then
        echo "../../../terraphim-ai"
    else
        echo ""
    fi
}

AGENT=$(find_agent)
TERRAPHIM_AI_DIR=$(find_terraphim_ai)

if [ -z "$AGENT" ]; then
    echo -e "${RED}Error: terraphim-agent not found${NC}"
    echo ""
    echo "Build it with:"
    echo "  cd /path/to/terraphim-ai"
    echo "  cargo build -p terraphim_agent --features repl-full --release"
    exit 1
fi

if [ -z "$TERRAPHIM_AI_DIR" ]; then
    echo -e "${YELLOW}Warning: terraphim-ai directory not found${NC}"
    echo "Knowledge graph features may not work."
    TERRAPHIM_AI_DIR="."
fi

# Helper to run agent REPL
run_repl() {
    local commands="$1"
    (cd "$TERRAPHIM_AI_DIR" && echo -e "$commands\n/quit" | "$AGENT" repl 2>&1 | \
        grep -v "^\[" | \
        grep -v "opendal" | \
        grep -v "^====" | \
        grep -v "Terraphim" | \
        grep -v "Type /help" | \
        grep -v "Mode:" | \
        grep -v "Available commands:" | \
        grep -v "^  /" | \
        grep -v "^$" | \
        grep -v "Goodbye")
}

show_help() {
    cat << 'EOF'
Search Personal Notes with Terraphim

Usage:
  ./search-notes.sh "query"                    # Search with default role
  ./search-notes.sh --role rust-engineer "query"  # Search with specific role
  ./search-notes.sh --semantic "query"         # Semantic search (uses KG)
  ./search-notes.sh --limit 10 "query"         # Limit results
  ./search-notes.sh --roles                    # List available roles
  ./search-notes.sh --stats                    # Show search statistics
  ./search-notes.sh --help                     # Show this help

Roles:
  terraphim-engineer  Local docs + expanded_docs + KG
  rust-engineer       Rust notes + Query.rs + auto-KG
  frontend-engineer   GrepApp JavaScript/TypeScript
  default             All expanded_docs

Examples:
  ./search-notes.sh "async iterator"
  ./search-notes.sh --role rust-engineer "error handling"
  ./search-notes.sh --role frontend-engineer "useState"
EOF
}

# Parse arguments
MODE="search"
ROLE=""
QUERY=""
LIMIT=""
SEMANTIC=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --role|-r)
            ROLE="$2"
            shift 2
            ;;
        --limit|-l)
            LIMIT="$2"
            shift 2
            ;;
        --semantic|-s)
            SEMANTIC="--semantic"
            shift
            ;;
        --roles)
            MODE="roles"
            shift
            ;;
        --stats)
            MODE="stats"
            shift
            ;;
        --graph|-g)
            MODE="graph"
            shift
            ;;
        *)
            if [ -z "$QUERY" ]; then
                QUERY="$1"
            fi
            shift
            ;;
    esac
done

# Build command options
OPTS=""
if [ -n "$ROLE" ]; then
    OPTS="$OPTS --role $ROLE"
fi
if [ -n "$LIMIT" ]; then
    OPTS="$OPTS --limit $LIMIT"
fi
if [ -n "$SEMANTIC" ]; then
    OPTS="$OPTS $SEMANTIC"
fi

# Execute based on mode
case $MODE in
    search)
        if [ -z "$QUERY" ]; then
            echo -e "${RED}Error: Search query required${NC}"
            echo "Usage: ./search-notes.sh \"query\""
            exit 1
        fi
        echo -e "${BLUE}Searching notes for: ${GREEN}$QUERY${NC}"
        if [ -n "$ROLE" ]; then
            echo -e "Role: ${GREEN}$ROLE${NC}"
        fi
        echo ""
        run_repl "/search \"$QUERY\" $OPTS"
        ;;

    roles)
        echo -e "${BLUE}Available Roles${NC}"
        echo ""
        run_repl "/role list"
        ;;

    stats)
        echo -e "${BLUE}Search Statistics${NC}"
        echo ""
        run_repl "/config show"
        ;;

    graph)
        echo -e "${BLUE}Knowledge Graph Terms${NC}"
        echo ""
        run_repl "/graph --top-k 20"
        ;;
esac
