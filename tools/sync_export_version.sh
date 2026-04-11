#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mode="${1:-sync}"
project_file="project.godot"
export_file="export_presets.cfg"

if [[ ! -f "$project_file" ]]; then
  echo "Missing $project_file" >&2
  exit 1
fi

if [[ ! -f "$export_file" ]]; then
  echo "Missing $export_file" >&2
  exit 1
fi

derive_version() {
  local exact_tag latest_tag commit_count short_hash distance base_version

  exact_tag="$(git tag --points-at HEAD | rg '^v?[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
  if [[ -n "$exact_tag" ]]; then
    echo "${exact_tag#v}"
    return
  fi

  latest_tag="$(git tag --sort=-version:refname | rg '^v?[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
  short_hash="$(git rev-parse --short HEAD)"

  if [[ -n "$latest_tag" ]]; then
    base_version="${latest_tag#v}"
    distance="$(git rev-list "${latest_tag}..HEAD" --count)"
    echo "${base_version}-dev.${distance}.g${short_hash}"
    return
  fi

  commit_count="$(git rev-list --count HEAD)"
  echo "0.0.0-dev.${commit_count}.g${short_hash}"
}

version="$(derive_version)"
filename_version="${version//./_}"
filename_version="${filename_version//-/_}"

python3 - <<'PY' "$mode" "$project_file" "$export_file" "$version" "$filename_version"
from pathlib import Path
import re
import sys

mode = sys.argv[1]
project_path = Path(sys.argv[2])
export_path = Path(sys.argv[3])
version = sys.argv[4]
filename_version = sys.argv[5]

project_text = project_path.read_text()
updated_project_text, count = re.subn(
    r'^config/version=".*"$',
    f'config/version="{version}"',
    project_text,
    flags=re.MULTILINE,
)
if count == 0:
    raise SystemExit("Expected to replace config/version in project.godot")

export_text = export_path.read_text()
updated_export_text = export_text
replacements = {
    r'^application/short_version=".*"$': f'application/short_version="{version}"',
    r'^application/version=".*"$': f'application/version="{version}"',
    r'^export_path="builds/.*"$': f'export_path="builds/CrispyFlakes_{filename_version}.dmg"',
}

for pattern, replacement in replacements.items():
    updated_export_text, count = re.subn(pattern, replacement, updated_export_text, flags=re.MULTILINE)
    if count == 0:
        raise SystemExit(f"Expected to replace pattern: {pattern}")

if mode == "check":
    if project_text != updated_project_text or export_text != updated_export_text:
        raise SystemExit(
            "Version metadata is out of sync. Run `bash tools/sync_export_version.sh` and commit the result."
        )
elif mode == "sync":
    project_path.write_text(updated_project_text)
    export_path.write_text(updated_export_text)
else:
    raise SystemExit(f"Unsupported mode: {mode}")
PY

if [[ "$mode" == "check" ]]; then
  echo "Version metadata is in sync for $version"
else
  echo "Synchronized project and export metadata to version $version"
fi
