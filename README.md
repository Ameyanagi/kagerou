# Kagerou

> **Experimental — API may change before v1.0.**

Low-level native 2D rendering for Mojo.

## Scope

Kagerou is a renderer rather than a GUI toolkit, window system, plotting library, or application framework.

The current implementation milestone is intentionally narrow: establish
validated continuous `Point` values and `AffineTransform` application,
composition, rotation, and inversion. Paths remain gated on the separate K0.4
tolerance contract; strokes, fills, clipping, and the correctness-first software
surface follow through later v0.1 gates.
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

The first public slice provides constructor-validated continuous `Point`
geometry and explicit 2D `AffineTransform` algebra. Public
observations and operations revalidate current storage and reject floating-point
overflow, accounting for Mojo 1.0's externally mutable struct fields. It has no
surface, color, plotting, windowing, or GPU dependency.

```mojo
from kagerou import AffineTransform, Point

var transform = AffineTransform.rotation(0.5).followed_by(
    AffineTransform.translation(12.0, 8.0)
)
var restored = transform.inverted().apply(transform.apply(Point(4.0, 6.0)))
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
