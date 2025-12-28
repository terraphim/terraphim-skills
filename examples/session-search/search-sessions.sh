#!/bin/bash
#
# Semantic search over Claude Code sessions using Terraphim
#
# Usage:
#   ./search-sessions.sh "query"                    # Basic search
#   ./search-sessions.sh --concepts "query"         # Concept-based search
#   ./search-sessions.sh --export "query" file.md   # Export to file
#   ./search-sessions.sh --stats                    # Show statistics
#   ./search-sessions.sh --timeline                 # Show timeline
#
# Prerequisites:
#   - terraphim-agent built with --features repl-full
#   - Claude Code sessions in ~/.claude/projects/
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
    # Check common terraphim-ai locations
    elif [ -x "$HOME/projects/terraphim/terraphim-ai/target/release/terraphim-agent" ]; then
        echo "$HOME/projects/terraphim/terraphim-ai/target/release/terraphim-agent"
    elif [ -x "../../../terraphim-ai/target/release/terraphim-agent" ]; then
        echo "../../../terraphim-ai/target/release/terraphim-agent"
    else
        echo ""
    fi
}

AGENT=$(find_agent)

# Find terraphim-ai directory (needed for knowledge graph)
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
    echo "Set TERRAPHIM_AI_DIR environment variable or run from terraphim-ai directory."
    TERRAPHIM_AI_DIR="."
fi

# Helper to run agent REPL with commands
run_repl() {
    local commands="$1"
    (cd "$TERRAPHIM_AI_DIR" && echo -e "$commands\n/quit" | "$AGENT" repl 2>&1 | \
        grep -v "^\\[" | \
        grep -v "opendal" | \
        grep -v "^====" | \
        grep -v "Terraphim TUI REPL" | \
        grep -v "Type /help" | \
        grep -v "Mode: Offline" | \
        grep -v "Available commands:" | \
        grep -v "^  /" | \
        grep -v "^$" | \
        grep -v "Goodbye")
}

show_help() {
    cat << 'EOF'
Semantic Search over Claude Code Sessions

Usage:
  ./search-sessions.sh "query"                    # Basic full-text search
  ./search-sessions.sh --concepts "query"         # Knowledge graph concept search
  ./search-sessions.sh --related <session-id>     # Find related sessions
  ./search-sessions.sh --export "query" file.md   # Export results to file
  ./search-sessions.sh --stats                    # Show session statistics
  ./search-sessions.sh --timeline [--limit N]     # Show session timeline
  ./search-sessions.sh --sources                  # List available sources
  ./search-sessions.sh --import                   # Import all sessions
  ./search-sessions.sh --help                     # Show this help

Examples:
  ./search-sessions.sh "rust async"
  ./search-sessions.sh --concepts "error handling"
  ./search-sessions.sh --export "authentication" auth-sessions.md
  ./search-sessions.sh --timeline --limit 20
EOF
}

# Parse arguments
MODE="search"
QUERY=""
OUTPUT_FILE=""
SESSION_ID=""
LIMIT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --concepts|-c)
            MODE="concepts"
            shift
            QUERY="$1"
            shift
            ;;
        --related|-r)
            MODE="related"
            shift
            SESSION_ID="$1"
            shift
            ;;
        --export|-e)
            MODE="export"
            shift
            QUERY="$1"
            shift
            OUTPUT_FILE="$1"
            shift
            ;;
        --stats|-s)
            MODE="stats"
            shift
            ;;
        --timeline|-t)
            MODE="timeline"
            shift
            ;;
        --sources)
            MODE="sources"
            shift
            ;;
        --import|-i)
            MODE="import"
            shift
            ;;
        --limit|-l)
            shift
            LIMIT="$1"
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

# Execute based on mode
case $MODE in
    search)
        if [ -z "$QUERY" ]; then
            echo -e "${RED}Error: Search query required${NC}"
            echo "Usage: ./search-sessions.sh \"query\""
            exit 1
        fi
        echo -e "${BLUE}Searching sessions for: ${GREEN}$QUERY${NC}"
        echo ""

        # Import first if no sessions cached
        run_repl "/sessions import --limit 100\n/sessions search $QUERY"
        ;;

    concepts)
        if [ -z "$QUERY" ]; then
            echo -e "${RED}Error: Concept query required${NC}"
            exit 1
        fi
        echo -e "${BLUE}Searching by concept: ${GREEN}$QUERY${NC}"
        echo ""

        run_repl "/sessions import --limit 100\n/sessions concepts $QUERY"
        ;;

    related)
        if [ -z "$SESSION_ID" ]; then
            echo -e "${RED}Error: Session ID required${NC}"
            exit 1
        fi
        echo -e "${BLUE}Finding sessions related to: ${GREEN}$SESSION_ID${NC}"
        echo ""

        run_repl "/sessions related $SESSION_ID"
        ;;

    export)
        if [ -z "$QUERY" ] || [ -z "$OUTPUT_FILE" ]; then
            echo -e "${RED}Error: Query and output file required${NC}"
            echo "Usage: ./search-sessions.sh --export \"query\" output.md"
            exit 1
        fi
        echo -e "${BLUE}Exporting sessions matching '$QUERY' to: ${GREEN}$OUTPUT_FILE${NC}"

        run_repl "/sessions import --limit 100\n/sessions search $QUERY\n/sessions export --format markdown --output $OUTPUT_FILE"
        echo -e "${GREEN}Exported to $OUTPUT_FILE${NC}"
        ;;

    stats)
        echo -e "${BLUE}Session Statistics${NC}"
        echo ""

        run_repl "/sessions import --limit 500\n/sessions stats"
        ;;

    timeline)
        LIMIT_ARG=""
        if [ -n "$LIMIT" ]; then
            LIMIT_ARG="--limit $LIMIT"
        fi

        echo -e "${BLUE}Session Timeline${NC}"
        echo ""

        run_repl "/sessions import --limit 500\n/sessions timeline --group week $LIMIT_ARG"
        ;;

    sources)
        echo -e "${BLUE}Available Session Sources${NC}"
        echo ""

        run_repl "/sessions sources"
        ;;

    import)
        echo -e "${BLUE}Importing Sessions${NC}"
        echo ""

        run_repl "/sessions import\n/sessions stats"
        ;;
esac
