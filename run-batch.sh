#!/bin/bash

# Usage: ./run-batch.sh <model> <runs> [id...]
#
# Examples:
#   # Run all scenarios 9 times
#   ./run-batch.sh anthropic/claude-opus-4-8 9
#
#   # Run only scenarios c0001 c0002 c0003, 10 times each
#   ./run-batch.sh anthropic/claude-opus-4-8 10 c0001 c0002 c0003

MODEL="${1:?Usage: $0 <model> <runs> [id...]}"
RUNS="${2:?Usage: $0 <model> <runs> [id...]}"
shift 2
IDS=("$@")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for i in $(seq 1 "$RUNS"); do
    echo ""
    echo "════════════════════════════════════════"
    echo "  Batch run $i / $RUNS"
    echo "════════════════════════════════════════"
    if [ "${#IDS[@]}" -gt 0 ]; then
        for id in "${IDS[@]}"; do
            echo "  -> Scenario $id"
            python3 "$SCRIPT_DIR/run-opencode.py" --id "$id" --model "$MODEL"
        done
    else
        python3 "$SCRIPT_DIR/run-opencode.py" --all --model "$MODEL"
    fi
done

echo ""
echo "Batch complete: $RUNS run(s) finished."
