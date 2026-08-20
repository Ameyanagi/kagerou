# Architecture

Kagerou owns 2D geometry, paths, transforms, stroke/fill semantics, clipping, software surfaces, rasterization, and later GPU backends.

## Dependency boundary

Allowed ecosystem dependencies: Akari for color semantics after its foundation is stable.
Expected downstream consumers: Sen's optional native backend and other applications that need low-level 2D rendering.

Dependencies point from applications and higher-level packages toward smaller
foundations. This repository must never import a downstream consumer. New
dependencies require a documented need and must not force unrelated users to
install an application, renderer, language layer, or scientific stack.

## Layers

Planned implementation areas: points, transforms, paths, strokes, fills, clips, software surfaces, rasterization, antialiasing, and an isolated future GPU renderer.

The researched target contracts, primary-source provenance, adopted and
rejected complexity, minimal public API, verification strategy, and
dependency-ready issue order are specified in
[reference-architecture.md](reference-architecture.md).

The package root exports only the small documented public surface. Algorithms,
generated tables, platform details, and backend implementations remain in
their owning modules. Generic Mojo-native buffers, spans, strings, and
collections are preferred over an ecosystem-specific universal container.

## Data flow

Input validation occurs at the public boundary. Internal layers operate on
explicit typed values, produce deterministic outputs for deterministic inputs,
and report invalid state rather than silently replacing it with a default.
I/O, clocks, randomness, terminal queries, filesystem access, and accelerator
selection stay at explicit effect or backend boundaries.

Mojo 1.0 does not make underscore-prefixed struct fields private. Geometry
constructors validate their inputs, while every public numeric observation and
operation revalidates reachable storage. Operation results pass through the same
constructors so floating overflow raises instead of escaping as nonfinite state.

Affine inversion decomposes each finite binary64 coefficient into its exact
integer significand and base-two exponent. Products are formed exactly in
`Int256`; terms are aligned exactly whenever cancellation is possible. A term
separated by more than the retained 149-bit window cannot affect exact-zero
classification and lies below the retained working precision, but it can still
decide a binary64 halfway-rounding case by one ulp. K0.3 therefore does not
promise correctly rounded inverse coefficients. Only an exact zero determinant
is singular. Inverse coefficients apply their exponents in binary64-sized
steps, and inverse translation uses the same exact-product accumulation so
finite cancellation cannot be lost to intermediate overflow. Any nonzero result
that would underflow, or any result that would overflow, is rejected as
nonrepresentable. Approximate geometry and near-singular tolerance remain owned
by the unopened K0.4 gate.
