# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning.

## [Unreleased]

## [0.1.0] - 2026-08-22

### Added

- Initial experimental repository scaffold.
- Finite 2D points and affine transform application/composition.
- Counterclockwise rotation and row-scaled affine inversion with explicit
  singular-transform errors.
- Explicit geometry validation checkpoints, affine coefficient accessors, and
  exact point equality and string formatting.
- Validated `Vec2` displacements with point/vector arithmetic, linear-part
  affine application, and a sorted, finite-extent `Rect` with
  union/intersection/containment/inflation.
- Immutable SoA `Path` (verb array plus interleaved coordinates) with
  transform, conservative control-box bounds, `PathBuilder` state-machine
  construction, `PathVerb`/`FillRule` nominal values, and rectangle/circle
  factories.
- Recursive de Casteljau curve flattening with a documented device-space
  tolerance policy and deterministic termination.
- In-place `AffineTransform.apply_batch` over parallel coordinate arrays.
- A documented y-down coordinate convention and scientific y-up adapter.
- A damped-sine flattening example with Hermite-to-Bézier construction, golden
  segment-count growth, and viewport batch transformation.
- An owned, stride-aware premultiplied `Rgba8` `Surface` with checked pixel
  access, overflow-safe construction, clipped solid fills, and deterministic
  source-over compositing.
- A four-pixel SIMD clear/compositing kernel with exact scalar tails,
  differential conformance tests, and reproducible 1080p throughput benchmarks.
- Deterministic binary-coverage `fill_path`/`blend_path` rasterization with
  nonzero and even-odd rules, implicit subpath closure, overflow-safe
  `PixelRect` clipping, residual-preserving overflow-safe extreme-coordinate
  interpolation, and a separate per-pixel traversal with explicit
  expected-mask fixtures.
- Read-only `Surface.bytes()` integration access, including stride padding,
  plus `row_bytes()` for the visible byte count of one row.
- Native sampling-profiler workloads and p50/p95 benchmarks that separate
  clears, rectangle compositing, path rasterization, short public spans, and
  the scalar reference.

### Changed

- Trust constructor-validated geometry during ordinary reads and operations,
  while continuing to reject nonrepresentable operation results.
- Precompute ordinary-coordinate raster-edge vertical bounds and slopes while
  retaining scaled overflow-safe interpolation for extreme finite geometry.

### Fixed

- Preserve mixed-scale off-diagonal coefficients and finite translation
  cancellation during affine inversion without weakening exact singularity.
- Preserve locally visible crossings for asymmetric extreme-to-ordinary path
  edges by interpolating both endpoint residuals instead of reusing one rounded
  line intercept.
- Skip zero-length scalar tail dispatch and nominal row walks when validating an
  empty surface layout.

[Unreleased]: https://github.com/Ameyanagi/kagerou/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ameyanagi/kagerou/releases/tag/v0.1.0
