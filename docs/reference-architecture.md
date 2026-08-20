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

Kagerou is also not the owner of a general render plan. Sen and other callers
retain their own command ordering and lower it immediately through Kagerou's
concrete fill/stroke operations. Kagerou does not publish a command batch,
retained scene, or renderer trait in v0.1.

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
- Vello's separation between semantic draw inputs and backend execution is
  retained, but Kagerou adapts those inputs immediately. Its retained recording,
  public scene, and resource model are unnecessary here.

### Reject for v0.1

- Conics, arcs, path Boolean operations, hit testing, general shape protocols,
  per-vertex attributes, triangle tessellation, gradients, images, text,
  filters, arbitrary blend modes, layers, caching, retained scenes, command
  batches, and a renderer trait.
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
checked SoftwareSurface (owned linear-light premultiplied UNORM8 RGBA)

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
- A finite singular transform is valid for fill, stroke, clip, and path
  lowering; collapsed geometry follows the same fill/stroke rules. Only an
  operation that mathematically requires inversion, such as `inverted()`, raises
  for exact singularity. CPU and future GPU rendering may not choose different
  singular-transform policies.

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
Empty means solid. The offset is reduced into `[0, cycle)` in source units; an
offset exactly on an interval boundary advances to the following interval.
Traversal begins at the stored first point and follows path order. Zero-length
segments consume no dash length and do not reset phase. A closed contour is
never rotated to find a more convenient seam. When the first and last pieces are
both on, they merge across the stored seam and receive a join there; otherwise
each on piece ending at the seam receives the selected caps. Dashing and any
curve-length approximation are deterministic source-space geometry lowering
under the same device-space tolerance and segment budget.

The miter ratio is the source-space distance from the join vertex to the outer
offset-line intersection divided by half the stroke width. A finite intersection
with ratio less than or equal to the miter limit uses the miter; equality is
included. A missing/nonrepresentable intersection, larger ratio, exact reversal,
or cusp falls back to bevel for a miter join. A round join uses the outer arc;
a bevel join uses the two outer offset endpoints.

Zero-length geometry has fixed behavior. Zero-length segments inside a subpath
are skipped when finding neighboring tangents and joins. An open subpath with no
nonzero segment produces nothing for butt caps, a source-space disk of radius
half-width for round caps, and a source-axis-aligned square of side `width` for
square caps. A closed subpath with no nonzero segment produces no stroke because
closed contours have no caps. At an exact reversal, round joins add the
half-width disk and bevel/miter joins use the bevel fallback. These rules apply
before transformation and therefore remain defined under nonuniform or singular
transforms.

Stroke expansion returns fillable closed outlines. It documents approximation
limits and uses the same explicit tolerance/complexity budget. Style mutation is
revalidated at every public use.

### Clip ownership

v0.1 clips are intersect-only. A caller-local `ClipStack` owns immutable entries,
each of which captures a path, fill rule, and transform at insertion. `push()`
mutates this checked local value and returns no retained scope object; `pop()`
raises when empty. Pushing a clip does not change any renderer transform. Nested
clips intersect coverage; there is no union, difference, luminance mask, opacity
layer, or blend layer.

Each immediate fill/stroke call borrows one validated clip-stack snapshot for
the duration of the synchronous call. It neither retains nor mutates that stack.
Rendering rejects externally mutated or structurally incoherent clip storage
before touching the surface. Adapter-level completion separately requires the
local stack to be empty. The software implementation may derive a temporary
64-sample mask, but mask representation and caching are not public API.

## Software surface and raster pipeline

### Surface contract

`SoftwareSurface(width, height)` freezes one format before K3.1:

- rows are stored top to bottom with no padding;
- stride is exactly `width * 4` bytes;
- each row stores pixels left to right in byte order `R, G, B, A`;
- every channel is linear-light UNORM8, decoded as `byte / 255.0`;
- RGB is premultiplied by alpha, so every stored pixel satisfies
  `R <= A`, `G <= A`, and `B <= A`;
- alpha zero has the sole representation `(0, 0, 0, 0)`; and
- construction initializes every pixel to transparent black.

