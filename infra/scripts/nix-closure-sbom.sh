#!/usr/bin/env bash
# Generate SPDX 2.3 JSON SBOMs from Nix flake closures
#
# Usage:
#   nix-closure-sbom.sh .#laingville-devcontainer
#   nix-closure-sbom.sh .#laingville-devcontainer > sbom.json
#
# Input: Nix flake output (e.g., .#laingville-devcontainer)
# Output: SPDX 2.3 JSON to stdout
#
# The script uses `nix path-info --json --recursive` to get the full closure
# and extracts package names and versions from store paths.

set -euo pipefail

parse_store_path() {
  local path="$1"

  if [[ ! "$path" =~ ^/nix/store/ ]]; then
    return 0
  fi

  local basename="${path##*/}"

  if [[ ! "$basename" =~ ^[a-z0-9]+-(.+)-([0-9].*)$ ]]; then
    return 0
  fi

  local name="${BASH_REMATCH[1]}"
  local version="${BASH_REMATCH[2]}"

  echo "${name}|${version}"
}

generate_spdx_json() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local -a package_lines=()
  local first=true

  for pkg_spec in "$@"; do
    IFS='|' read -r name version <<< "$pkg_spec"

    local spdx_id="SPDXRef-Package-${name}-${version}"

    if [[ "$first" == true ]]; then
      first=false
    else
      package_lines+=(",")
    fi

    package_lines+=("    {")
    package_lines+=("      \"name\": \"$name\",")
    package_lines+=("      \"version\": \"$version\",")
    package_lines+=("      \"SPDXID\": \"$spdx_id\",")
    package_lines+=("      \"downloadLocation\": \"NOASSERTION\",")
    package_lines+=("      \"filesAnalyzed\": false")
    package_lines+=("    }")
  done

  cat << EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "creationInfo": {
    "created": "$timestamp",
    "creators": ["Tool: nix-closure-sbom"]
  },
  "packages": [
EOF

  printf '%s\n' "${package_lines[@]}"

  cat << EOF
  ]
}
EOF
}

generate_sbom_from_closure() {
  local flake_output="$1"

  local closure_json
  closure_json=$(nix path-info --json --recursive "$flake_output" 2> /dev/null || echo "[]")

  local -a packages=()

  while IFS= read -r path; do
    if [[ -n "$path" ]]; then
      local pkg_spec
      pkg_spec=$(parse_store_path "$path")
      if [[ -n "$pkg_spec" ]]; then
        packages+=("$pkg_spec")
      fi
    fi
  done < <(echo "$closure_json" | jq -r '.[] | .path' 2> /dev/null || true)

  generate_spdx_json "${packages[@]}"
}

main_nix_closure_sbom() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: nix-closure-sbom.sh <flake-output>" >&2
    return 1
  fi

  local flake_output="$1"
  generate_sbom_from_closure "$flake_output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main_nix_closure_sbom "$@"
fi
