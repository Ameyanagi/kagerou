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

Mojo 1.0 does not make underscore-prefixed struct fields private. Geometry
constructors establish invariants, and public observations and operations trust
stored state thereafter. Direct mutation of underscore-prefixed storage is out
of contract; public `validate()` methods provide an explicit checkpoint when a
caller performs unusual low-level mutation. Results that can overflow still pass
through validating constructors so nonfinite state cannot escape.

`Surface` follows the same trust boundary for nonnegative dimensions, byte
stride, exact owned storage length, and premultiplied `Rgba8` pixels. Public
pixel reads and writes remain checked. Fill and compositing clip signed integer
spans before calculating offsets.

Path rendering remains behind `Surface`: curves first use the shared
device-space flattening contract, then each subpath is implicitly closed into
directed nonhorizontal edges. The default scanline at `y + 0.5` gathers and sorts its
crossings, groups equal crossings, advances either signed winding or parity,
and emits half-open horizontal spans. The same half-open rule includes pixel
centers on top/left boundaries and excludes centers on bottom/right boundaries.
A separate per-pixel traversal avoids crossing sorting and span emission, but
intentionally shares flattening and edge interpolation. Explicit expected masks
independently lock fill-rule, boundary, symmetric extreme diagonals, and an
asymmetric MAX-to-local apex.
`PixelRect` is a per-call backend-neutral clip; it intersects with surface
bounds before coordinate conversion or offset calculation and does not pretend
to be the unopened transformed clip-stack API.

Empty clips, empty paths, and transparent blend sources return after validating
the cheap tolerance and sampling arguments and before flattening or allocating edge/crossing
storage. `Surface.bytes()` exposes a read-only borrowed span over the exact owned
storage, including padding; `row_bytes()` distinguishes visible RGBA bytes from
the byte `stride` used to locate the next row.

Fractional coverage reuses directed edges and sorted scanlines at N subpixel
heights. Each filled interval contributes sample counts to a single clipped row,
then equal-coverage runs share the existing compositor. The UInt16 row does not
grow with N or surface height; the public limit of 16 samples per axis keeps
counts at or below 256. Analytic shape masks independently verify this path.
Tight path bounds are a separate allocation-free traversal over endpoints and
normalized derivative roots; the original control-box query remains available.

The SIMD row loop is a narrow, audited unsafe boundary over an owned
`List[UInt8]`. Validation and clipping prove each whole-width load/store is
inside initialized storage before the origin-tracked pointer is created. The
list is never resized while borrowed, byte alignment is explicit, and the
pointer does not escape. One-to-three pixel tails use the private bounds-checked
scalar loop, which remains the semantic reference in exact differential tests.
An attempted four-channel tail vector was removed after the clean benchmark
showed it slower than this scalar path.

Native `sample` profiles use separate long-running rectangle-composite and path
workloads in binary coverage mode. On the profiled Apple M4 build, the generated 16-byte NEON
load/widen/multiply/narrow/store loop owns the path workload's dominant samples;
flattening and allocation are a small minority. This evidence keeps path
preparation internal and the public API direct. Manual four-vector unrolling was
rejected after paired measurements showed no meaningful median improvement.
The retained geometry optimization precomputes ordinary-coordinate edge slopes
and vertical bounds once. Extreme edges instead retain a scaled leading slope
plus independently interpolated endpoint residuals, avoiding both overflowing
differences and a rounded global-intercept assumption.

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
