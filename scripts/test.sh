#!/usr/bin/env bash
set -euo pipefail

for test_file in tests/test_*.mojo; do
  mojo run -I src "$test_file"
done

mkdir -p .pixi/test-bin
mojo build -I src examples/basic.mojo -o .pixi/test-bin/basic
mojo build -I src examples/flatten_curve.mojo -o .pixi/test-bin/flatten-curve

mojo build -I src examples/coverage_gallery.mojo -o .pixi/test-bin/coverage-gallery
