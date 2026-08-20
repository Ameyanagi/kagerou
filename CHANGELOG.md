# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Initial experimental repository scaffold.
- Finite 2D points and affine transform application/composition.
- Counterclockwise rotation and row-scaled affine inversion with explicit
  singular-transform errors.
- Pinned primary-source reference architecture for paths, tolerance, stroke,
  fill, clipping, software rasterization, the Akari boundary, and a future
  isolated GPU backend.

### Changed

- Revalidate reachable mutable geometry and reject transform-result overflow.

### Fixed

- Preserve mixed-scale off-diagonal coefficients and finite translation
  cancellation during affine inversion without weakening exact singularity.
