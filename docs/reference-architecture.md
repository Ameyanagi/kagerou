# Reference architecture

This document turns primary-source study into an executable architecture for
Kagerou. It specifies contracts and issue order; it does not copy algorithms or
source. Every cited reference is pinned to the exact commit inspected on
2026-08-20.

## Scope

Kagerou is a low-level 2D renderer. Its v0.1 owns validated geometry, paths,
fill and stroke semantics, intersect-only clipping, a bounded software surface,
scalar coverage, and source-over compositing.

It is not a GUI toolkit, plotting package, window system, retained UI framework,
text shaper, image editor, or document renderer. Sen may consume Kagerou later;
Kagerou must never depend on Sen. A GPU implementation may consume the same
semantic inputs after v0.1, but no GPU resource, device, shader, or error enters
the CPU API.

## Primary-source ledger

The research clones live outside the Kagerou repository at
`/Users/ryuichi/dev/reference-libraries/kagerou/`. They are evidence, not build
inputs or vendored dependencies.

| Project | Inspected commit | License | Relevant public model and layering |
| --- | --- | --- | --- |
| [tiny-skia](https://github.com/linebender/tiny-skia/tree/88c65f6e6dfb31b7ea720e2f1609db7bf154b182) | `88c65f6e6dfb31b7ea720e2f1609db7bf154b182` | BSD-3-Clause | Immutable compact paths feed fill/stroke calls on an owned premultiplied RGBA surface; clipping is an explicit alpha mask; CPU rendering and bounds-checked pixel access are the deliberate scope. |
| [lyon](https://github.com/nical/lyon/tree/8071ec066c610b006e58086fea30cd96d4cef153) | `8071ec066c610b006e58086fea30cd96d4cef153` | MIT OR Apache-2.0 | Path, geometry, algorithms, and tessellation are separate crates. Tessellators write through a transactional geometry-builder seam and deliberately do not own a graphics backend. |
| [kurbo](https://github.com/linebender/kurbo/tree/ca273499e3e48bd2de6f02aa8e99a148984e45f3) | `ca273499e3e48bd2de6f02aa8e99a148984e45f3` | MIT OR Apache-2.0 | `f64` curve/path values separate drawing elements from independent segments, distinguish conservative from tight bounds, and attach explicit accuracy to flattening and stroke expansion. |
| [Vello](https://github.com/linebender/vello/tree/f08b480a77bf91f37adec56ac177f8073db12f56) | `f08b480a77bf91f37adec56ac177f8073db12f56` | MIT OR Apache-2.0 | A `Scene` records semantic draw commands and resources independently from a feature-gated renderer. Encoding, flattening, clipping, binning/coarse work, and fine rasterization are separate stages. |

The exact license files are [tiny-skia's BSD license](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/LICENSE),
[lyon's MIT](https://github.com/nical/lyon/blob/8071ec066c610b006e58086fea30cd96d4cef153/LICENSE-MIT)
and [Apache-2.0](https://github.com/nical/lyon/blob/8071ec066c610b006e58086fea30cd96d4cef153/LICENSE-APACHE),
[kurbo's MIT](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/LICENSE-MIT)
and [Apache-2.0](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/LICENSE-APACHE),
and [Vello's MIT](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/LICENSE-MIT)
and [Apache-2.0](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/LICENSE-APACHE).

### Evidence distilled from the references

- tiny-skia defines its scope as a minimal CPU-only renderer with fill, stroke,
  dashing, clipping, and blending, while explicitly excluding GPU, text, broad
  image formats, advanced path operations, and color management
  ([README](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/README.md#L6-L17),
  [out-of-scope list](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/README.md#L86-L111)).
  Its path is immutable, compact, finite, contour-valid, and has precomputed
  conservative bounds; tight bounds are a separate computation
  ([path contract](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/path/src/path.rs#L16-L53),
  [bounds](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/path/src/path.rs#L66-L114)).
  Its surface owns checked premultiplied RGBA bytes and rejects zero or
  mismatched sizes
  ([pixmap](https://github.com/linebender/tiny-skia/blob/88c65f6e6dfb31b7ea720e2f1609db7bf154b182/src/pixmap.rs#L23-L69)).
- lyon makes path events explicit, including subpath begin/end and the closed
  flag
  ([events](https://github.com/nical/lyon/blob/8071ec066c610b006e58086fea30cd96d4cef153/crates/path/src/events.rs#L5-L35)).
  It defines tolerance as maximum curve-to-approximation distance and leaves
  produced geometry and the graphics backend to the caller
  ([tolerance and backend boundary](https://github.com/nical/lyon/blob/8071ec066c610b006e58086fea30cd96d4cef153/crates/lyon/src/lib.rs#L160-L176)).
  Its geometry output protocol has begin, end, and abort hooks, demonstrating
  that failure should not expose partial output
  ([geometry builder](https://github.com/nical/lyon/blob/8071ec066c610b006e58086fea30cd96d4cef153/crates/tessellation/src/geometry_builder.rs#L200-L265)).
- kurbo distinguishes path elements, useful for construction, from independent
  segments, useful for geometry algorithms
  ([path model](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/kurbo/src/bezpath.rs#L26-L50),
  [nominal values](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/kurbo/src/bezpath.rs#L103-L143)).
  It also documents that its flattening tolerance is an attempted rather than
  absolute Hausdorff bound
  ([flattening contract](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/kurbo/src/bezpath.rs#L589-L625))
  and that stroke expansion approximates parallel curves rather than a rigorous
  sweep
  ([stroke contract](https://github.com/linebender/kurbo/blob/ca273499e3e48bd2de6f02aa8e99a148984e45f3/kurbo/src/stroke.rs#L243-L286)).
  Kagerou must state comparable limits instead of presenting tolerance as a
  proof it has not established.
- Vello records drawing commands and resources in a reusable `Scene`, separate
  from its renderer
  ([scene](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/vello/src/scene.rs#L29-L83)).
  Fill and stroke record semantic style, transform, brush, and shape
  independently of the target
  ([fill and stroke](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/vello/src/scene.rs#L311-L383)).
  The GPU renderer and its resource-bearing options are feature-gated
  ([renderer boundary](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/vello/src/lib.rs#L316-L405)),
  while the internal recording explicitly stages flattening, clip reduction,
  binning, allocation, coarse work, and fine rasterization
  ([pipeline recording](https://github.com/linebender/vello/blob/f08b480a77bf91f37adec56ac177f8073db12f56/vello/src/render.rs#L300-L490)).

## Decisions: adopt, adapt, reject

### Adopt

- An immutable, contour-valid `Path` produced by a stateful `PathBuilder`.
- Explicit move, line, quadratic, cubic, and close commands.
- Distinct conservative and tight bounds contracts.
- One named, positive, finite tolerance value threaded through approximate
  algorithms.
- Stroke expansion as geometry lowering: the rasterizer consumes fills.
- Explicit nonzero/even-odd fill rules and explicit stroke cap/join semantics.
- Checked surface dimensions, checked byte-length arithmetic, premultiplied
  storage, and bounded writes.
- A simple scalar clip-mask model before any hierarchical clip optimization.
- Algorithm/output and semantic/backend seams so later implementations cannot
  redefine observable behavior.
- Failure-atomic builders and lowering stages: validation or complexity failure
  leaves the destination unchanged and reusable.

### Adapt

- tiny-skia's compact parallel verb/point storage is a useful internal option,
  but Kagerou first chooses the representation that Mojo can validate and
  iterate safely. Storage layout is not public API.
- lyon's geometry-builder seam informs an internal sink for flattened or
  expanded geometry. Kagerou produces scalar edges and coverage, not a public
  triangle-tessellation API.
- kurbo's drawing-element/segment distinction becomes builder commands at the
  public boundary and derived segment iteration internally. Raw mutable element
  access is not adopted because Mojo 1.0 cannot rely on underscore privacy.
- Vello's semantic recording/backend split is retained as a future seam, but a
  retained public scene and its resource model are unnecessary for v0.1.

### Reject for v0.1

- Conics, arcs, path Boolean operations, hit testing, general shape protocols,
  per-vertex attributes, triangle tessellation, gradients, images, text,
  filters, arbitrary blend modes, layers, caching, and retained scenes.
- A GPU-first pipeline, shaders, atlases, device selection, asynchronous
  submission, GPU target handles, or GPU errors in the core package.
- Window creation, event handling, widgets, plotting semantics, and export
  formats.
- Silent repair of invalid paths, nonfinite coordinates, invalid styles,
  unbalanced clips, size overflow, or exhausted subdivision budgets.
- Unchecked mutable views of semantic values. Allocation reuse is internal and
  may be introduced only after mutation tests preserve all contracts.

## Target architecture

```text
public semantic values
Point / AffineTransform / GeometryTolerance / Path / styles / clips
                              |
                              v
geometry lowering (Float64, target independent)
validate -> transform-aware flatten -> stroke expansion -> fill edges
                              |
                              v
scalar software pipeline
edge preparation -> clipped coverage -> solid paint -> source-over
                              |
                              v
checked SoftwareSurface (owned premultiplied RGBA8)

future, after v0.1 conformance:
same semantic draw input -> isolated GPU encoder/renderer -> GPU target
```

The five layers are:

1. **Continuous geometry:** finite `Float64` points, affine transforms, exact
   singularity, and explicit approximate tolerance.
2. **Path semantics:** immutable contours and iteration, independent of color,
   rasterization, and device resources.
3. **Geometry lowering:** flattening, stroke expansion, fill edges, and clip
   shapes. This layer produces owned validated results before surface mutation.
4. **Scalar rendering:** deterministic coverage, intersected clip masks, paint
   conversion, and source-over composition.
5. **Target ownership:** an owned checked software surface now; separate GPU
   target and renderer types later.

No public type in one layer exposes the internal storage of the layer below it.

## Geometry and path representation

### Coordinate convention

- Continuous geometry uses `Float64`.
- Surface device coordinates place the origin at the top left, positive `x` to
  the right, positive `y` downward, and pixel centers at `(x + 0.5, y + 0.5)`.
- `AffineTransform.followed_by()` retains its current application-order
  contract. Lowering never changes composition order implicitly.
- Every coordinate, transform coefficient, style scalar, and tolerance must be
  finite when observed. Operation overflow raises.

### Commands and contours

K1 exposes an immutable `Path` and a builder with these operations:

```mojo
var builder = PathBuilder()
builder.move_to(Point(8.0, 8.0))
builder.line_to(Point(48.0, 8.0))
builder.quadratic_to(Point(56.0, 16.0), Point(48.0, 24.0))
builder.cubic_to(Point(40.0, 32.0), Point(16.0, 32.0), Point(8.0, 24.0))
builder.close()
var path = builder.finish()
```

The contract is:

- An empty path is valid.
- Every nonempty subpath begins with exactly one move.
- Line, quadratic, cubic, and close before a move raise.
- A second move ends the previous open subpath and begins another.
- `close()` is permitted once per current subpath, records semantic closure,
  and moves the current point back to that subpath's first point.
- A drawing command after close requires a new move. Kagerou does not infer a
  continuation rule.
- Zero-length subpaths and segments are preserved. Later fill and stroke gates
  define their effect; the builder does not discard them.
- Fill evaluation closes open contours conceptually for area, but it does not
  mutate the path. Stroke distinguishes an explicit close join from open caps.
- `finish()` consumes or invalidates the builder and returns an immutable owned
  path. Failed commands and failed finish leave no partially published path.

The internal encoding may use tagged commands or parallel verb/point arrays.
Callers receive checked iteration and counts, never mutable internal storage.
Because underscore-prefixed fields are reachable in Mojo 1.0, every public
observation revalidates reachable representation unless the representation
itself makes every bit pattern valid.

### Bounds

`control_bounds()` is the cheap conservative union of endpoints and control
points. `tight_bounds()` evaluates finite Bézier extrema. Empty-path behavior is
explicit (an optional/absent rectangle), not an invented zero rectangle. Both
methods validate path state and fail on nonrepresentable intermediate results.
Raster culling may use conservative bounds only; correctness never depends on a
tight-bounds optimization.

## Tolerance and flattening

`GeometryTolerance` is a nominal positive finite `Float64` measured in device
pixels. It is not an equality epsilon, determinant threshold, stroke width, or
coverage cutoff. Exact topology and singularity remain exact contracts.

Approximate equality helpers, if later needed, use separately named absolute
and relative tolerances. They never change fill topology or accept a singular
transform.

Flattening follows these rules:

- The caller supplies a device-space tolerance; there is no hidden global.
- The path transform is known before subdivision. The accepted polyline is
  tested in device space, so scaling the source path cannot silently magnify the
  allowed error.
- Endpoints are emitted exactly once and in path order. Closure is a flag plus
  an edge when required, not a duplicated builder command.
- Quadratic and cubic curves use deterministic adaptive subdivision with a
  documented sufficient flatness test. The implementation must state whether
  the tolerance is a proven bound or a conservative practical criterion.
- A finite maximum depth and a checked segment budget guarantee termination.
  Budget exhaustion raises and publishes no partial flattened path.
- Refining tolerance must not remove original endpoints or reorder segments.

Stroke width is in source-space units. Stroke expansion constructs the semantic
source-space outline, then transforms and flattens that outline. Every
approximation made while constructing the outline is accepted against the
device-space tolerance after transformation; it is not controlled by dividing
through one guessed scale factor. This preserves the correct outline under
rotation, shear, and nonuniform scale. A later optimized implementation must be
conformant with this reference ordering.

## Fill, stroke, and clipping

### Fill

`FillRule` is a nominal value with exactly `non_zero()` and `even_odd()`
semantics. Filling an open contour includes the conceptual closing edge. Edge
intersection uses a documented half-open vertex rule so a shared vertex is not
counted twice. Reversing a simple contour changes winding sign but not nonzero
membership; duplicating a contour changes nonzero winding but cancels under
even-odd.

### Stroke

`StrokeStyle` contains:

- positive finite width (zero-width hairlines are outside v0.1),
- `butt`, `round`, or `square` caps,
- `miter`, `round`, or `bevel` joins,
- a finite miter limit greater than or equal to `1.0`, and
- an optional finite dash sequence and offset.

A dash sequence contains positive finite lengths, has a positive finite cycle,
and is normalized to an even on/off cycle by repeating an odd-length input once.
Empty means solid. Dash offset normalization is deterministic. Dashed closed
contours define the seam explicitly; implementations cannot reorder dashes if
that changes observable output.

Stroke expansion returns fillable closed outlines. It documents approximation
limits, covers cusps and degenerate segments, and uses the same explicit
tolerance/complexity budget. Style mutation is revalidated at every public use.

### Clip ownership

v0.1 clips are intersect-only. A `ClipStack` owns immutable entries, each of
which captures a path, fill rule, and transform at insertion. Pushing a clip
does not change the renderer's transform. Nested clips intersect coverage;
there is no union, difference, luminance mask, opacity layer, or blend layer.

`push()` returns a balanced scope/token or `pop()` validates nonempty state.
Rendering rejects mutated/unbalanced state before touching the surface. The
software implementation may cache an internal 8-bit coverage mask, but mask
representation and caching are not public API.

## Software surface and raster pipeline

### Surface contract

`SoftwareSurface(width, height)` owns tightly packed premultiplied RGBA8 bytes.
v0.1 rejects zero dimensions. Construction checks `width * height * 4`, integer
conversion, stride, and allocation limits before allocation. Borrowed surface
views, custom strides, alternate formats, and image decoding/encoding wait for
later evidence.

Checked access exposes dimensions, immutable pixel observation, clear, and
eventually explicit export-copy access. No public mutable byte slice can break
premultiplication or length invariants. The surface is move-only unless a
deliberate deep-copy API is added. Every draw guarantees writes stay within its
owned allocation, including negative/huge path coordinates and clips.

### Reference scalar pipeline

The first correct pipeline is deliberately simple:

1. Validate the complete path, transform, tolerance, style, clip stack, paint,
   target dimensions, and complexity budget.
2. Lower curves and strokes to finite device-space line edges in temporary
   owned storage.
3. Cull against conservative integer target bounds without changing edge
   topology.
4. Evaluate nonzero or even-odd membership using the locked half-open crossing
   rule.
5. Compute coverage using an **8 by 8 centered, uniform subpixel grid**. Samples
   are `(pixel_x + (i + 0.5) / 8, pixel_y + (j + 0.5) / 8)` for `i,j` in
   `0..8`; coverage is exactly `inside_count / 64`.
6. Evaluate every clip at the same 64 sample positions and combine inside
   predicates with logical intersection. Equivalently, intersect 64-bit sample
   masks; multiplying already-averaged per-pixel coverages is not conformant.
7. Convert one solid Akari color to the internal premultiplied representation
   and apply source-over.
8. Quantize to RGBA8 once with a documented tie policy and commit bounded pixel
   writes.

The 8 by 8 rule is a stable reference oracle, not a performance promise. Later
analytic, scanline, tiled, SIMD, or GPU coverage may replace it only if the
public conformance policy explicitly permits its differences. The scalar path
must remain available to generate independent fixtures.

A failing command is surface-atomic: validation, lowering, clip preparation,
and allocation complete before the first target write. The surface remains
valid and reusable after every raised error.

## Akari color boundary

Geometry, path, stroke, fill, clipping, and scalar coverage do not depend on a
color library. Kagerou adds Akari only after Akari publishes a stable v0.1
numeric and color-space contract.

At that gate:

- Akari owns public color construction, spaces, conversion, palette, and
  interpolation semantics.
- Kagerou accepts a narrow solid-color value from Akari and does not define a
  competing RGB/HSL/color-management hierarchy.
- The integration contract identifies the blending space explicitly. The
  preferred contract is finite linear-light RGBA `Float64` in `[0, 1]`.
- Kagerou clamps only where the agreed Akari conversion contract requires it,
  premultiplies exactly once, composites in the documented space, and quantizes
  exactly once at the RGBA8 surface boundary.
- Internal premultiplied RGBA8 is a storage format, not an Akari public color
  model.

Until that dependency gate opens, K3 tests operate on internal scalar coverage
and explicit test-only reference channels. Root exports must not publish a
temporary color type that downstream code could adopt.

## Backend and GPU seam

Kagerou should stabilize semantic drawing before publishing a renderer trait.
For v0.1, `SoftwareRenderer` consumes immutable draw inputs and an explicit
mutable `SoftwareSurface`; it does not hide a process-global current target.

Internally, a small validated `DrawCommand`/`RenderBatch` representation may
separate recording from execution when reuse is measured. It contains semantic
paths, transforms, fill/stroke styles, clips, and solid paint—not flattened
edges, tiles, shaders, device handles, or allocations. It is not a public
retained scene in v0.1.

After the scalar conformance corpus is stable, a GPU package/module may add
`GpuRenderer` and `GpuTarget`. It consumes the same semantic values through an
adapter and owns all device selection, resource lifetime, asynchronous work,
shader compilation, and GPU errors. CPU-only consumers never import or install
that backend. Backend-specific batching and encoding remain internal.

Cross-backend tests render identical semantic fixtures. Exact geometry and
topology must agree; pixels follow a published image-difference policy. GPU work
does not begin until those tests exist and the software surface is useful alone.

## Ownership, errors, mutation, and numerical safety

- `Path`, clip entries, flattened paths, and stroke outlines are owned immutable
  values. Algorithms borrow them for the duration of a call.
- `PathBuilder` owns mutable construction state. `finish()` is consuming;
  allocation reuse is an internal optimization.
- `SoftwareSurface` owns its pixels and is mutated only through checked methods.
  A renderer borrows it exclusively for a draw.
- A source path or clip cannot alias target storage. Pixel-buffer views are not
  retained after their borrow.
- Each public call revalidates externally reachable Mojo 1.0 storage. Mutation
  regression tests overwrite every reachable discriminant and numeric field
  with invalid and nonfinite values.
- Nominal enum-like values use representations where every constructible bit
  pattern has a defined valid meaning, or every public use rejects invalid
  state. No unknown discriminant falls through to a default behavior.
- Public failures raise with operation and cause: invalid state, nonfinite or
  nonrepresentable numeric result, singular transform, invalid tolerance/style,
  unbalanced clip, dimension/stride overflow, or complexity-budget exhaustion.
- Validation and lowering are failure-atomic. No public error returns a partial
  path, outline, clip, or draw.
- Exact predicates (path state, fill rule, closure, singularity, buffer bounds)
  stay separate from approximate numeric policy.

## Minimal v0.1 API target

The root remains staged and small. Symbols appear only when their roadmap gate
is implemented and tested:

```mojo
from kagerou import (
    AffineTransform,
    ClipStack,
    FillRule,
    GeometryTolerance,
    LineCap,
    LineJoin,
    Path,
    PathBuilder,
    Point,
    SoftwareRenderer,
    SoftwareSurface,
    StrokeStyle,
)
```

Conceptual use after the Akari gate:

```mojo
var builder = PathBuilder()
builder.move_to(Point(8.0, 8.0))
builder.line_to(Point(56.0, 8.0))
builder.line_to(Point(32.0, 48.0))
builder.close()
var triangle = builder.finish()

var surface = SoftwareSurface(64, 64)
var renderer = SoftwareRenderer(GeometryTolerance.device_pixels(0.25))
renderer.fill(
    surface,
    triangle,
    AffineTransform.identity(),
    FillRule.non_zero(),
    color,
)
```

The API intentionally omits a universal shape protocol, scene graph, canvas
state machine, generic image type, GPU target, and file save method. Examples
may provide a tiny PPM writer outside the library if visual inspection is
needed before an image-codec package exists.

## Verification strategy

### Unit and reference tests

- Command arity, missing move, repeated close, multiple contours, explicit
  versus conceptual closure, empty paths, zero-length segments, and finite
  mutation rejection.
- Conservative bounds and independently generated analytic quadratic/cubic
  extrema fixtures.
- Flattened line/quadratic/cubic fixtures with exact endpoints and an
  independent dense-sampling deviation oracle that does not call production
  flatness helpers.
- Cap, join, miter fallback, dash cycle/seam, closed-path, cusp, and degenerate
  stroke outlines.
- Nonzero/even-odd fixtures with reversed, duplicated, nested,
  self-intersecting, shared-vertex, and open contours.
- Clip intersection identities: full clip is neutral, empty clip clears,
  disjoint clips clear, and reordering intersect-only clips preserves coverage.
- Surface size/stride overflow, zero dimensions, sentinel guards around every
  row, extreme off-screen geometry, and exact checked access.
- Source-over transparent/opaque identities, premultiplied-channel invariants,
  monotone alpha, and all boundary byte values.

### Properties and metamorphic tests

- Flattening preserves endpoints/order; tighter tolerance does not increase the
  independent sampled error and terminates within budget.
- Transforming the resulting polyline agrees within the device tolerance with
  flattening under the composed transform.
- Fill membership is translation invariant and follows each fill rule's winding
  identities.
- Stroke bounds contain sampled offset geometry; swapping contour direction
  swaps sides without changing the union outline.
- Coverage is finite and in `[0, 1]`, quantized coverage is in `0..64`, and
  repeated renders are byte-identical on the supported scalar platform matrix.
- Public mutation cannot produce a crash, out-of-bounds write, silent default,
  nontermination, or nonfinite published result.

### Golden corpus

Golden artifacts are small raw RGBA files plus a text manifest containing
dimensions, pixel format, color-space contract, fixture version, and SHA-256.
Coverage-only fixtures use readable integer matrices in `0..64`. PNG is an
optional derived review artifact, never the oracle.

Every golden change includes the semantic reason and independently reviewed
reference generation. Production helpers do not generate their own expected
values. Platform-independent scalar output is byte-exact; future GPU output
uses an explicit per-channel and differing-pixel budget plus structural
coverage tests.

### Benchmarks

Benchmarks measure stages separately: path iteration, quadratic/cubic
flattening, solid/dashed stroke expansion, edge preparation, fill coverage,
clip intersection, compositing, and end-to-end draws. Each committed workload
has a versioned manifest and checksum.

The methodology records Mojo/compiler revision, lock digest, Kagerou revision
and dirty state, OS, CPU, optimization flags, warmup, samples, iterations,
surface size, path/segment counts, tolerance, clip depth, and paint mode. Timed
inputs pass through `std.benchmark.black_box`; output checksums are consumed to
prevent dead-code elimination. CI checks compilation and semantic checksums,
not unstable timing thresholds. Documentation publishes methodology, never an
unsupported superiority claim.

## Dependency-ready issue order

Each issue is completed with implementation, focused unit/reference/property
tests, mutation/resource tests where relevant, root/package smoke when public,
and updated contracts. Do not combine adjacent gates merely because their types
are related.

1. **K0.4 Geometry tolerance policy.** Add nominal positive finite
   device-pixel tolerance; separate exact and approximate comparisons; cover
   mutation, zero, negative, infinity, NaN, and smallest/large finite inputs.
2. **K1.1 Path command values.** Define five finite nominal commands and checked
   observation without exposing mutable storage through the root.
3. **K1.2 Path builder.** Lock contour state, closure, empty/degenerate policy,
   consuming finish, failure atomicity, and checked iteration.
4. **K1.3a Conservative bounds.** Implement endpoint/control bounds and explicit
   empty behavior. Use it for no correctness-critical culling yet.
5. **K1.3b Tight bounds.** Add analytic Bézier extrema with independent fixtures
   and dynamic-range/nonrepresentable-result rejection.
6. **K1.4 Flattening.** Implement transform-aware device tolerance, deterministic
   budgets, no partial output, and an independent deviation oracle.
7. **K2.1 Fill rule and edge semantics.** Lock nominal rules, conceptual closure,
   half-open crossings, and winding metamorphic tests without pixels.
8. **K2.2a Solid stroke style.** Width/cap/join/miter validation and mutation
   rejection; hairlines remain out of scope.
9. **K2.3a Solid stroke expansion.** Source-space outline followed by transform
   and device flattening; reference joins/caps/degenerates.
10. **K2.2b/K2.3b Dashes.** Add validated cycles, offsets, open and closed seam
    policy after solid strokes pass.
11. **K2.4 Clip stack.** Intersect-only immutable entries, explicit balance,
    transform capture, and no global renderer state.
12. **K3.1 Pixel surface.** Move-only tightly packed RGBA8 storage, checked
    dimensions/allocation/access, zero-size rejection, and sentinel tests.
13. **K3.2 Coverage rasterizer.** Implement the 8 by 8 scalar reference rule,
    exact `0..64` coverage fixtures, bounded writes, and budget failure.
14. **Akari adapter gate.** Pin Akari commit/package, verify its finite linear
    RGBA contract, add only a narrow solid-color adapter, and document the
    dependency. Skip this issue until Akari is stable.
15. **K3.3 Compositing.** Lock premultiplication, source-over, blending space,
    quantization ties, and exhaustive boundary fixtures.
16. **K3.4 Clip integration.** Rasterize/intersect clip coverage and prove
    failure atomicity and surface containment.
17. **K4.1 Conformance corpus.** Commit coverage matrices, raw RGBA goldens,
    manifests, checksums, mutation corpus, and independent generators.
18. **K4.2 Root audit.** Export only completed semantic types; keep commands,
    edges, masks, raster stages, and storage details internal.
19. **K4.3 Downstream proof.** Build a Sen adapter outside Kagerou; add no Sen or
    plotting dependency here.
20. **K4.4 Package matrix.** Run locked checks, examples, installed-package
    smoke, and package builds on every declared platform.
21. **Post-v0.1 renderer recording seam.** Add an internal semantic batch only
    if profiles show reuse value; avoid publishing a retained scene by default.
22. **Post-v0.1 optimized backends.** Establish benchmark baselines, then scalar
    optimization, SIMD, and finally an isolated GPU renderer, each gated by the
    same conformance corpus.

The earliest currently dependency-ready issue remains K0.4. No path,
rasterization, Akari integration, SIMD, or GPU work should bypass it.
