#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import sys


README = "README.md"

BLOCK_RE = re.compile(r"```mermaid\n(.*?)```", re.DOTALL)
CLASS_DEF_RE = re.compile(r"^\s*classDef\s+([A-Za-z][A-Za-z0-9_]*)\s+(.+?)\s*$")
NODE_RE = re.compile(r"^\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:\[.+\]|\(.+\)|\{.+\})\s*:::\s*([A-Za-z][A-Za-z0-9_]*)\s*$")
UNCLASSED_NODE_RE = re.compile(r"^\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:\[.+\]|\(.+\)|\{.+\})\s*$")
EDGE_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)\s*(?:-->|~~~)\s*([A-Za-z][A-Za-z0-9_]*)\b")


def fail(message):
    print(f"roadmap: {message}", file=sys.stderr)
    return 1


def mermaid_blocks():
    with open(README, encoding="utf-8") as handle:
        return BLOCK_RE.findall(handle.read())


def class_defs(block):
    defs = {}
    for line in block.splitlines():
        match = CLASS_DEF_RE.match(line)
        if match:
            defs[match.group(1)] = match.group(2)
    return defs


def validate_block(block, index, legend_defs):
    defs = class_defs(block)
    if defs != legend_defs:
        return fail(f"mermaid block {index} classDef palette differs from legend")

    nodes = set()
    saw_non_class_def = False
    for raw_line in block.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("%%") or line.startswith("flowchart"):
            continue
        if line.startswith("classDef"):
            if saw_non_class_def:
                return fail(f"mermaid block {index} has classDef after nodes or edges")
            continue
        saw_non_class_def = True

        node = NODE_RE.match(raw_line)
        if node:
            node_class = node.group(2)
            if node_class not in legend_defs:
                return fail(f"mermaid block {index} uses unknown class {node_class}")
            nodes.add(node.group(1))
            continue

        if UNCLASSED_NODE_RE.match(raw_line):
            return fail(f"mermaid block {index} has unclassed node: {line}")

        for edge in EDGE_RE.finditer(raw_line):
            nodes.add(edge.group(1))
            nodes.add(edge.group(2))

    defined_nodes = set()
    for raw_line in block.splitlines():
        node = NODE_RE.match(raw_line)
        if node:
            defined_nodes.add(node.group(1))

    for edge in EDGE_RE.finditer(block):
        left = edge.group(1)
        right = edge.group(2)
        if left not in defined_nodes or right not in defined_nodes:
            return fail(f"mermaid block {index} has edge with undefined node: {left} to {right}")

    return 0


def repo_name():
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"]
    if not shutil.which("gh"):
        return None
    result = subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def epic_numbers(repo):
    if not repo or not shutil.which("gh"):
        if os.environ.get("GITHUB_ACTIONS"):
            raise RuntimeError("gh is required in CI to verify epic coverage")
        print("roadmap: skipping GitHub epic coverage because gh is unavailable", file=sys.stderr)
        return []

    result = subprocess.run(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            repo,
            "--label",
            "epic",
            "--state",
            "all",
            "--limit",
            "1000",
            "--json",
            "number",
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        if os.environ.get("GITHUB_ACTIONS"):
            raise RuntimeError(result.stderr.strip())
        print("roadmap: skipping GitHub epic coverage because gh issue list failed", file=sys.stderr)
        return []
    return [issue["number"] for issue in json.loads(result.stdout)]


def main():
    blocks = mermaid_blocks()
    if not blocks:
        return fail("README has no Mermaid blocks")

    first = blocks[0]
    if "LDone[Done]" not in first or "LTodo[Todo]" not in first:
        return fail("first Mermaid block must be the shared legend")

    legend_defs = class_defs(first)
    required = {"done", "review", "active", "next", "partial", "todo"}
    missing = required.difference(legend_defs)
    if missing:
        return fail("legend is missing classes: " + ", ".join(sorted(missing)))

    for index, block in enumerate(blocks, start=1):
        result = validate_block(block, index, legend_defs)
        if result != 0:
            return result

    combined = "\n".join(blocks)
    try:
        numbers = epic_numbers(repo_name())
    except RuntimeError as error:
        return fail(str(error))
    for number in numbers:
        if f"#{number}" not in combined:
            return fail(f"epic issue #{number} is missing from README Mermaid diagrams")

    print("roadmap: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
