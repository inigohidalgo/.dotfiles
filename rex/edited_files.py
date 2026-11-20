"""List the files a running Claude Code session edited, most recent first.

Usage: edited_files.py CLAUDE_PID

The pid maps to its session through ~/.claude/sessions/<pid>.json. The session's
transcript, and its subagents' transcripts, are scanned for Edit / Write /
MultiEdit / NotebookEdit tool calls. Only files that still exist are printed.
"""

from __future__ import annotations

import json
import sys
from collections.abc import Iterator
from pathlib import Path

CLAUDE = Path.home() / ".claude"
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}


def session_id_for(pid: str) -> str:
    record = CLAUDE / "sessions" / f"{pid}.json"
    try:
        return json.loads(record.read_text())["sessionId"]
    except (OSError, KeyError, ValueError) as exc:
        sys.exit(f"no claude session record for pid {pid}: {exc}")


def transcripts(session_id: str) -> list[Path]:
    mains = list((CLAUDE / "projects").glob(f"*/{session_id}.jsonl"))
    if not mains:
        sys.exit(f"no transcript for claude session {session_id}")
    found: list[Path] = []
    for main in mains:
        found.append(main)
        found.extend((main.parent / session_id / "subagents").glob("*.jsonl"))
    return found


def edits(path: Path) -> Iterator[tuple[str, str]]:
    """Yield (timestamp, file_path) for each edit tool call in one transcript."""
    with path.open() as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("type") != "assistant":
                continue
            content = entry.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if block.get("type") != "tool_use" or block.get("name") not in EDIT_TOOLS:
                    continue
                inp = block.get("input") or {}
                target = inp.get("file_path") or inp.get("notebook_path")
                if target:
                    yield entry.get("timestamp", ""), target


def main(argv: list[str]) -> None:
    if len(argv) != 2:
        sys.exit(__doc__)
    latest: dict[str, str] = {}
    for transcript in transcripts(session_id_for(argv[1])):
        for stamp, target in edits(transcript):
            if stamp >= latest.get(target, ""):
                latest[target] = stamp
    for target, _ in sorted(latest.items(), key=lambda kv: kv[1], reverse=True):
        if Path(target).exists():
            print(target)


if __name__ == "__main__":
    main(sys.argv)
