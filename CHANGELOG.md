# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

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

### Changed

- Trust constructor-validated geometry during ordinary reads and operations,
  while continuing to reject nonrepresentable operation results.

### Fixed

- Preserve mixed-scale off-diagonal coefficients and finite translation
  cancellation during affine inversion without weakening exact singularity.