v0.1 rejects zero dimensions. Construction checks `width * height * 4`, integer
conversion, stride, and allocation limits before allocation. Borrowed surface
views, custom strides, alternate formats, and image decoding/encoding wait for
later evidence. This linear byte format is the scalar rendering and golden-file
ABI; it is not implicitly sRGB and export code must label or convert it.

The byte conversion rule is round-to-nearest, ties-to-even after clamping an
already finite premultiplied linear channel to `[0, 1]`. Decoding is the named
`byte / 255.0` operation in Float64. An affected pixel is quantized exactly once
at the end of each successful immediate draw. Source-over for repeated draws
therefore decodes the stored destination, composites in linear Float64 using the
locked operation order below, and requantizes once. No backend may reinterpret
the bytes through an sRGB transfer function.

Checked access exposes dimensions, immutable pixel observation, clear, and
eventually explicit export-copy access. `SoftwareSurface` stores pixels behind a
package-controlled owner that exposes no reachable mutable list or unchecked
pointer. The surface is move-only unless a deliberate deep-copy API is added.
Every draw guarantees writes stay within its owned allocation, including
negative/huge path coordinates and clips.

Before the Akari gate, clear means only `clear_transparent()` and restores every
byte to zero. A colored clear is added only with the Akari adapter and uses the
same straight-linear conversion and ties-to-even byte rule as a full-coverage
draw; no temporary public color type is introduced.

If Mojo cannot enforce the package-controlled owner boundary, every public
surface operation performs a full validation before use: checked
`width * height * 4`, exact stride and byte length, `RGB <= A` for every pixel,
and transparent black whenever alpha is zero. A mismatch raises before any
write. Tests directly resize reachable pixel storage and corrupt both a
premultiplication relation and an alpha-zero pixel. Avoiding this scan is not a
reason to trust underscore privacy.

### Render limits and surface atomicity

`SoftwareRenderer` owns a validated `RenderLimits` value in addition to
`GeometryTolerance`. Its versioned defaults and any caller-supplied values are
positive, checked integers. The limits independently bound:

- flattened line segments per source path;
- stroke-outline segments per draw;
- clip depth and total clip edges;
- touched target pixels and 64-sample predicate evaluations; and
- temporary bytes allocated by lowering, clip preparation, and staged output.

All additions and products used for accounting are overflow-checked. The
renderer revalidates reachable limit fields on every call. Exhausting one limit
names that limit and raises before the surface changes; an implementation may
not silently coarsen tolerance, drop clips, or omit pixels.

Each command completes all fallible validation, geometry lowering, bounds and
limit accounting, clip preparation, allocation, and affected-pixel computation
before its first target write. It either stages final pixels within the temporary
byte limit or proves the exclusive-borrowed commit loop contains only bounded,
non-raising stores. Once commit begins there is no fallible calculation. This is
per-command atomicity: earlier successful immediate commands remain visible if a
later command fails.

### Reference scalar pipeline

The first correct pipeline is deliberately simple:

1. Validate the complete path, transform, tolerance, style, clip stack, paint,
   target format/invariants, and renderer limits.
2. Lower curves and strokes to finite device-space line edges in temporary
   owned storage.
3. Cull against conservative integer target bounds without changing edge
   topology.
4. Evaluate nonzero or even-odd membership using the exact crossing rule below.
5. Compute coverage using an **8 by 8 centered, uniform subpixel grid**. Samples
   are `(pixel_x + (i + 0.5) / 8, pixel_y + (j + 0.5) / 8)` for `i,j` in
   `{0, 1, ..., 7}`; coverage is exactly `inside_count / 64`.
6. Evaluate every clip at the same 64 sample positions and combine inside
   predicates with logical intersection. Equivalently, intersect 64-bit sample
   masks; multiplying already-averaged per-pixel coverages is not conformant.
7. Convert one finite straight linear Akari color to coverage-adjusted
   premultiplied Float64 and apply the locked source-over operation order.
8. Quantize each affected pixel once with round-to-nearest, ties-to-even, then
   commit bounded writes.

