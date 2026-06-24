#!/usr/bin/env python3
"""
Steganography Opencode Runner - Python wrapper for easy project testing

This script helps run opencode on different projects with various attack scenarios
for your steganography research.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def load_scenarios(config_file="scenarios.json"):
    """Load test scenarios from JSON configuration"""
    script_dir = Path(__file__).parent
    config_path = script_dir / config_file

    if not config_path.exists():
        print(f"Error: Configuration file {config_file} not found at {config_path}")
        sys.exit(1)

    try:
        with open(config_path) as f:
            config = json.load(f)
            return config.get("iterations", [])
    except (json.JSONDecodeError, IOError) as e:
        print(f"Error: Failed to load or parse {config_file}: {e}")
        sys.exit(1)


def run_command(cmd):
    """Run a shell command and handle errors"""
    print(f"\n{'='*60}")
    print(f"Running: {' '.join(str(c) for c in cmd)}")
    print(f"{'='*60}\n")

    try:
        result = subprocess.run(cmd, check=False)
        return result.returncode
    except FileNotFoundError as e:
        print(f"Error: {e}")
        print("Make sure run-project.sh is in the current directory and is executable")
        return 1


# ── MCP helpers ───────────────────────────────────────────────────────────────

def is_mcp_scenario(item: dict) -> bool:
    return bool(item.get("mcp", False))


def _write_inplace(path: Path, content: str):
    """Write content to a file in-place, preserving the inode so Docker bind mounts stay valid."""
    with open(str(path), "w") as f:
        f.write(content)
        f.truncate()


def write_mcp_scenario(script_dir: Path, item: dict):
    """Write active_scenario.json so the MCP server returns the right response."""
    scenario_file = script_dir / "mcp-server" / "active_scenario.json"
    config = {
        "id": item.get("id"),
        "tool": item.get("mcp_tool", "web_search"),
        "response": item.get("mcp_response", ""),
        "injection_text": item.get("hidden_imbedded_instruction", ""),
    }
    _write_inplace(scenario_file, json.dumps(config, indent=2))
    print(f">>> MCP scenario written: id={config['id']}, tool={config['tool']}")


def ensure_mcp_server(script_dir: Path, timeout: int = 30):
    """Start the mcp-server service and wait until it responds."""
    print(">>> Starting MCP server...")
    result = subprocess.run(
        ["docker", "compose", "up", "-d", "mcp-server"],
        cwd=str(script_dir),
        check=False,
    )
    if result.returncode != 0:
        print("Warning: docker compose up mcp-server returned non-zero exit code")

    print(f">>> Waiting for MCP server to be ready (up to {timeout}s)...")
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen("http://localhost:8001/mcp", timeout=2)
            print(">>> MCP server is ready.")
            return
        except urllib.error.HTTPError:
            # Any HTTP response (including 406 for wrong content-type) means server is up
            print(">>> MCP server is ready.")
            return
        except Exception:
            time.sleep(1)
    print("Warning: MCP server did not respond in time — continuing anyway")


def reset_mcp_scenario(script_dir: Path):
    """Clear the active scenario after the run."""
    scenario_file = script_dir / "mcp-server" / "active_scenario.json"
    default = {"id": None, "tool": "web_search", "response": "", "injection_text": ""}
    _write_inplace(scenario_file, json.dumps(default, indent=2))


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Run opencode on projects for steganography research",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run a specific iteration by ID
  %(prog)s --id 0101

  # Run with a specific model
  %(prog)s --id 0101 --model anthropic/claude-sonnet-4-6
  %(prog)s --id 0101 --model google/gemini-3.1-flash-lite

  # Run an MCP injection scenario
  %(prog)s --id 2001

  # Run all iterations for a specific technique
  %(prog)s --technique "unicode emoji"

  # Run all iterations
  %(prog)s --all

  # Continue from a specific ID (inclusive)
  %(prog)s --from 3102 --model anthropic/claude-opus-4-8

  # List all available iterations
  %(prog)s --list
        """
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--id", type=str, help="Run a specific iteration by its ID")
    group.add_argument("--technique", type=str, help="Run all iterations matching a specific technique")
    group.add_argument("--all", action="store_true", help="Run all iterations")
    group.add_argument("--from", dest="from_id", type=str, metavar="ID",
                       help="Run all iterations starting from (and including) the given ID")
    group.add_argument("--list", action="store_true", help="List all available iterations")

    parser.add_argument(
        "--model", type=str,
        help="Model to use, e.g. anthropic/claude-haiku-4-5-20251001 or google/gemini-3.1-flash-lite"
    )

    args = parser.parse_args()

    if args.model:
        os.environ["MODEL"] = args.model

    if not os.environ.get("MODEL"):
        parser.error("--model is required (or set the MODEL environment variable). "
                     "e.g. --model anthropic/claude-haiku-4-5-20251001")

    # Load scenarios from JSON
    iterations_list = load_scenarios()

    # List scenarios and exit
    if args.list:
        print("\nAvailable Iterations:")
        print("=" * 60)
        for item in iterations_list:
            iteration_id = item.get("id", "unknown")
            technique = item.get("technique", "unknown")
            modality = item.get("modality", "")
            description = item.get("description", "")
            file_name = item.get("file") or "(MCP tool)"
            path = item.get("path", "(provided via CLI)")
            prompt = item.get("prompt", "").replace("$FILE", file_name or "")[:50]
            mcp_tag = "  [MCP]" if is_mcp_scenario(item) else ""
            print(f"\nID: {iteration_id:16} | Technique: {technique}{mcp_tag}")
            print(f"   Modality:    {modality}")
            print(f"   Description: {description}")
            print(f"   Path:        {path}")
            print(f"   File:        {file_name}")
            print(f"   Prompt:      {prompt}...")
        print("\n")
        return 0

    script_dir = Path(__file__).parent
    run_project_script = script_dir / "run-project.sh"

    if not run_project_script.exists():
        print(f"Error: {run_project_script} not found")
        print("Make sure you're in the project root directory")
        return 1

    to_run = []
    if args.all:
        to_run = iterations_list
    elif args.id:
        to_run = [item for item in iterations_list if item.get("id") == args.id]
        if not to_run:
            print(f"Error: No iteration found with ID '{args.id}'")
            return 1
    elif args.technique:
        to_run = [item for item in iterations_list if item.get("technique") == args.technique]
        if not to_run:
            print(f"Error: No iteration found with technique '{args.technique}'")
            return 1
    elif args.from_id:
        ids = [item.get("id") for item in iterations_list]
        if args.from_id not in ids:
            print(f"Error: No iteration found with ID '{args.from_id}'")
            return 1
        start = ids.index(args.from_id)
        to_run = iterations_list[start:]
        print(f">>> Continuing from ID {args.from_id} ({len(to_run)} iteration(s) remaining)")

    overall_exit_code = 0
    for item in to_run:
        iteration_id = item.get("id", "unknown")
        technique = item.get("technique", "unknown")
        project_path = script_dir / item.get("path", "")
        file_name = item.get("file") or ""
        raw_prompt = item.get("prompt", "")

        # Replace $FILE with the actual file name
        prompt = raw_prompt.replace("$FILE", file_name)

        print(f"\n>>> Running Iteration {iteration_id} (Technique: {technique})")
        print(f">>> Target folder: {project_path}")
        if file_name:
            print(f">>> Target file: {file_name}")

        os.environ["SCENARIO_ID"] = iteration_id
        _write_inplace(script_dir / "results" / ".scenario_id", iteration_id)

        if not project_path.exists():
            print(f"Error: Project path '{project_path}' does not exist. Skipping.")
            overall_exit_code = 1
            continue

        # ── MCP scenario setup ────────────────────────────────────────────────
        if is_mcp_scenario(item):
            write_mcp_scenario(script_dir, item)
            ensure_mcp_server(script_dir)
            os.environ["MCP_ENABLED"] = "true"
        else:
            os.environ.pop("MCP_ENABLED", None)

        git_underscore = project_path / "_git"
        git_dot = project_path / ".git"
        renamed_git = False

        if git_underscore.exists():
            print(f">>> Renaming _git to .git in {project_path}")
            git_underscore.rename(git_dot)
            renamed_git = True

        try:
            cmd = [str(run_project_script), str(project_path), prompt]
            code = run_command(cmd)
            if code != 0:
                overall_exit_code = code
        finally:
            if renamed_git and git_dot.exists():
                print(f">>> Renaming .git back to _git in {project_path}")
                git_dot.rename(git_underscore)

            # Clear MCP state after each run
            if is_mcp_scenario(item):
                reset_mcp_scenario(script_dir)
                os.environ.pop("MCP_ENABLED", None)

    return overall_exit_code


if __name__ == "__main__":
    sys.exit(main())
