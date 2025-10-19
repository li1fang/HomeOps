#!/usr/bin/env python3
"""Emit toolchain metadata for Gate0."""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def _read_version(cmd: list[str], first_line: bool = False) -> str:
    text = subprocess.check_output(cmd, text=True).strip()
    return text.splitlines()[0] if first_line and text else text


def main() -> None:
    parser = argparse.ArgumentParser(description="Capture tool versions for CI gating")
    parser.add_argument("--venv-path", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--ansible", required=True)
    parser.add_argument("--ansible-lint", required=False)
    parser.add_argument("--yamllint", required=False)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    from ansible import release  # type: ignore

    ansible_version = f"ansible [core {release.__version__}]"

    try:
        import ansiblelint  # type: ignore
    except ModuleNotFoundError:
        ansible_lint_version = _read_version([args.ansible_lint or "ansible-lint", "--version"])
    else:
        ansible_lint_version = f"ansible-lint {ansiblelint.__version__} (ansible-core {release.__version__})"

    try:
        import yamllint  # type: ignore
    except ModuleNotFoundError:
        yamllint_version = _read_version([args.yamllint or "yamllint", "--version"])
    else:
        yamllint_version = f"yamllint {yamllint.__version__}"

    entries = [
        ("VENV_PATH", args.venv_path),
        ("PYTHON_VERSION", _read_version([args.python, "--version"])),
        ("ANSIBLE_VERSION", ansible_version),
        ("ANSIBLE_LINT_VERSION", ansible_lint_version),
        ("YAMLLINT_VERSION", yamllint_version),
    ]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(f"{key}={value}" for key, value in entries) + "\n", encoding="utf-8")
    print(output_path.read_text(), end="")


if __name__ == "__main__":
    main()
