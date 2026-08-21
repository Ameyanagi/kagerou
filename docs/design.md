# Design

## Principles

- Mojo is the runtime implementation language.
- Prefer pure Mojo and safe standard-library APIs.
- Keep the root API small, typed, documented, and testable.
- Separate semantic contracts from optimized CPU, SIMD, GPU, terminal, or
  rendering backends.
- Establish correctness and reference fixtures before optimization.
- Make invalid public configuration unrepresentable when practical; otherwise
  reject it explicitly.
- Validate semantic values at construction, trust them thereafter, and expose an
  explicit validation checkpoint for unusual low-level mutation.
- Preserve source mappings, numerical tolerances, ownership, and provenance as
  first-class data when the domain requires them.
- Do not add a framework-wide array, executor, renderer, or application model.

## Tradeoffs

The project accepts a narrower initial feature set in exchange for reviewable
contracts and sparse dependencies. Generated tables are acceptable when their
sources, Unicode or data version, licenses, checksums, and deterministic update
procedure are committed. Consumers must not need the generator toolchain.

## Coordinate frame

Kagerou uses a y-down device-space coordinate frame: positive x points right,
positive y points down, and the origin is at the visual top-left. This matches
raster surfaces, tiny-skia, Skia, and kurbo's rendering usage.

The coordinate algebra still uses the usual signed formulas. Consequently,
`AffineTransform.rotation(radians)` is counterclockwise in the mathematical
sense of that algebra but appears **clockwise** on a y-down screen. A `Rect`'s
minimum corner is its visual top-left. The rectangle factory's emission order
has positive nonzero winding and therefore also appears clockwise on screen.

Data sources that plot in a y-up frame, including scientific plots, should
adapt once at the rendering boundary. The recommended Sen adapter is one line:
`AffineTransform.scale(1.0, -1.0).followed_by(AffineTransform.translation(0.0, height))`.

## Tolerance policy (K0.4, first slice)

Kagerou distinguishes structural facts, which remain exact, from geometric
approximations, which have an explicit device-space error budget.

| Comparison or operation | Policy |
| --- | --- |
| Path verb sequences and path equality | Exact |
| Winding and fill-rule selection | Exact |
| Rectangle edge ordering | Exact |
| Curve flattening distance | Approximate with an explicit tolerance |
| Bézier-extrema roots (later slice) | Approximate with an explicit tolerance |

`DEFAULT_FLATTEN_TOLERANCE = 0.25` device units is the named default. Following
kurbo's convention, flattening tolerance is the maximum distance in device
space between the true curve and its polyline approximation. Under midpoint
subdivision the flatness bound shrinks fourfold per level, so segment count
scales approximately as `1 / sqrt(tolerance)` for quadratics and cubics
alike. The default of 0.25 is the
right practical choice for antialiased output; use a smaller value only for
high-precision export.

API naming communicates ownership: past-participle methods return new values
(`translated`, `inverted`, `transformed`, `flattened`, `inflated`), while
mutating builder verbs remain imperative (`move_to`, `line_to`, `close`).

## Out of scope

GUI widgets, window management, plotting semantics, image editing, scene graphs,
and GPU acceleration are outside v0.1.
