#!/usr/bin/env bash

set -euo pipefail

package_name="mojo-kagerou"
version="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)"
package_paths="$(find output -type f -name "${package_name}-${version}-*.conda" -print)"
package_count="$(printf '%s\n' "$package_paths" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ -z "$version" || "$package_count" -ne 1 ]]; then
  echo "expected exactly one ${package_name}-${version}-*.conda artifact, found ${package_count}" >&2
  exit 1
fi

package_path="$package_paths"
metadata_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kagerou-package.XXXXXX")"
trap 'rm -r -- "$metadata_root"' EXIT

pixi run rattler-build package extract "$package_path" --dest "$metadata_root" >/dev/null
index_json="${metadata_root}/info/index.json"
if [[ ! -f "$index_json" ]]; then
  echo "package does not contain info/index.json" >&2
  exit 1
fi

compiler_dependencies="$(grep -o '"mojo-compiler[^"]*"' "$index_json" || true)"
if [[ "$compiler_dependencies" != '"mojo-compiler ==1.0.0"' ]]; then
  echo "expected one exact mojo-compiler ==1.0.0 runtime dependency; found: ${compiler_dependencies:-none}" >&2
  exit 1
fi
