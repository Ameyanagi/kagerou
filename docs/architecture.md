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
