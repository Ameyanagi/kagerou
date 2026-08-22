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

## Software surface and compositing

`Surface` owns row-major premultiplied RGBA8 bytes. Its stride is expressed in
bytes, is at least `width * 4`, and may include row padding. Construction rejects
negative dimensions or stride and checks both row-byte and `stride * height`
overflow before allocation. Zero width or height is valid, checked pixel access
always rejects coordinates outside the half-open dimensions, and empty fill or
blend operations are no-ops without walking nominally large empty dimensions.
`bytes()` exposes the exact storage, including padding, as a read-only borrowed
span; `row_bytes()` distinguishes the visible `width * 4` bytes from `stride`.

`Rgba8(red, green, blue, alpha)` accepts already-premultiplied bytes and rejects
any color channel greater than alpha. This intentionally tiny local format keeps
Kagerou independent of Akari until Akari's public color-space contract is ready.

Solid spans and rectangles use signed integer origins and nonnegative extents.
Clipping is half-open and compares before adding, so `Int.MIN`/`Int.MAX` origins
and extents cannot overflow an endpoint. Premultiplied source-over is evaluated
per channel as

`source + round(destination * (255 - source_alpha) / 255)`.

The integer round-to-nearest implementation is exact for the full byte domain.
Transparent source is identity and opaque source is replacement. A private
scalar implementation defines the semantic reference. Complete four-pixel
chunks widen one 16-byte load to UInt16 SIMD, apply the same integer expression,
and narrow to one 16-byte store. One-to-three-pixel tails use the original
bounds-checked scalar formula. The only unsafe boundary is an origin-tracked
pointer borrowed from the owned `List[UInt8]`. Clipping proves every 16-byte
access is initialized and in bounds, alignment is explicitly one byte, and the
pointer never escapes the operation.

## Binary path coverage and rectangular clipping

`fill_path` overwrites and `blend_path` source-over composites pixels whose
centers are inside a flattened path. `_clipped` variants additionally accept a
`PixelRect` with a signed origin and nonnegative extent. Clips intersect with
the surface without forming `origin + extent`, so extreme signed inputs are
well-defined. This explicit per-call value is intentionally smaller than a
stateful transformed clip stack.

Sampling occurs at `(x + 0.5, y + 0.5)`. Nonhorizontal edges cross scanlines in
`[min_y, max_y)`. Sorted equal-x crossings are consumed as a group; nonzero
fills add directed winding and even-odd fills use its parity. Filled x intervals
are `[left, right)`. These choices establish the top/left-inclusive,
bottom/right-exclusive boundary rule, avoid double-counting shared vertices,
and make open subpaths close implicitly. Crossing interpolation has a fast
ordinary-device-coordinate path and an extreme-coordinate path that separates a
scaled leading slope from the finite residual at each endpoint. Those residuals
are interpolated outward from the nearer endpoint with scaled differences before
one final multiply-add. This preserves both symmetric residuals such as `x - y`
and asymmetric MAX-to-local offsets without overflowing an endpoint difference
or treating one rounded residual as a global intercept. A fully scaled endpoint
interpolation remains the fallback when no finite leading line is available.
Ordinary-coordinate edges precompute their vertical bounds and `dx / dy` once,
so scanlines perform comparisons and a multiply-add rather than repeated
min/max and division.

Coverage is currently binary: a covered pixel receives full source coverage.
Antialiasing may refine coverage values later without changing path winding,
edge ownership, clipping, or compositing semantics. A slow per-pixel traversal
checks optimized crossing sorting and span emission, while sharing the same
flattened edges and interpolation. Full explicit masks independently check both
fill rules, edge ownership, clipping, symmetric extreme `x = y` diagonals, and
an asymmetric MAX-to-local apex; the scalar compositor independently checks
SIMD batches and tails.

## Out of scope

GUI widgets, window management, plotting semantics, image editing, scene graphs,
and GPU acceleration are outside v0.1.
