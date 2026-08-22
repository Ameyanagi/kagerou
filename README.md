# Kagerou

> **Experimental — API may change before v1.0.**

Low-level native 2D rendering for Mojo.

## Scope

Kagerou is a renderer rather than a GUI toolkit, window system, plotting
library, or application framework.

The current implementation milestone provides validated continuous geometry,
affine transforms, immutable paths, stateful path construction, conservative
bounds, deterministic curve flattening, and an owned premultiplied RGBA8
software surface with clipped solid fills and source-over compositing. Stroke
geometry, antialiased coverage, and clip stacks follow through later v0.1
gates. The current binary-coverage path rasterizer supports nonzero/even-odd
fills, implicit closure, rectangular pixel clips, and deterministic curves via
the existing flattening tolerance.
The project is independently installable and does not require any application
from the wider ecosystem.

The public slice provides constructor-validated geometry, explicit 2D transform
algebra, SoA paths, and checked owned pixel storage. Construction establishes
finite geometry, layout, and premultiplication invariants; ordinary reads and
operations trust stored state, while explicit `validate()` methods provide an
opt-in checkpoint after unusual low-level mutation. Surface dimensions and
strides are overflow-checked, pixel access is bounds-checked, and signed solid
spans and rectangles clip without overflowing their end coordinates. Kagerou
also rasterizes paths by a documented pixel-center rule and contains every
write in both the surface and an optional `PixelRect`. It still has no plotting,
windowing, GPU, Sen, or Akari dependency.

For encoder and backend integration, `Surface.bytes()` returns a borrowed
read-only view of the exact owned storage, including stride padding.
`row_bytes()` reports visible `width * 4` bytes separately from `stride`.

## Install

Add Kagerou to another Pixi project from the Mojo ecosystem channel:

```sh
# In your pixi project
pixi project channel add https://ameyanagi.github.io/mojo-channel
pixi add mojo-kagerou
```

The Mojo import name is `kagerou`, while the package name is `mojo-kagerou`.
Package releases are distributed through the ecosystem channel.

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

This example draws a clipped, premultiplied source-over circle into an owned
surface. `blend_path` uses the full surface; `blend_path_clipped` adds an
overflow-safe integer clip without introducing global renderer state.

```mojo
from kagerou import PixelRect, PathBuilder, Point, Rgba8, Surface


def main() raises:
    var surface = Surface(200, 160)
    var circle = PathBuilder.circle(Point(100.0, 80.0), 48.0)
    var blue = Rgba8(UInt8(16), UInt8(48), UInt8(96), UInt8(128))
    surface.blend_path_clipped(
        circle,
        PixelRect(60, 30, 80, 100),
        blue,
    )
    print(surface.pixel(100, 80))
```

The expected output is `Rgba8(16, 48, 96, 128)`.

## Development

Install [Pixi](https://pixi.sh/), then run:

```sh
pixi install --locked
pixi run check
pixi run example
pixi run bench-surface
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
- `benchmarks/`: reproducible large-surface performance methodology and program
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
