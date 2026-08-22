#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

readme_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/kagerou-readme-check.XXXXXX")
cleanup() {
  if [[ -n "${readme_check_dir:-}" && -d "$readme_check_dir" ]]; then
    rm -rf -- "$readme_check_dir"
  fi
}
trap cleanup EXIT

awk -v output_dir="$readme_check_dir" '
  BEGIN {
    in_block = 0
    block_count = 0
  }
  /^```mojo$/ {
    if (in_block) {
      print "README.md contains a nested fenced Mojo block." > "/dev/stderr"
      exit 2
    }
    in_block = 1
    block_count += 1
    output_file = sprintf("%s/readme_block_%d.mojo", output_dir, block_count)
    printf "%s", "" > output_file
    next
  }
  in_block && /^```$/ {
    close(output_file)
    in_block = 0
    next
  }
  in_block {
    print $0 > output_file
  }
  END {
    if (in_block) {
      print "README.md has an unterminated fenced Mojo block." > "/dev/stderr"
      exit 2
    }
    print block_count > (output_dir "/block_count")
  }
' README.md

block_count=$(<"$readme_check_dir/block_count")
if [[ $block_count -eq 0 ]]; then
  printf '%s\n' 'README.md contains no fenced Mojo blocks.' >&2
  exit 1
fi

for ((block_number = 1; block_number <= block_count; block_number++)); do
  source_file="$readme_check_dir/readme_block_$block_number.mojo"
  output_file="$readme_check_dir/block_$block_number"
  if ! mojo build -I src "$source_file" -o "$output_file"; then
    printf 'README Mojo block %d failed to compile.\n' "$block_number" >&2
    exit 1
  fi
done

printf 'Compiled %d README Mojo block(s) successfully.\n' "$block_count"