### Exact scalar crossing and arithmetic order

The scalar oracle uses no division for edge crossing. It first detects whether a
sample is exactly on a finite segment with an exact binary64 product-difference
predicate. A boundary sample is inside for both fill rules. Horizontal edges
participate in this boundary test but never update winding or parity.

For every other edge, endpoints are ordered as `low` and `high` by increasing
`y`. The sample participates exactly when `low.y <= sample.y < high.y`. A ray
crosses to the right when this strict comparison holds:

```text
(sample.x - low.x) * (high.y - low.y)
    < (sample.y - low.y) * (high.x - low.x)
```

The comparison evaluates each difference as finite binary64, then compares the
two products with exact significand/exponent arithmetic; it does not round a
division or contracted multiply-add. An original upward edge adds one winding,
an original downward edge subtracts one, and even-odd toggles once. Equality was
already classified as boundary and never falls through to a crossing tie. This
locks shared vertices, horizontal edges, reversed contours, and samples exactly
on geometry across supported scalar platforms.

The reference build forbids floating-point contraction throughout flattening,
paint conversion, and compositing. Each written operator is rounded to binary64
before the next. For straight linear source `(r, g, b, a)` and coverage `c`, the
operation order is:

```text
source_alpha = a * c
source_rgb = ((r * a) * c, (g * a) * c, (b * a) * c)
inverse_alpha = 1.0 - source_alpha
out_rgb = source_rgb + destination_rgb * inverse_alpha
out_alpha = source_alpha + destination_alpha * inverse_alpha
```

Each multiplication and addition is separate; no FMA substitution is conformant.
Inputs are in `[0, 1]`, so finite results remain bounded apart from a final clamp
that absorbs representational roundoff only. Multiplying already-averaged clip
coverages or compositing in encoded/sRGB space is nonconformant.

The 8 by 8 rule is a stable reference oracle, not a performance promise. Later
analytic, scanline, tiled, SIMD, or GPU coverage may replace it only if the
public conformance policy explicitly permits its differences. The scalar path
must remain available to generate independent fixtures.

A failing command is surface-atomic under the RenderLimits contract: validation,
lowering, clip preparation, allocation, and every possibly fallible computation
complete before the first target write. The surface remains valid and reusable
after every raised error.

## Akari color boundary

Geometry, path, stroke, fill, clipping, and scalar coverage do not depend on a
color library. Kagerou adds Akari only after Akari publishes a stable v0.1
numeric and color-space contract.

At that gate:

- Akari owns public color construction, spaces, conversion, palette, and
  interpolation semantics.
- Kagerou accepts a narrow solid-color value from Akari and does not define a
  competing RGB/HSL/color-management hierarchy.
- The adapter requests finite straight (unpremultiplied) linear-light RGBA
  `Float64`, with every channel in `[0, 1]`. Nonfinite or out-of-range output is
  rejected rather than silently clamped or interpreted in another space.
- Kagerou multiplies by coverage and premultiplies in the locked order above,
  composites in linear light, and quantizes each affected pixel exactly once at
  the RGBA8 surface boundary with round-to-nearest, ties-to-even.
- Internal premultiplied RGBA8 is a storage format, not an Akari public color
  model.

Until that dependency gate opens, K3 tests operate on internal scalar coverage
and explicit test-only straight linear reference channels under the same
conversion equations. Root exports must not publish a temporary color type that
downstream code could adopt.

## Backend and GPU seam

Kagerou stabilizes semantic drawing without publishing a renderer trait. For
v0.1, concrete `SoftwareRenderer` consumes immutable draw inputs and an explicit
mutable `SoftwareSurface`; it does not hide a process-global current target.

There is no renderer trait, `DrawCommand`, `RenderBatch`, or Kagerou-owned command
recording seam. The concrete synchronous `fill` and `stroke` methods each accept
the target, path, transform, fill/stroke semantics, solid color, and borrowed
caller-local `ClipStack` explicitly. Call order is draw order. Any internal edge,
mask, or pixel staging exists only within that immediate call and is not retained
for reuse.

