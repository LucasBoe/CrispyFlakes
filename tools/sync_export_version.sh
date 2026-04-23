#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mode="${1:-sync}"
project_file="project.godot"
export_file="export_presets.cfg"
for_next_commit="${SYNC_FOR_NEXT_COMMIT:-0}"

if [[ "$mode" == "sync-next" ]]; then
  mode="sync"
  for_next_commit="1"
fi

if [[ ! -f "$project_file" ]]; then
  echo "Missing $project_file" >&2
  exit 1
fi

if [[ ! -f "$export_file" ]]; then
  echo "Missing $export_file" >&2
  exit 1
fi

find_nearest_semver_tag() {
  git describe \
    --tags \
    --abbrev=0 \
    --match 'v[0-9]*.[0-9]*.[0-9]*' \
    --match '[0-9]*.[0-9]*.[0-9]*' \
    2>/dev/null || true
}

derive_version() {
  local nearest_tag commit_count distance base_version

  nearest_tag="$(find_nearest_semver_tag)"

  if [[ -n "$nearest_tag" ]]; then
    base_version="${nearest_tag#v}"
    distance="$(git rev-list "${nearest_tag}..HEAD" --count)"
    if [[ "$mode" == "sync" && "$for_next_commit" == "1" ]]; then
      distance="$((distance + 1))"
    fi
    if [[ "$distance" -eq 0 ]]; then
      echo "${base_version}"
    else
      echo "${base_version}-dev.${distance}"
    fi
    return
  fi

  commit_count="$(git rev-list --count HEAD)"
  if [[ "$mode" == "sync" && "$for_next_commit" == "1" ]]; then
    commit_count="$((commit_count + 1))"
  fi
  echo "0.0.0-dev.${commit_count}"
}

sed_inplace() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

require_pattern() {
  local pattern="$1" file="$2"
  if ! grep -qE "$pattern" "$file"; then
    echo "Expected pattern not found in $file: $pattern" >&2
    exit 1
  fi
}

version="$(derive_version)"
filename_version="${version//./_}"
filename_version="${filename_version//-/_}"

if [[ "$mode" == "check" ]]; then
  ok=true
  grep -qF "config/version=\"${version}\""                            "$project_file" || ok=false
  grep -qF "application/short_version=\"${version}\""                "$export_file"  || ok=false
  grep -qF "application/version=\"${version}\""                      "$export_file"  || ok=false
  grep -qF "export_path=\"builds/CrispyFlakes_${filename_version}.dmg\"" "$export_file"  || ok=false

  if [[ "$ok" == "false" ]]; then
    echo "Version metadata is out of sync. Run \`bash tools/sync_export_version.sh sync-next\` before committing, or install the Git hook." >&2
    exit 1
  fi
  echo "Version metadata is in sync for $version"

elif [[ "$mode" == "sync" ]]; then
  require_pattern '^config/version=".*"$'          "$project_file"
  require_pattern '^application/short_version=".*"$' "$export_file"
  require_pattern '^application/version=".*"$'     "$export_file"
  require_pattern '^export_path="builds/.*"$'      "$export_file"

  # Escape & and \ in replacement strings (. and - are safe in sed replacement)
  esc_ver=$(printf '%s' "$version"          | sed 's/[&\]/\\&/g')
  esc_fn=$(printf '%s'  "$filename_version" | sed 's/[&\]/\\&/g')

  sed_inplace "s|^config/version=\".*\"\$|config/version=\"${esc_ver}\"|"                              "$project_file"
  sed_inplace "s|^application/short_version=\".*\"\$|application/short_version=\"${esc_ver}\"|"       "$export_file"
  sed_inplace "s|^application/version=\".*\"\$|application/version=\"${esc_ver}\"|"                   "$export_file"
  sed_inplace "s|^export_path=\"builds/.*\"\$|export_path=\"builds/CrispyFlakes_${esc_fn}.dmg\"|"    "$export_file"

  echo "Synchronized project and export metadata to version $version"

else
  echo "Unsupported mode: $mode" >&2
  exit 1
fi
