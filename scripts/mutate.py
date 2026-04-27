#!/usr/bin/env python3
"""Helper for mutation testing.

Supports batched apply/revert so multiple independent mutations across
different files can be applied at once and tested with a single test run.

Usage:
    mutate.py check <file> <search>           — exit 0 if pattern present
    mutate.py apply <file> <search> <replace> [token]
        Replaces first occurrence. Saves backup keyed by `token` (default
        derived from the file path) so a single file can hold multiple
        unrelated mutations across batches if ever needed.
    mutate.py revert <file> [token]           — restores from backup
    mutate.py revert-all                      — restores every .mut.bak file under cwd
"""
import os
import sys
from pathlib import Path


def _backup_path(filepath: str, token: str | None) -> str:
    if token:
        return f"{filepath}.mut.bak.{token}"
    return f"{filepath}.mut.bak"


def main():
    action = sys.argv[1]

    if action == "check":
        filepath, search = sys.argv[2], sys.argv[3]
        with open(filepath) as f:
            content = f.read()
        sys.exit(0 if search in content else 1)

    if action == "apply":
        filepath, search, replace = sys.argv[2], sys.argv[3], sys.argv[4]
        token = sys.argv[5] if len(sys.argv) > 5 else None
        with open(filepath) as f:
            content = f.read()
        # Only create backup once per file per batch — subsequent applies
        # mutate the already-mutated file in place so multiple mutations
        # to the same file (rare) compose.
        bak = _backup_path(filepath, token)
        if not os.path.exists(bak):
            with open(bak, "w") as f:
                f.write(content)
        if search not in content:
            sys.exit(2)  # Pattern vanished (e.g., earlier mutation removed it)
        new_content = content.replace(search, replace, 1)
        with open(filepath, "w") as f:
            f.write(new_content)
        return

    if action == "revert":
        filepath = sys.argv[2]
        token = sys.argv[3] if len(sys.argv) > 3 else None
        bak = _backup_path(filepath, token)
        if os.path.exists(bak):
            with open(bak) as f:
                original = f.read()
            with open(filepath, "w") as f:
                f.write(original)
            os.remove(bak)
        return

    if action == "revert-all":
        for bak in Path(".").rglob("*.mut.bak*"):
            original_path = str(bak).split(".mut.bak")[0]
            if os.path.exists(original_path):
                with open(bak) as f:
                    original = f.read()
                with open(original_path, "w") as f:
                    f.write(original)
            os.remove(bak)
        return

    print(f"Unknown action: {action}", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
