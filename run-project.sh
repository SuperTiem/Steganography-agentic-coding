#!/bin/bash

# Helper script to run opencode on a specific project with a prompt
# Usage: ./run-project.sh <project-path> [prompt]
#        ./run-project.sh <project-path> [--interactive]

set -e

# Enable debug output
DEBUG="${DEBUG:-0}"
if [ "$DEBUG" = "1" ]; then
    set -x
fi

# Inherit MODEL from environment; allow override via --model flag
if [ "$1" = "--model" ]; then
    if [ "$#" -lt 3 ]; then
        echo "Error: --model requires a model name and project path"
        exit 1
    fi
    MODEL="$2"
    shift 2
fi

if [ -z "$MODEL" ]; then
    echo "Error: MODEL is not set. Pass --model <model> or set the MODEL environment variable."
    echo "  e.g.: $0 --model anthropic/claude-haiku-4-5-20251001 /path/to/project 'prompt'"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 [--model <model>] <project-path> [prompt]"
    echo "       $0 [--model <model>] <project-path> --interactive"
    echo ""
    echo "Examples:"
    echo "  # Run with a prompt"
    echo "  $0 /path/to/project 'Analyze this code for security issues'"
    echo ""
    echo "  # Run with a specific model"
    echo "  $0 --model anthropic/claude-sonnet-4-6 /path/to/project 'Analyze this'"
    echo ""
    echo "  # Run interactively (shell prompt)"
    echo "  $0 /path/to/project --interactive"
    echo ""
    echo "  # Run with mounted projects folder"
    echo "  $0 /projects/myproject 'Generate unit tests'"
    echo ""
    echo "Debug: DEBUG=1 $0 [--model <model>] <project-path> [prompt]"
    exit 1
fi

PROJECT_PATH="$1"
PROMPT="${2:-}"

echo "Debug: PROJECT_PATH=$PROJECT_PATH"
echo "Debug: PROMPT=$PROMPT"
echo "Debug: MODEL=$MODEL"

# Resolve absolute path
if [[ "$PROJECT_PATH" != /* ]]; then
    echo "Debug: Resolving relative path..."
    PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
        echo "ERROR: Could not resolve path '$1'"
        exit 1
    }
fi

echo "Debug: Resolved PROJECT_PATH=$PROJECT_PATH"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Debug: SCRIPT_DIR=$SCRIPT_DIR"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Project directory '$PROJECT_PATH' does not exist!"
    exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH")"
echo "Debug: PROJECT_NAME=$PROJECT_NAME"

echo "=========================================="
echo "Steganography Opencode Runner"
echo "=========================================="
echo "Project Path: $PROJECT_PATH"
echo "Project Name: $PROJECT_NAME"
echo ""

if [ "$PROMPT" = "--interactive" ]; then
    echo "Mode: Interactive Shell"
    echo ""
    echo "Debug: Entering interactive mode"
    echo "Debug: About to run docker compose..."
    cd "$SCRIPT_DIR"
    echo "Debug: Changed to $SCRIPT_DIR"
    echo "Debug: Running: docker compose run --rm -it -e PROJECT_FOLDER=/projects/$PROJECT_NAME -e MODEL=$MODEL -v $PROJECT_PATH:/projects/$PROJECT_NAME steganography /bin/bash"
    docker compose run --rm -it \
        -e PROJECT_FOLDER="/projects/$PROJECT_NAME" \
        -e MODEL="$MODEL" \
        -e SCENARIO_ID="${SCENARIO_ID:-}" \
        -v "$PROJECT_PATH:/projects/$PROJECT_NAME" \
        steganography /bin/bash
elif [ -n "$PROMPT" ]; then
    echo "Mode: Opencode with Prompt"
    echo "Prompt: $PROMPT"
    echo ""
    echo "Debug: Entering prompt mode"
    echo "Starting opencode in container..."
    cd "$SCRIPT_DIR"
    # Explicitly call entrypoint script with PROJECT_FOLDER and PROMPT
    docker compose run --rm -it \
        -e PROJECT_FOLDER="/projects/$PROJECT_NAME" \
        -e PROMPT="$PROMPT" \
        -e MODEL="$MODEL" \
        -e SCENARIO_ID="${SCENARIO_ID:-}" \
        -v "$PROJECT_PATH:/projects/$PROJECT_NAME" \
        steganography /home/user/entrypoint.sh
else
    echo "Mode: Interactive Shell (no prompt)"
    echo ""
    echo "Debug: Entering default shell mode"
    cd "$SCRIPT_DIR"
    docker compose run --rm -it \
        -e PROJECT_FOLDER="/projects/$PROJECT_NAME" \
        -e MODEL="$MODEL" \
        -e SCENARIO_ID="${SCENARIO_ID:-}" \
        -v "$PROJECT_PATH:/projects/$PROJECT_NAME" \
        steganography /bin/bash
fi
