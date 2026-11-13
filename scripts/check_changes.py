#!/usr/bin/env python3
"""Static DDD layering / naming / red-line checker for Java sources.

Usage:
  python check_changes.py --root <project> [--paths FILE ...]
  python check_changes.py --root <project> --layer-map domain=com.foo.core

Default: inspect changed and untracked files reported by `git status --porcelain`.
Use --paths when the target is not a git repository.

Output markers: [BLOCK] must fix, [WARN] needs human review, [INFO] context.
Exit codes: 0 = no blocking violations, 1 = blocking violations or check failure.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

LAYER_ALIASES = {
    "domain": ("domain", "model", "core"),
    "application": ("application", "app", "usecase", "usecases", "service", "services"),
    "interfaces": ("interfaces", "interface", "adapter", "adapters", "rest", "controller", "web", "api"),
    "infrastructure": ("infrastructure", "infra", "persistence", "dal"),
}

BANNED_IMPORTS = {
    "domain": (
        r"org\.springframework", r"javax\.persistence", r"jakarta\.persistence",
        r"org\.mybatis", r"com\.baomidou", r"org\.apache\.ibatis",
        r"com\.fasterxml\.jackson", r"javax\.servlet", r"jakarta\.servlet",
        r"\.interfaces\.", r"\.application\.", r"\.infrastructure\.",
        r"lombok\.Data", r"lombok\.Setter", r"lombok\.Builder", r"lombok\.AllArgsConstructor",
    ),
    "application": (
        r"javax\.persistence", r"jakarta\.persistence", r"org\.mybatis",
        r"com\.baomidou", r"\.interfaces\.", r"\.infrastructure\.",
    ),
    "interfaces": (
        r"\.infrastructure\.", r"\.domain\.repository\.", r"\.domain\.gateway\.",
        r"javax\.persistence", r"jakarta\.persistence",
    ),
    "infrastructure": (r"\.interfaces\.", r"\.application\."),
}

CONTENT_RULES = (
    (r"System\.out\.print", "BLOCK", "use SLF4J instead of System.out"),
    (r"\.printStackTrace\(", "BLOCK", "log with cause instead of printStackTrace"),
    (r"java\.util\.Date|SimpleDateFormat|java\.sql\.Timestamp", "BLOCK", "use java.time types"),
    (r"catch\s*\([^)]*\)\s*\{\s*\}", "BLOCK", "empty catch block"),
    (r"@Autowired[^\n]*\n\s*private\s", "BLOCK", "field injection; use constructor injection"),
    (r"return\s+null\s*;", "WARN", "returning null; prefer Optional or an empty collection"),
    (r"\bTODO\b|\bFIXME\b", "WARN", "unresolved TODO/FIXME marker"),
)

IMPORT_RE = re.compile(r"^\s*import\s+(?:static\s+)?([\w.]+)\s*;", re.MULTILINE)
PACKAGE_RE = re.compile(r"^\s*package\s+([\w.]+)\s*;", re.MULTILINE)


def collect_files(root: Path, explicit: list[str] | None) -> list[str]:
    if explicit:
        return [p.replace("\\", "/") for p in explicit]
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"git is unavailable ({exc}); pass --paths explicitly") from exc
    if proc.returncode != 0:
        raise RuntimeError("not a git repository; pass --paths explicitly")
    files = []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        name = line[3:].strip()
        if " -> " in name:
            name = name.split(" -> ", 1)[1]
        name = name.strip('"')
        files.append(name.replace("\\", "/"))
    return files


def parse_layer_map(raw: str | None) -> dict[str, str]:
    result = {}
    if not raw:
        return result
    for item in raw.split(","):
        if "=" not in item:
            continue
        layer, prefix = item.split("=", 1)
        layer = layer.strip().lower()
        if layer in LAYER_ALIASES and prefix.strip():
            result[layer] = prefix.strip()
    return result


def detect_layer(rel_path: str, package: str | None, layer_map: dict[str, str]) -> str | None:
    for layer, prefix in layer_map.items():
        if package and (package == prefix or package.startswith(prefix + ".")):
            return layer
    for part in Path(rel_path).parts:
        token = part.lower()
        for layer, aliases in LAYER_ALIASES.items():
            if token in aliases:
                return layer
    return None


def check_file(root: Path, rel_path: str, layer_map: dict[str, str]) -> list[tuple[str, str]]:
    findings: list[tuple[str, str]] = []
    path = root / rel_path
    if not path.is_file():
        return findings
    try:
        content = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError as exc:
        return [("BLOCK", f"{rel_path}: cannot read file ({exc})")]

    package_match = PACKAGE_RE.search(content)
    package = package_match.group(1) if package_match else None
    layer = detect_layer(rel_path, package, layer_map)
    filename = path.name

    if layer is None:
        findings.append(("WARN", f"{rel_path}: layer not recognized; skipped dependency rules. "
                                "Use --layer-map to declare custom package prefixes."))
    else:
        findings.append(("INFO", f"{rel_path}: layer={layer}"))
        for pattern in BANNED_IMPORTS.get(layer, ()):
            for imported in IMPORT_RE.findall(content):
                if re.search(pattern, imported):
                    findings.append(("BLOCK", f"{rel_path}: [{layer}] forbidden import '{imported}' "
                                              f"(rule {pattern})"))
                    break

        if layer == "domain":
            if re.search(r"@(Data|Setter|Builder|AllArgsConstructor)\b", content):
                findings.append(("BLOCK", f"{rel_path}: [domain] mutating Lombok annotation breaks invariants"))
            if filename.endswith("Impl.java"):
                findings.append(("BLOCK", f"{rel_path}: implementation class must live in infrastructure"))
            if filename.endswith(("PO.java", "DO.java", "Entity.java")):
                findings.append(("BLOCK", f"{rel_path}: persistence object must live in infrastructure"))
            if filename.endswith("Repository.java") and not re.search(r"\binterface\s+\w+Repository\b", content):
                findings.append(("BLOCK", f"{rel_path}: repository port in domain must be an interface"))
        if layer in ("domain", "interfaces") and "@Transactional" in content:
            findings.append(("BLOCK", f"{rel_path}: [{layer}] transaction boundary belongs to application only"))
        if layer in ("application", "interfaces", "domain") and filename.endswith(("PO.java", "DO.java")):
            findings.append(("BLOCK", f"{rel_path}: persistence object leaked into {layer}"))
        if layer == "interfaces" and any(
            re.search(r"\.(?:\w+Repository|\w+Mapper)\b", imported)
            for imported in IMPORT_RE.findall(content)
        ):
            findings.append(("BLOCK", f"{rel_path}: [interfaces] must not reference repositories/mappers"))

    for pattern, severity, message in CONTENT_RULES:
        if re.search(pattern, content):
            findings.append((severity, f"{rel_path}: {message}"))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Static DDD layering checker for Java changes")
    parser.add_argument("--root", default=".", help="project root (default: current directory)")
    parser.add_argument("--paths", nargs="*", default=None, help="explicit java files to check")
    parser.add_argument("--layer-map", default=None,
                        help="custom package prefixes, e.g. domain=com.foo.core,application=com.foo.app")
    parser.add_argument("--strict", action="store_true", help="treat WARN findings as blocking")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"[BLOCK] root is not a directory: {root}")
        return 1
    try:
        candidates = collect_files(root, args.paths)
    except RuntimeError as exc:
        print(f"[BLOCK] {exc}")
        return 1

    java_files = [f for f in candidates if f.lower().endswith(".java")]
    if not java_files:
        print("[INFO] no Java files in the change set; nothing to check")
        return 0

    all_findings: list[tuple[str, str]] = []
    layer_map = parse_layer_map(args.layer_map)
    for rel in java_files:
        all_findings.extend(check_file(root, rel, layer_map))

    blocks = [m for severity, m in all_findings if severity == "BLOCK"]
    warns = [m for severity, m in all_findings if severity == "WARN"]
    for severity, message in all_findings:
        if severity == "INFO":
            print(f"[INFO] {message}")
    for message in blocks:
        print(f"[BLOCK] {message}")
    for message in warns:
        print(f"[WARN] {message}")

    print(f"[RESULT] checked={len(java_files)} BLOCK={len(blocks)} WARN={len(warns)} "
          f"-> {'FAIL' if blocks or (args.strict and warns) else 'PASS'}")
    return 1 if blocks or (args.strict and warns) else 0


if __name__ == "__main__":
    sys.exit(main())
