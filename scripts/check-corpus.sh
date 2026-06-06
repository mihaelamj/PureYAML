#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts"

PUREYAML_RUN_FULL_CORPUS=1 swift test --filter RealYAMLCorpusTests

mkdir -p "$ARTIFACT_DIR"

python3 - "$ROOT_DIR" "$ARTIFACT_DIR" <<'PY'
import json
import platform
import subprocess
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
artifact_dir = Path(sys.argv[2])
manifest_path = root / "Tests" / "Fixtures" / "real-yaml-corpus.yaml"

def parse_manifest(path):
    version = None
    description = None
    seeds = []
    current = None
    for raw_line in path.read_text().splitlines():
        if raw_line.startswith("version: "):
            version = int(raw_line.split(": ", 1)[1])
        elif raw_line.startswith("description: "):
            description = raw_line.split(": ", 1)[1]
        elif raw_line.startswith("  - id: "):
            if current is not None:
                seeds.append(current)
            current = {"id": raw_line.split(": ", 1)[1]}
        elif current is not None and raw_line.startswith("    "):
            key, value = raw_line.strip().split(": ", 1)
            if key in {"byteCount", "lineCount"}:
                current[key] = int(value)
            else:
                current[key] = value
    if current is not None:
        seeds.append(current)
    return {"version": version, "description": description, "seeds": seeds}

def command_output(command):
    try:
        return subprocess.check_output(
            command,
            cwd=root,
            stderr=subprocess.STDOUT,
            text=True,
        ).strip()
    except Exception as error:
        return f"unavailable: {error}"

manifest = parse_manifest(manifest_path)
seeds = manifest["seeds"]
categories = Counter(seed["category"] for seed in seeds)
tiers = Counter(seed["tier"] for seed in seeds)
sizes = Counter(seed["size"] for seed in seeds)

summary = {
    "seedCount": len(seeds),
    "defaultSeeds": tiers["default"],
    "fullSeeds": tiers["full"],
    "totalBytes": sum(seed["byteCount"] for seed in seeds),
    "totalLines": sum(seed["lineCount"] for seed in seeds),
    "categories": dict(sorted(categories.items())),
    "sizes": dict(sorted(sizes.items())),
}
generated_summary = {
    "validDocumentSeed": "0x505559414D4C",
    "validDocumentCases": 100,
    "mutationSourceTier": "default",
    "mutationSourceSeeds": tiers["default"],
    "mutationClasses": [
        "missingMappingSpace",
        "tabIndentation",
        "missingSequenceSpace",
        "unterminatedQuotedString",
        "undefinedAlias",
    ],
    "totalMutations": tiers["default"] * 5,
    "status": "passed",
}

(artifact_dir / "real-seed-manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n"
)
(artifact_dir / "seeds.json").write_text(
    json.dumps(
        {
            "generated": generated_summary,
            "realSeeds": [{"id": seed["id"], "tier": seed["tier"]} for seed in seeds],
        },
        indent=2,
        sort_keys=True,
    ) + "\n"
)
(artifact_dir / "generated-validation-summary.json").write_text(
    json.dumps(generated_summary, indent=2, sort_keys=True) + "\n"
)

def yaml_mapping(mapping, indentation=0):
    lines = []
    spaces = " " * indentation
    for key, value in mapping.items():
        if isinstance(value, dict):
            lines.append(f"{spaces}{key}:")
            lines.extend(yaml_mapping(value, indentation + 2))
        elif isinstance(value, list):
            lines.append(f"{spaces}{key}:")
            for item in value:
                lines.append(f"{spaces}  - {item}")
        else:
            lines.append(f"{spaces}{key}: {value}")
    return lines

(artifact_dir / "real-seed-summary.yaml").write_text(
    "\n".join(yaml_mapping(summary)) + "\n"
)
(artifact_dir / "generated-validation-summary.yaml").write_text(
    "\n".join(yaml_mapping(generated_summary)) + "\n"
)
(artifact_dir / "environment.txt").write_text(
    "\n".join(
        [
            f"python: {platform.python_version()}",
            f"platform: {platform.platform()}",
            f"swift: {command_output(['swift', '--version'])}",
            f"git: {command_output(['git', 'rev-parse', 'HEAD'])}",
            f"git_status: {command_output(['git', 'status', '--short'])}",
        ]
    ) + "\n"
)

print(f"corpus artifacts: {artifact_dir}")
PY
