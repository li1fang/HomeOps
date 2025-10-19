#!/usr/bin/env python3
"""Run ansible-playbook --syntax-check over all playbooks."""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Syntax-check playbooks recursively")
    parser.add_argument("--ansible-playbook", dest="ansible_playbook", required=True)
    parser.add_argument("--inventory", required=True)
    parser.add_argument("--playbooks-root", default="playbooks")
    args = parser.parse_args()

    root = Path(args.playbooks_root)
    playbooks = sorted(root.rglob("*.yml"))
    skip_dirs = {Path("k8s")}
    skip_files = {Path("run-sealos-langgraph.yml")}
    for playbook in playbooks:
        rel = playbook.relative_to(root)
        if any(rel == skip or rel.is_relative_to(skip) for skip in skip_dirs):
            continue
        if rel in skip_files:
            continue
        print(f"syntax-check {playbook}")
        subprocess.check_call([args.ansible_playbook, "-i", args.inventory, "--syntax-check", str(playbook)])


if __name__ == "__main__":
    main()
