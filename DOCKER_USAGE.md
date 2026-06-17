# Docker Usage Guide

This guide covers the Docker layer directly. For most research runs you should
use `run-opencode.py` (see the [README](README.md)), which selects a scenario
and calls into the layers described here. Use this document when you want to run
opencode on an arbitrary project or debug the container interactively.

## Overview

Two services are defined in `docker-compose.yml`:

| Service | Purpose |
| --- | --- |
| `steganography` | The opencode runtime (Ubuntu + opencode). Mounts a target project and runs an analysis prompt against it. |
| `mcp-server` | A controlled MCP server used by `mcp_context` scenarios. Host port `8001` → container port `8000`. |

A **model is always required.** Pass it with `--model` or set the `MODEL`
environment variable. There is no implicit default in the runner.

## Prerequisites

1. Copy the environment template and add your key(s):

   ```bash
   cp example.env .env
   # set GEMINI_API_KEY and/or ANTHROPIC_API_KEY
   ```

2. Build the image:

   ```bash
   docker compose build
   # or, force a clean rebuild:
   ./build.sh
   ```

## Option 1 — `run-project.sh` (recommended for ad-hoc projects)

`run-project.sh` wraps `docker compose run` and resolves paths for you.

```bash
# Syntax
./run-project.sh [--model <model>] <project-path> [prompt]
./run-project.sh [--model <model>] <project-path> --interactive
```

Examples:

```bash
# Run an analysis prompt against a scenario folder
./run-project.sh --model anthropic/claude-sonnet-4-6 \
  ./flask-artifacts/0101 "Please analyze the README.md and summarize it."

# Use the MODEL environment variable instead of the flag
MODEL=google/gemini-3.1-flash-lite \
  ./run-project.sh ./flask-artifacts/base "Summarize this project"

# Open an interactive shell inside the container for a project
./run-project.sh --model google/gemini-3.1-flash-lite ./flask-artifacts/base --interactive

# Enable verbose debug output
DEBUG=1 ./run-project.sh --model google/gemini-3.1-flash-lite ./flask-artifacts/0101 "Analyze this"
```

The project directory is mounted into the container at
`/projects/<basename>`, and results are written to `./results/`.

## Option 2 — `docker compose` directly

```bash
# Automated run with a prompt
PROJECT_FOLDER=/projects/myproject \
MODEL=anthropic/claude-sonnet-4-6 \
PROMPT="Find all TODO comments" \
docker compose run --rm \
  -v "$(pwd)/flask-artifacts/base:/projects/myproject" \
  steganography /home/user/entrypoint.sh

# Interactive shell
PROJECT_FOLDER=/projects/myproject \
MODEL=google/gemini-3.1-flash-lite \
docker compose run --rm -it \
  -v "$(pwd)/flask-artifacts/base:/projects/myproject" \
  steganography /bin/bash
```

## Option 3 — the MCP server

For `mcp_context` scenarios the MCP server must be running. `run-opencode.py`
starts and configures it automatically; to run it by hand:

```bash
# Start the MCP service (host port 8001 → container 8000)
docker compose up -d mcp-server

# The active scenario is read from this file on every request:
#   mcp-server/active_scenario.json
# run-opencode.py writes it before a run and resets it afterwards.

# Inspect that it is up
curl -i http://localhost:8001/mcp
```

When MCP is in use, opencode is configured with the `research-server` MCP entry
(`configuration/opencode.jsonc`), enabled via the `MCP_ENABLED` flag.

## Environment variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `MODEL` | Yes | Model id, e.g. `anthropic/claude-sonnet-4-6` or `google/gemini-3.1-flash-lite` |
| `GEMINI_API_KEY` | If using Google | Google Gemini API key (from `.env`) |
| `ANTHROPIC_API_KEY` | If using Anthropic | Anthropic API key (from `.env`) |
| `PROJECT_FOLDER` | For runs | Absolute path to the project inside the container, e.g. `/projects/myproject` |
| `PROMPT` | Optional | Task for opencode; if omitted the container starts interactively |
| `MCP_ENABLED` | Optional | `true` to enable the MCP server entry in opencode config (default `false`) |
| `SCENARIO_ID` | Optional | Names the output files; set automatically by `run-opencode.py` |

## How the entrypoint works

`entrypoint.sh` runs on container start and:

1. Fills the `${GEMINI_API_KEY}` / `${ANTHROPIC_API_KEY}` placeholders in the
   opencode auth file from the environment.
2. Fills the `${MODEL}` and `${MCP_ENABLED}` placeholders in `opencode.jsonc`
   (and fails fast if `MODEL` is unset).
3. Marks all paths as git-safe.
4. If `PROJECT_FOLDER` is set: `cd`s into it, runs
   `opencode run "$PROMPT" --model "$MODEL" --format json --thinking
   --dangerously-skip-permissions`, and tees the NDJSON output plus a metadata
   file into `/home/user/results` (mounted to `./results`).
5. If no `PROJECT_FOLDER`/prompt is set, drops into an interactive shell.

## Troubleshooting

**`MODEL is not set`**
The runner requires a model. Pass `--model <model>` or export `MODEL`.

**Container exits immediately**
Verify the project path exists and is mounted; check that `PROJECT_FOLDER`
points at the in-container mount path (`/projects/<name>`).

**API key warnings / auth failures**
Confirm `.env` contains the right key for the provider in your `MODEL`, and that
`configuration/opencode/auth.json` placeholders are intact.

**MCP scenarios produce no injection**
Ensure `docker compose up -d mcp-server` is running and that
`mcp-server/active_scenario.json` holds the intended scenario (it is reset to an
empty default between runs).

**opencode not found in the image**
Rebuild cleanly: `docker compose build --no-cache` (or `./build.sh`).

## Notes

- `run-project.sh` resolves relative paths to absolute paths automatically.
- The in-container project name is derived from the directory basename.
- For batch processing, prefer `run-opencode.py --all` over scripting this layer.
