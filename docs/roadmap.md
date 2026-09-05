# Roadmap

Each checkbox is a reviewable issue completed with implementation, focused
tests, an example when public, and updated contracts. Correct scalar geometry is
the reference for every later raster or accelerator backend.

## v0.1 — Foundation

### K0 — Finite geometry seed

- [x] **K0.1 Continuous points:** validate finite 2D construction, provide
  non-raising observations, and expose explicit validation checkpoints.
- [x] **K0.2 Affine transforms:** add identity, translation, scale, point
  application, and application-ordered composition; reject operation overflow
  with regression fixtures.
- [x] **K0.3 Transform algebra:** add rotation and inversion with explicit
  singular-transform errors and identity/composition invariant tests.

  Evidence: radians-based counterclockwise rotation, exponent-tracked
  exact-singular inversion, two-sided round trips, reversed-composition
  invariants, explicit mutation checkpoints, mixed dynamic-range coefficients,
  finite translation cancellation, and nonrepresentable-result rejection are
  covered by reference tests and installed-package smoke.
- [x] **K0.4 Geometry tolerance policy:** document exact versus approximate
  comparisons and the tolerance rules used by higher-level geometry tests.

  Evidence: exact structural comparisons are separated from the named 0.25
  device-unit flattening tolerance, with dense sampled-distance fixtures at
  1.0, 0.25, and 0.01.

Completion gate: root imports remain limited to semantic geometry and path
vocabulary; the installed-package smoke test applies a transform without Akari
or Sen.

### K1 — Paths

- [x] **K1.1 Path command values:** define move, line, quadratic, cubic, and
  close commands as nominal values with finite coordinates.
- [x] **K1.2 Path builder:** enforce a valid current-point/subpath state and
  reject drawing commands before the first move.
- [x] **K1.3 Bounds:** retain conservative `bounds`/`control_bounds` and add
  analytic Bézier-extrema `tight_bounds`. Normalized derivative roots handle
  degeneracy, near-linear coefficients, and huge finite coordinates; dense
  independent Bernstein samples and known extrema verify the result.
- [x] **K1.4 Flattening:** convert curves to line segments under an explicit
  device-space tolerance with deterministic termination tests.

  Evidence: MOVE/LINE/CLOSE-only output, exact source endpoints, recursive
  de Casteljau error bounds, depth-capped termination, damped-sine goldens, and
  monotonic segment growth are covered by focused tests and a compiling example.

Dependency gate: K1 begins after K0.3 and K0.4 stabilize transformation and
tolerance semantics. Paths remain independent of color and surfaces.

### K2 — Stroke, fill, and clipping semantics

- [x] **K2.1 Fill rule:** define nonzero and even-odd rules independently of a
  rasterizer implementation.

  Evidence: nominal `FillRule.NONZERO` and `FillRule.EVEN_ODD` values are
  defined and tested independently of rasterization.
- [ ] **K2.2 Stroke style:** validate width, cap, join, miter limit, and dash
  pattern as renderer-neutral values.
- [ ] **K2.3 Stroke expansion:** lower stroked paths to fillable geometry with
  fixtures for joins, caps, closed paths, and degenerate segments.
- [ ] **K2.4 Clip stack:** specify intersect-only clip semantics and transformed
  clip ownership without global renderer state.

Dependency gate: K2 consumes K1 paths only after path state and flattening are
stable. Akari is still unnecessary because fill/stroke geometry and color are
separate inputs.

### K3 — Correctness-first software surface

- [x] **K3.1 Pixel surface:** own dimensions, stride, and checked pixel access
  with explicit overflow and empty-surface behavior.

  Evidence: `Surface` validates row bytes and total storage before allocation,
  supports explicit padded stride, checks individual pixel access, and treats
  zero-sized fill/blend workloads as constant-time no-ops.
- [x] **K3.2 Coverage rasterizer:** rasterize flattened fills into scalar
  coverage using a documented sampling rule.

  Evidence: `Surface.fill_path` and `blend_path` flatten curves, implicitly
  close subpaths, apply nonzero/even-odd winding at pixel centers, and emit
  deterministic binary-coverage spans or 2–16 centered samples per axis.
  Independent analytic masks cover translated diagonals, circles, tiny curves,
  clipping, and both fill rules. Visual examples and quality/cost benchmarks
  document the sampling/flattening tradeoff. A separate per-pixel traversal checks
  span emission; explicit expected masks independently verify nested winding,
  fractional boundaries, and huge diagonal residuals.
- [x] **K3.3 Compositing:** implement source-over alpha with reference pixels and
  transparent/opaque invariants.

  Evidence: the scalar premultiplied RGBA8 reference locks integer rounding and
  alpha edge cases; clipped four-pixel SIMD batches and every scalar tail length
  are tested for exact differential equality. A reproducible 1080p benchmark
  compares SIMD clears/blends with scalar source-over.
- [ ] **K3.4 Clip integration:** apply the K2 clip stack and prove all writes stay
  inside checked surface bounds.

  First slice: explicit per-call `PixelRect` clips already intersect every path
  write with checked surface bounds without endpoint overflow. Transformed
  stateful clip-stack ownership remains pending with K2.4.

Akari gate: choose a pinned Akari color representation only after Akari's v0.1
numeric/color-space contract is stable. Until then, rasterizer coverage tests use
internal scalar coverage and do not publish a competing color type.

### K4 — Release hardening

- [ ] **K4.1 Conformance corpus:** cover degenerate paths, transformed curves,
  fill rules, joins, clipping, and alpha reference images/checksums.
- [ ] **K4.2 Root audit:** expose semantic geometry and surface operations while
  keeping tessellation/raster implementation details internal.
- [ ] **K4.3 Downstream proof:** validate a Sen adapter outside Kagerou without
  adding Sen as a dependency or plotting concepts to Kagerou.
- [ ] **K4.4 Package matrix:** build and smoke-test the precompiled package on
  every supported platform.

Release gate: scalar results are deterministic within the documented tolerance,
checked surfaces contain every write, and dependency arrows remain sparse.

## v0.2 — Usability

- Add ergonomic path construction and image export only after v0.1 usage shows
  stable needs.
- Add gradients after color and transform semantics are proven independently.
- Publish the first modular-community recipe once software rendering is useful
  without Sen.

## v0.3 — Performance

- Add reproducible path-flattening, stroke, fill, and compositing benchmarks.
- Optimize measured scalar bottlenecks while retaining the reference path.
- Introduce SIMD behind identical geometry, coverage, and compositing contracts.

Current evidence: the surface benchmark reports p50/p95 for clears, rectangle
source-over, path fill/source-over, narrow tails, and the scalar oracle. Native
sampling profiles separate full-surface composite work from geometry-aware path
work. Exact 16-byte SIMD batches and scalar tails retain independent scalar
differential coverage.

## v1.0 — Stability

- Document all public symbols, errors, numeric tolerances, and pixel guarantees.
- Support the declared OS/architecture matrix in CI.
- Require at least one non-Sen downstream renderer integration.

## Test matrix

- **Unit:** finite validation, transform operations, path state, styles, and
  checked surface boundaries.
- **Reference value:** affine matrices, Bézier extrema, stroke outlines,
  coverage samples, and source-over pixels.
- **Invariant:** identity/composition, transform round trips, bounded writes,
  deterministic flattening, and coverage in `[0, 1]`.
- **Packaging:** installed root imports and a minimal checked rendering operation.

## Not planned

GUI widgets, window management, plotting semantics, text shaping, image editing,
scene graphs, retained-mode UI, and GPU acceleration are outside v0.1. GPU work
begins only as a later backend after scalar semantics and conformance stabilize.
