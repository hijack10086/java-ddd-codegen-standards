#!/usr/bin/env python3
"""Run the project's own compile / static-check / test commands.

The script never formats code, installs tools, edits build files, or skips tests.
Use --dry-run to preview commands before executing them.

Usage:
  python lint_gate.py --root <project> [--dry-run] [--extra-args "-Dskip..."] [--check "cmd"]
"""
from __future__ import annotations

import argparse
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

FORBIDDEN_ARGS = ("skiptests", "-x test", "-xtest", "--exclude-task test", "-dmaven.test.skip=true")


def wrapper(root: Path, names: tuple[str, ...]) -> str | None:
    for name in names:
        if (root / name).is_file():
            return name
    return None


def build_command(root: Path) -> tuple[list[str] | None, str]:
    if (root / "pom.xml").is_file() or wrapper(root, ("mvnw", "mvnw.cmd")):
        w = wrapper(root, ("mvnw.cmd", "mvnw")) if sys.platform == "win32" else wrapper(root, ("mvnw",))
        if w:
            cmd = ["cmd.exe", "/c", w, "-B", "verify"] if sys.platform == "win32" \
                else [str(root / w), "-B", "verify"]
            return cmd, f"Maven wrapper ({w})"
        if shutil.which("mvn"):
            return ["mvn", "-B", "verify"], "system Maven"
        return None, "pom.xml found but neither mvnw nor mvn is available"

    if any((root / n).is_file() for n in ("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts")):
        w = wrapper(root, ("gradlew.bat",)) if sys.platform == "win32" else wrapper(root, ("gradlew",))
        if w:
            cmd = ["cmd.exe", "/c", w, "test"] if sys.platform == "win32" \
                else [str(root / w), "test"]
            return cmd, f"Gradle wrapper ({w})"
        if shutil.which("gradle"):
            return ["gradle", "test"], "system Gradle"
        return None, "Gradle build file found but neither gradlew nor gradle is available"

    return None, "no pom.xml / build.gradle(.kts) found; nothing to verify"


def run(cmd: list[str], root: Path, dry_run: bool, label: str) -> int:
    print(f"[CMD] {label}: {' '.join(shlex.quote(part) for part in cmd)}")
    if dry_run:
        print("[SKIP] dry-run, command not executed")
        return 0
    started = time.time()
    try:
        proc = subprocess.run(cmd, cwd=str(root), capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=900)
    except subprocess.TimeoutExpired:
        print(f"[FAIL] {label}: timed out after 900s")
        return 1
    except OSError as exc:
        print(f"[FAIL] {label}: cannot execute ({exc})")
        return 1
    elapsed = time.time() - started
    output = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip().splitlines()
    tail = output[-25:] if output else ["(no output)"]
    print(f"[INFO] {label}: exit={proc.returncode} elapsed={elapsed:.1f}s")
    for line in tail:
        print(f"    {line}")
    if proc.returncode != 0:
        print(f"[FAIL] {label}: build/test failed, fix the code and rerun")
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile and test gate for Java projects")
    parser.add_argument("--root", default=".", help="project root (default: current directory)")
    parser.add_argument("--dry-run", action="store_true", help="print commands without executing")
    parser.add_argument("--extra-args", default="", help="extra arguments appended to the main command")
    parser.add_argument("--check", action="append", default=[],
                        help="additional project command, repeatable, e.g. --check 'mvn spotless:check'")
    # Values such as -DskipTests start with a dash; argparse would treat them as options.
    raw_argv = sys.argv[1:]
    normalized = []
    index = 0
    while index < len(raw_argv):
        token = raw_argv[index]
        if token == "--extra-args" and index + 1 < len(raw_argv):
            normalized.append("--extra-args=" + raw_argv[index + 1])
            index += 2
        else:
            normalized.append(token)
            index += 1
    args = parser.parse_args(normalized)

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"[FAIL] root is not a directory: {root}")
        return 1

    extra = shlex.split(args.extra_args)
    joined = (args.extra_args + " " + " ".join(args.check)).lower()
    for forbidden in FORBIDDEN_ARGS:
        if forbidden in joined:
            print(f"[BLOCK] skipping tests is not allowed: '{forbidden}'")
            return 1

    cmd, label = build_command(root)
    if cmd is None:
        print(f"[FAIL] {label}")
        return 1
    if extra:
        cmd = cmd + extra

    results: list[int] = []
    results.append(run(cmd, root, args.dry_run, label))
    for index, raw in enumerate(args.check, start=1):
        check_cmd = shlex.split(raw)
        if check_cmd:
            results.append(run(check_cmd, root, args.dry_run, f"extra check #{index}"))

    failed = sum(1 for code in results if code != 0)
    print(f"[RESULT] commands={len(results)} failed={failed} "
          f"-> {'PASS' if failed == 0 else 'FAIL'}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