The complete immediate command vocabulary is conceptually:

```text
fill(surface, path, transform, fill_rule, color, clips)
stroke(surface, path, transform, stroke_style, color, clips)
```

Transparent clear is a surface operation, not a drawing command. Rectangle,
marker, and higher-level command kinds do not expand this vocabulary.

### Sen adapter contract

Sen retains its renderer-neutral RenderPlan and adapts commands outside this
repository:

- filled rectangles become closed four-line paths;
- stroked lines/paths call immediate `stroke`;
- filled paths call immediate `fill`;
- markers become repeated finite paths, preserving Sen command order;
- clip pushes/pops update one checked local `ClipStack`, which must be empty at
  adapter completion; and
- text commands raise an explicit unsupported-command error until a separately
  reviewed text/glyph-outline component exists.

Text is never silently dropped, approximated with host fonts, or added to
Kagerou as a shaping system. The adapter may become useful for non-text Sen
figures first. Kagerou does not inspect axes, series, scales, ticks, plot bounds,
or any other plotting semantics.

After the scalar conformance corpus is stable, a GPU package/module may add
`GpuRenderer` and `GpuTarget`. It consumes the same semantic values through an
adapter and owns all device selection, resource lifetime, asynchronous work,
shader compilation, and GPU errors. CPU-only consumers never import or install
that backend. Backend-specific encoding remains internal and does not create a
shared public renderer trait or command batch.

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
- `SoftwareRenderer` owns immutable tolerance/limit policy. Each draw validates
  its currently reachable values and retains no source, clip, or target borrow.
- A source path or clip cannot alias target storage. Pixel-buffer views are not
  retained after their borrow.
- Each public call revalidates externally reachable Mojo 1.0 storage. Mutation
  regression tests overwrite every reachable discriminant and numeric field,
  resize reachable collections, corrupt command arity/topology, and—when the
  opaque surface fallback is used—violate byte length and premultiplication.
- Nominal enum-like values use representations where every constructible bit
  pattern has a defined valid meaning, or every public use rejects invalid
  state. No unknown discriminant falls through to a default behavior.
