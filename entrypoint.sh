#!/bin/bash
set -e

AUTH_FILE="/home/user/.local/share/opencode/auth.json"
CONFIG_FILE="/home/user/.config/opencode/opencode.jsonc"

# Configure API keys in auth.json
if [ -f "$AUTH_FILE" ]; then
    if [ -n "$GEMINI_API_KEY" ]; then
        echo "Configuring Gemini API key..."
        sed -i "s|\${GEMINI_API_KEY}|${GEMINI_API_KEY}|g" "$AUTH_FILE"
    else
        echo "WARNING: GEMINI_API_KEY is not set"
    fi

    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "Configuring Anthropic API key..."
        sed -i "s|\${ANTHROPIC_API_KEY}|${ANTHROPIC_API_KEY}|g" "$AUTH_FILE"
    else
        echo "WARNING: ANTHROPIC_API_KEY is not set"
    fi
else
    echo "WARNING: Auth file not found at $AUTH_FILE"
fi

# Configure active model and MCP flag in opencode.jsonc
MCP_ENABLED="${MCP_ENABLED:-false}"
if [ -z "$MODEL" ]; then
    echo "ERROR: MODEL environment variable is not set. Specify a model when launching the container."
    exit 1
fi
if [ -f "$CONFIG_FILE" ]; then
    echo "Configuring model: $MODEL"
    echo "Configuring MCP enabled: $MCP_ENABLED"
    sed -i "s|\${MODEL}|${MODEL}|g" "$CONFIG_FILE"
    sed -i "s|\${MCP_ENABLED}|${MCP_ENABLED}|g" "$CONFIG_FILE"
else
    echo "WARNING: Config file not found at $CONFIG_FILE"
fi

# Set git safe directory for all paths within the container
echo "Configuring git safe directory..."
git config --global --add safe.directory '*'

# If PROJECT_FOLDER is set, handle project-based execution
# This takes priority over any passed commands
if [ -n "$PROJECT_FOLDER" ]; then
    if [ ! -d "$PROJECT_FOLDER" ]; then
        echo "ERROR: Project folder '$PROJECT_FOLDER' does not exist!"
        echo "Contents of /projects:"
        ls -la /projects 2>/dev/null || echo "(directory not mounted)"
        exit 1
    fi
    
    echo "=========================================="
    echo "Opencode Project Runner"
    echo "=========================================="
    echo "Project folder: $PROJECT_FOLDER"
    cd "$PROJECT_FOLDER"
    echo "Working directory: $(pwd)"
    echo "Project contents:"
    ls -la | head -20
    echo ""
    
    # Create results directory if it doesn't exist
    RESULTS_DIR="/home/user/results"
    mkdir -p "$RESULTS_DIR"
    
    # If a PROMPT is provided, show it to the user
    if [ -n "$PROMPT" ]; then
        echo "Your prompt:"
        echo "---"
        echo "$PROMPT"
        echo "---"
        echo ""
        echo "Starting opencode with your prompt..."
        # Save prompt to a file for reference
        echo "$PROMPT" > /tmp/opencode_prompt.txt
        
        # Create output file with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        SCENARIO_ID_FILE="/home/user/results/.scenario_id"
        if [ -z "$SCENARIO_ID" ] && [ -f "$SCENARIO_ID_FILE" ]; then
            SCENARIO_ID=$(cat "$SCENARIO_ID_FILE")
        fi
        RUN_NAME="${SCENARIO_ID:-$(basename "$PROJECT_FOLDER")}"
        OUTPUT_FILE="$RESULTS_DIR/${RUN_NAME}_${TIMESTAMP}.log"
        SESSION_FILE="$RESULTS_DIR/${RUN_NAME}_${TIMESTAMP}_session.json"
        
        echo "Output will be saved to: $OUTPUT_FILE"
        echo ""
        
        # Run opencode with the prompt and capture output
        # Use --prompt to run with the given prompt
        # Redirect both stdout and stderr to the output file and also to terminal
        if [ -n "$MODEL" ]; then
            MODEL_ARGS="--model $MODEL"
        else
            MODEL_ARGS=""
        fi
        /home/user/.opencode/bin/opencode run "$PROMPT" $MODEL_ARGS --format json --thinking --dangerously-skip-permissions 2>&1 | tee "$OUTPUT_FILE" || true
        
        # Save metadata about this run
        cat > "$RESULTS_DIR/${RUN_NAME}_${TIMESTAMP}_metadata.txt" << EOF
Project: $RUN_NAME
Prompt: $PROMPT
Project Path: $PROJECT_FOLDER
Timestamp: $TIMESTAMP
Model: $MODEL
API Key Configured: Yes
EOF
        
        echo ""
        echo "=========================================="
        echo "Results saved to: $OUTPUT_FILE"
        echo "Metadata saved to: $RESULTS_DIR/${PROJECT_NAME}_${TIMESTAMP}_metadata.txt"
        echo "=========================================="
        
    else
        echo "Starting opencode..."
        # Start opencode interactively without a prompt (don't save output in this case)
        exec /home/user/.opencode/bin/opencode
    fi
    
# If no PROJECT_FOLDER, execute the command passed as arguments
# If no arguments passed, default to bash
else
    if [ $# -eq 0 ]; then
        # No command passed and no PROJECT_FOLDER, default to interactive bash
        exec /bin/bash
    else
        exec "$@"
    fi
fi
