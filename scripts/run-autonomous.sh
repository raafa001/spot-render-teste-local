#!/bin/bash
# run-autonomous.sh - Run AIOps agents autonomously
set -e

echo "🤖 Starting AIOps Autonomous Mode"
echo "================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
AGENTS_DIR="$HOME/git/spot-render/agents"
SPOT_RENDER_DIR="$(dirname "$0")"
INTERVAL=${1:-300}  # Default 5 minutes between cycles

cd "$SPOT_RENDER_DIR"

# Source venv if exists
if [ -f "$AGENTS_DIR/venv/bin/activate" ]; then
    source "$AGENTS_DIR/venv/bin/activate"
fi

# Export LLM config
export OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://localhost:11434}
export OLLAMA_MODEL=${OLLAMA_MODEL:-llama3.2}

log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

run_agent() {
    local agent=$1
    local args=$2
    log "Running agent: $agent"

    python -m agents.main --agent "$agent" $args 2>/dev/null && \
        log "$agent completed" || \
        log "$agent failed"
}

# Check if Ollama is available
check_ollama() {
    curl -s "$OLLAMA_BASE_URL/api/version" > /dev/null 2>&1
}

main() {
    log "Starting autonomous loop (interval: ${INTERVAL}s)"
    log "Monitoring: $SPOT_RENDER_DIR"

    while true; do
        log "=== Starting autonomous cycle ==="

        # 1. Security Scan (every cycle)
        if [ -d ".git" ]; then
            log "Running security scan..."
            python -m agents.main --agent security-scanner --repo . > /tmp/security-scan.log 2>&1 || true
        fi

        # 2. Generate documentation (daily - check if needs update)
        # 3. Check for incidents (every cycle)
        # 4. Monitor metrics (every cycle)

        # Store cycle info
        echo "$(date)" > /tmp/last-aiops-cycle.txt

        log "=== Cycle complete ==="
        log "Next cycle in ${INTERVAL} seconds..."

        sleep "$INTERVAL"
    done
}

# Run once for testing
if [ "$1" == "--once" ]; then
    log "Running single cycle (--once mode)"
    main
else
    main
fi
