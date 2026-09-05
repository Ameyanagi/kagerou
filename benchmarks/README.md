# Software-surface benchmarks

Run `pixi run bench-surface` from the repository root. Before retaining results,
record the CPU, OS, architecture, exact Mojo version, compiler options, UTC
time, and the command alongside the program's machine-readable output.

The deterministic in-memory fixture is a 1,920 x 1,080 premultiplied RGBA8
surface. It measures alternating opaque clears, rectangle SIMD source-over, the
byte-exact scalar source-over oracle, end-to-end circle fill/source-over (curve
flattening through emitted spans), and the public three-pixel span entry point
against the direct scalar oracle. The normal cases record 15 samples; the
deliberately slower full-frame oracle records nine. Output reports nearest-rank
p50/p95 elapsed times plus normalized per-pixel, per-frame, or per-operation
values and a checksum. Surface and input-path allocation occurs before timing;
path cases intentionally include per-call flattening and transient
edge/crossing storage. The Pixi task compiles with `-O3`, and observation
barriers prevent dead-store removal. Every case performs three untimed warmup
rounds; metadata names the nine-sample case as `full_frame_scalar_samples` so it
does not imply that the 15-sample narrow scalar case uses the same count.

## Native sampling profiles

Build the two long-running workloads, launch one, let dynamic-loader startup
finish, and attach macOS `sample` for three seconds:

```sh
pixi run build-profile-surface
./.pixi/profile_surface &
profile_pid=$!
sleep 2
sample "$profile_pid" 3 -file .pixi/profile_surface.txt
wait "$profile_pid"

pixi run build-profile-path
./.pixi/profile_path &
profile_pid=$!
sleep 2
sample "$profile_pid" 3 -file .pixi/profile_path.txt
wait "$profile_pid"
```

`profile_surface.mojo` isolates repeated full-surface source-over.
`profile_path.mojo` includes curve flattening, edge construction, crossing
sorting, clipping, span emission, and compositing. Compare the two before
attributing cost to geometry. Mojo 1.0 may inline the package into `main`; when
that happens, map a sampled `main + offset` to
`xcrun llvm-objdump --disassemble .pixi/profile_path`. Generated code around the
hot address should be retained with the review notes.

On Apple M4/macOS 26.5.1 on 2026-08-22, reviewed post-startup 3-second `sample`
runs kept the geometry and compositing workloads separate. The rectangle run
placed all 2,500 main-thread samples in `main`; its hottest `main + 664` address
mapped to the 16-byte NEON store in the inlined composite loop. The workload's
1,920-pixel width is divisible by the four-pixel vector width, and disassembly
confirmed that the zero-remainder branch skips the scalar helper. The path run
placed 2,423 of 2,523 top-of-stack main-thread samples in its inlined body, 41 in
real scalar span tails, and 40 in named edge/flattening/builder frames. Its
leading inlined offset, `main + 5308`, mapped to the vector store in the same
load/widen/source-over/narrow/store sequence.

A clean p50/p95 benchmark rerun after the residual and zero-tail fixes measured
path fill at 233.0/236.0 microseconds per call and path source-over at
311.1/319.4 microseconds per call. Manual four-vector unrolling was discarded
after paired large-frame runs showed no meaningful median win (15.999 ms versus
16.011 ms). A four-channel tail vector was also discarded after a clean run
measured 24.70 ns per three-pixel span versus 21.10 ns for the scalar oracle.

Results are development evidence, not permanent marketing claims. Rerun on the
target platform; do not generalize one machine's throughput.

## Fractional path coverage

`pixi run --locked bench-coverage` compares the original binary mode with 2, 4,
8, and 16 samples per axis at two flattening tolerances. See the
[quality/cost methodology and measured results](coverage.md), independent circle
reference, raw CSV, and generated visual comparison.
