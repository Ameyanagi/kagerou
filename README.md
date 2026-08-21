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

The public slice provides constructor-validated geometry, explicit 2D transform
algebra, and SoA paths that flatten curves for a downstream raster backend.
Construction establishes finite-value invariants; ordinary reads and operations
trust stored state, while explicit `validate()` methods provide an opt-in
checkpoint after unusual low-level mutation. Result-producing operations
continue to reject floating-point overflow. It has no surface, color, plotting,
windowing, or GPU dependency.

## Install

Add Kagerou to another Pixi project from the Mojo ecosystem channel:

```sh
# In your pixi project
pixi project channel add https://ameyanagi.github.io/mojo-channel
pixi add mojo-kagerou
```

The Mojo import name is `kagerou`, while the package name is `mojo-kagerou`;
the package publishes with the ecosystem's Wave releases.

Alternatively, work from a source checkout:

```sh
git clone https://github.com/Ameyanagi/kagerou
cd kagerou
pixi install --locked
pixi run check
```

Run your own file against the checkout with
`pixi run mojo run -I src your_file.mojo`.

## Quickstart

```mojo
from kagerou import AffineTransform, PathBuilder, PathVerb, Point


def main() raises:
    var builder = PathBuilder()
    builder.move_to(Point(0.0, 0.0))
    builder.line_to(Point(80.0, 0.0))
    builder.line_to(Point(40.0, 60.0))
    builder.close()

    # Compose transforms in application order with followed_by; there is
    # deliberately no order-ambiguous chaining hidden here.
    var transform = AffineTransform.translation(12.0, 8.0).followed_by(
        AffineTransform.scale(2.0, 2.0)
    )
    var polyline = builder^.finish().transformed(transform).flattened(0.25)

    var segment_count = 0
    for verb in polyline.verbs():
        if verb == PathVerb.LINE:
            segment_count += 1
    print(segment_count)
```

The expected printed output is `2`. From the repository checkout, save the
program as `quickstart.mojo` and run it with
`pixi run mojo run -I src quickstart.mojo`.

## A real task

This example flattens a circle, walks the public SoA path storage, and sends
each vertex to a stand-in downstream consumer. Replace `_send_to_consumer` with
the vertex sink for a tessellator, renderer, or file format.

```mojo
from kagerou import PathBuilder, Point


def _send_to_consumer(x: Float64, y: Float64):
    print("vertex", x, y)


def main() raises:
    var circle = PathBuilder.circle(Point(100.0, 100.0), 40.0)
    var polyline = circle.flattened(0.25)
    var coordinates = polyline.coordinates()
    var coordinate_index = 0
    var vertex_count = 0

    for verb in polyline.verbs():
        for point_index in range(verb.point_count()):
            var offset = coordinate_index + 2 * point_index
            _send_to_consumer(coordinates[offset], coordinates[offset + 1])
            vertex_count += 1
        coordinate_index += 2 * verb.point_count()

    var bounds = polyline.bounds()
    print("vertices:", vertex_count)
    print(
        "bounds:",
        bounds.min_x(),
        bounds.min_y(),
        bounds.max_x(),
        bounds.max_y(),
    )
```

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