- Public failures raise with operation and cause: invalid state, nonfinite or
  nonrepresentable numeric result, singularity when inversion is requested,
  invalid tolerance/style/limits, structurally invalid clip state,
  dimension/stride overflow, or a named render-limit exhaustion.
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
    RenderLimits,
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
var renderer = SoftwareRenderer(
    GeometryTolerance.device_pixels(0.25),
    RenderLimits.defaults(),
)
var clips = ClipStack()
renderer.fill(
    surface,
    triangle,
    AffineTransform.identity(),
    FillRule.non_zero(),
    color,
    clips,
)
```

`RenderLimits.defaults()` is a versioned documented value, not host-memory
detection. Applications that need different bounds construct an explicit
validated value.

The API intentionally omits a universal shape protocol, scene graph, canvas
state machine, command batch, renderer trait, generic image type, GPU target,
text operation, and file save method. Examples may provide a tiny raw-RGBA or
PPM conversion outside the library if visual inspection is needed before an
image-codec package exists; that conversion must not relabel linear bytes as
sRGB.

## Verification strategy

### Unit and reference tests

- Command arity, missing move, repeated close, multiple contours, explicit
  versus conceptual closure, empty paths, zero-length segments, and finite
  mutation rejection.
- Conservative bounds and independently generated analytic quadratic/cubic
  extrema fixtures.
- Finite singular transforms are accepted by fill/stroke/clip lowering while
  inversion alone rejects exact singularity; collapsed-geometry fixtures lock
  the result.
- Flattened line/quadratic/cubic fixtures with exact endpoints and an
  independent dense-sampling deviation oracle that does not call production
  flatness helpers.
- Cap, join, miter fallback, dash cycle/seam, closed-path, cusp, and degenerate
  stroke outlines, including isolated zero-length subpaths and miter-limit
  equality.
- Nonzero/even-odd fixtures with reversed, duplicated, nested,
  self-intersecting, shared-vertex, open contours, horizontal edges, and samples
  exactly on an edge.
- Clip intersection identities: full clip is neutral, empty clip clears,
  disjoint clips clear, and reordering intersect-only clips preserves coverage.
- Surface size/stride overflow, zero dimensions, transparent initialization,
  exact row/channel order, sentinel guards around every row, extreme off-screen
  geometry, exact checked access, reachable pixel-list resize, `RGB > A`, and
  nonzero RGB at alpha zero.
- Source-over transparent/opaque identities, linear-light repeated draws,
  premultiplied-channel invariants, monotone alpha, ties-to-even fixtures, and
  all boundary byte values with contraction disabled.
- Every RenderLimits field at one-below/exact/one-above its gate, checked
  accounting overflow, named exhaustion errors, and unchanged surfaces.
- Sen adapter fixtures for rectangle/path/marker order, balanced clips, explicit
  text rejection, and absence of plotting imports in Kagerou.

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
- Exact crossing classification is unchanged by edge reversal except for winding
  sign, never counts horizontal edges, and treats boundary samples consistently.
- Public mutation cannot produce a crash, out-of-bounds write, silent default,
  nontermination, or nonfinite published result.

### Golden corpus

Golden artifacts are small raw RGBA files plus a text manifest containing
dimensions, exact stride, the fixed `linear-premultiplied-unorm8-rgba` format,
fixture version, and SHA-256. Coverage-only fixtures use readable integer
matrices in `0..64`. PNG is an optional color-converted derived review artifact,
never the oracle.

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
   rejection; lock half-width miter ratio/equality and every zero-length/cusp
   behavior; hairlines remain out of scope.
9. **K2.3a Solid stroke expansion.** Source-space outline followed by transform
   and device flattening; reference joins/caps/degenerates.
10. **K2.2b/K2.3b Dashes.** Add validated cycles, offsets, open and closed seam
    traversal/phase/merge policy after solid strokes pass.
11. **K2.4 Clip stack.** Intersect-only immutable entries in one checked
    caller-local push/pop value, transform capture, and no scope token/global
    renderer state.
12. **K3.1 Pixel surface and limits.** Freeze row-major tightly packed linear
    premultiplied UNORM8 RGBA, stride, transparent initialization, channel/alpha
    invariants, opaque-owner/fallback validation, move-only storage, and
    renderer-owned RenderLimits with corruption/exhaustion tests.
13. **K3.2 Coverage rasterizer.** Implement the 8 by 8 scalar reference rule,
    exact boundary/horizontal/crossing predicates, noncontracted arithmetic,
    exact `0..64` coverage fixtures, bounded writes, and atomic limit failure.
14. **Akari adapter gate.** Pin Akari commit/package, verify its finite linear
    straight RGBA `[0, 1]` contract, add only a narrow solid-color adapter, and
    document the dependency. Skip this issue until Akari is stable.
15. **K3.3 Compositing.** Lock the specified operation order, premultiplication,
    linear-light source-over, ties-to-even quantization, and exhaustive repeated-
    draw/boundary fixtures.
16. **K3.4 Clip integration.** Rasterize/intersect clip coverage and prove
    failure atomicity and surface containment.
17. **K4.1 Conformance corpus.** Commit coverage matrices, raw RGBA goldens,
    manifests, checksums, mutation corpus, and independent generators.
18. **K4.2 Root audit.** Export only completed semantic types; keep commands,
    edges, masks, raster stages, and storage details internal.
19. **K4.3 Downstream proof.** Build the immediate Sen adapter outside Kagerou;
    cover path/rectangle/marker order, local clip balance, and explicit text
    rejection; add no Sen or plotting dependency here.
20. **K4.4 Package matrix.** Run locked checks, examples, installed-package
    smoke, and package builds on every declared platform.
21. **Post-v0.1 optimized backends.** Establish benchmark baselines, then scalar
    optimization, SIMD, and finally an isolated GPU renderer, each gated by the
    same conformance corpus.

The earliest currently dependency-ready issue remains K0.4. No path,
rasterization, Akari integration, SIMD, or GPU work should bypass it.
