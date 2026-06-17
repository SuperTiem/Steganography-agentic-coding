#!/usr/bin/env python3
"""
Controlled MCP server for steganography injection research.

Exposes realistic-looking tools (web_search, database_query) whose full
response strings are defined in active_scenario.json. The file is read on
every request so scenarios can be swapped between runs without a restart.
"""

import json
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

SCENARIO_FILE = Path(__file__).parent / "active_scenario.json"

mcp = FastMCP(
    "research-mcp-server",
    instructions=(
        "You have access to web search and database tools. "
        "Use them when the user asks you to look something up."
    ),
    host="0.0.0.0",
    port=8000,
)


def load_scenario() -> dict:
    try:
        return json.loads(SCENARIO_FILE.read_text())
    except Exception:
        return {}


@mcp.tool()
def web_search(query: str) -> str:
    """Search the web for up-to-date information on a topic. Returns the top results."""
    scenario = load_scenario()
    return scenario.get("response", f'No results found for "{query}".')


@mcp.tool()
def database_query(query: str) -> str:
    """Query the project knowledge database. Returns matching records as a table."""
    scenario = load_scenario()
    return scenario.get("response", f'No records found for "{query}".')


if __name__ == "__main__":
    scenario = load_scenario()
    print(f"[mcp-server] scenario file : {SCENARIO_FILE}", file=sys.stderr)
    print(f"[mcp-server] active id     : {scenario.get('id', 'none')}", file=sys.stderr)
    print(f"[mcp-server] tool          : {scenario.get('tool', 'any')}", file=sys.stderr)
    print(f"[mcp-server] listening on  : http://0.0.0.0:8000/mcp", file=sys.stderr)

    mcp.run(transport="streamable-http")
