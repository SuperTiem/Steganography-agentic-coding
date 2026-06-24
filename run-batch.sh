#!/bin/bash

# Usage: ./run-batch.sh <model> <runs>
# Example: ./run-batch.sh anthropic/claude-opus-4-8 9

MODEL="${1:?Usage: $0 <model> <runs>}"
RUNS="${2:?Usage: $0 <model> <runs>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for i in $(seq 1 "$RUNS"); do
    echo ""
    echo "════════════════════════════════════════"
    echo "  Batch run $i / $RUNS"
    echo "════════════════════════════════════════"
    python3 "$SCRIPT_DIR/run-opencode.py" --all --model "$MODEL"
done

echo ""
echo "Batch complete: $RUNS run(s) finished."
