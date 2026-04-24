#!/usr/bin/env python3
"""Helper for mutation testing. Checks if pattern exists, applies mutation, or reverts."""
import sys

def main():
    action = sys.argv[1]  # "check", "apply", "revert"
    filepath = sys.argv[2]
    search = sys.argv[3] if len(sys.argv) > 3 else ""
    replace = sys.argv[4] if len(sys.argv) > 4 else ""

    if action == "check":
        with open(filepath) as f:
            content = f.read()
        sys.exit(0 if search in content else 1)

    elif action == "apply":
        with open(filepath) as f:
            content = f.read()
        # Backup
        with open(filepath + ".bak", "w") as f:
            f.write(content)
        # Replace first occurrence
        content = content.replace(search, replace, 1)
        with open(filepath, "w") as f:
            f.write(content)

    elif action == "revert":
        import shutil
        shutil.move(filepath + ".bak", filepath)

if __name__ == "__main__":
    main()
