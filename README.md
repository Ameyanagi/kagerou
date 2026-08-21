# Kagerou

> **Experimental — API may change before v1.0.**

Low-level native 2D rendering for Mojo.

## Scope

Kagerou is a renderer rather than a GUI toolkit, window system, plotting
library, or application framework.

The current implementation milestone provides validated continuous geometry,
affine transforms, immutable paths, stateful path construction, conservative
bounds, and deterministic curve flattening under an explicit device-space
tolerance. Strokes, fills, clipping, and the correctness-first software surface
follow through later v0.1 gates.
The project is independently installable and does not require any application
from the wider ecosystem.

## Development

Install [Pixi](https://pixi.sh/), then run:

```sh
pixi install --locked
pixi run check
pixi run example
```

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `kagerou`. The eventual Conda distribution is
`mojo-kagerou`. Source lives under `src/kagerou/`, whose
`__init__.mojo` defines the package boundary.

The public slice provides constructor-validated geometry, explicit 2D transform
algebra, and SoA paths that flatten curves for a downstream raster backend.
Construction establishes finite-value invariants; ordinary reads and operations
trust stored state, while explicit `validate()` methods provide an opt-in
checkpoint after unusual low-level mutation. Result-producing operations
continue to reject floating-point overflow. It has no surface, color, plotting,
windowing, or GPU dependency.

```mojo
from kagerou import AffineTransform, PathBuilder, PathVerb, Point

var builder = PathBuilder()
builder.move_to(Point(0.0, 0.0))
builder.line_to(Point(80.0, 0.0))
builder.line_to(Point(40.0, 60.0))
builder.close()
var transform = AffineTransform.translation(12.0, 8.0)
var polyline = builder^.finish().transformed(transform).flattened(0.25)
var segment_count = 0
for verb in polyline.verbs():
    if verb == PathVerb.LINE:
        segment_count += 1
print(segment_count)
```

## Repository map

- `src/kagerou/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
