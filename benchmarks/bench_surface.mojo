"""Distribution benchmark for software compositing and path rasterization."""

from kagerou import Path, PathBuilder, Point, Rgba8, Surface
from std.benchmark import keep
from std.collections import List
from std.time import perf_counter_ns


comptime _WIDTH = 1920
comptime _HEIGHT = 1080
comptime _PIXEL_COUNT = _WIDTH * _HEIGHT
comptime _ROUNDS = 16
comptime _PATH_ROUNDS = 8
comptime _SCALAR_ROUNDS = 2
comptime _WARMUP_ROUNDS = 3
comptime _SAMPLE_COUNT = 15
comptime _SCALAR_SAMPLE_COUNT = 9
comptime _NARROW_SPAN_COUNT = 131_072


def _observe(surface: Surface, round: Int) raises:
    var x = (round * 811) % surface.width()
    var y = (round * 613) % surface.height()
    keep(surface.pixel(x, y).alpha())


def _sort_samples(mut samples: List[Int]):
    for index in range(1, len(samples)):
        var value = samples[index]
        var destination = index
        while destination > 0 and value < samples[destination - 1]:
            samples[destination] = samples[destination - 1]
            destination -= 1
        samples[destination] = value


def _measure_clear(
    mut surface: Surface,
    first: Rgba8,
    second: Rgba8,
) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface.clear(first if round % 2 == 0 else second)
        _observe(surface, round)

    var samples = List[Int](capacity=_SAMPLE_COUNT)
    for _ in range(_SAMPLE_COUNT):
        var started = perf_counter_ns()
        for round in range(_ROUNDS):
            surface.clear(first if round % 2 == 0 else second)
            _observe(surface, round)
        samples.append(perf_counter_ns() - started)
    _sort_samples(samples)
    return samples^


def _measure_blend(mut surface: Surface, source: Rgba8) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface.blend_rect(0, 0, _WIDTH, _HEIGHT, source)
        _observe(surface, round)

    var samples = List[Int](capacity=_SAMPLE_COUNT)
    for _ in range(_SAMPLE_COUNT):
        surface.clear(Rgba8(UInt8(15), UInt8(31), UInt8(47), UInt8(255)))
        var started = perf_counter_ns()
        for round in range(_ROUNDS):
            surface.blend_rect(0, 0, _WIDTH, _HEIGHT, source)
            _observe(surface, round)
        samples.append(perf_counter_ns() - started)
    _sort_samples(samples)
    return samples^


def _measure_scalar_blend(
    mut surface: Surface, source: Rgba8
) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface._blend_rect_scalar(0, 0, _WIDTH, _HEIGHT, source)
        _observe(surface, round)
    var samples = List[Int](capacity=_SCALAR_SAMPLE_COUNT)
    for _ in range(_SCALAR_SAMPLE_COUNT):
        surface.clear(Rgba8(UInt8(15), UInt8(31), UInt8(47), UInt8(255)))
        var started = perf_counter_ns()
        for round in range(_SCALAR_ROUNDS):
            surface._blend_rect_scalar(0, 0, _WIDTH, _HEIGHT, source)
            _observe(surface, round)
        samples.append(perf_counter_ns() - started)
    _sort_samples(samples)
    return samples^


def _measure_path_fill(
    mut surface: Surface,
    path: Path,
    color: Rgba8,
) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface.fill_path(path, color)
        _observe(surface, round)
    var samples = List[Int](capacity=_SAMPLE_COUNT)
    for _ in range(_SAMPLE_COUNT):
        surface.clear(Rgba8(UInt8(0), UInt8(0), UInt8(0), UInt8(0)))
        var started = perf_counter_ns()
        for round in range(_PATH_ROUNDS):
            surface.fill_path(path, color)
            _observe(surface, round)
        samples.append(perf_counter_ns() - started)
    _sort_samples(samples)
    return samples^


def _measure_path_blend(
    mut surface: Surface,
    path: Path,
    source: Rgba8,
) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface.blend_path(path, source)
        _observe(surface, round)
    var samples = List[Int](capacity=_SAMPLE_COUNT)
    for _ in range(_SAMPLE_COUNT):
        surface.clear(Rgba8(UInt8(15), UInt8(31), UInt8(47), UInt8(255)))
        var started = perf_counter_ns()
        for round in range(_PATH_ROUNDS):
            surface.blend_path(path, source)
            _observe(surface, round)
        samples.append(perf_counter_ns() - started)
    _sort_samples(samples)
    return samples^


def _measure_narrow_spans(
    mut surface: Surface,
    source: Rgba8,
    scalar: Bool,
) raises -> List[Int]:
    for round in range(_WARMUP_ROUNDS):
        surface.clear(Rgba8(UInt8(15), UInt8(31), UInt8(47), UInt8(255)))
        for index in range(_NARROW_SPAN_COUNT):
            var x = index % (surface.width() - 3)
            if scalar:
                surface._blend_span_scalar(x, 0, 3, source)
            else:
                surface.blend_span(x, 0, 3, source)
        keep(surface.pixel(round % surface.width(), 0).alpha())

    var samples = List[Int](capacity=_SAMPLE_COUNT)
    for sample in range(_SAMPLE_COUNT):
        surface.clear(Rgba8(UInt8(15), UInt8(31), UInt8(47), UInt8(255)))
        var started = perf_counter_ns()
        for index in range(_NARROW_SPAN_COUNT):
            var x = index % (surface.width() - 3)
            if scalar:
                surface._blend_span_scalar(x, 0, 3, source)
            else:
                surface.blend_span(x, 0, 3, source)
        samples.append(perf_counter_ns() - started)
        keep(surface.pixel(sample % surface.width(), 0).alpha())
    _sort_samples(samples)
    return samples^


def _p50(samples: List[Int]) -> Int:
    return samples[len(samples) // 2]


def _p95(samples: List[Int]) -> Int:
    return samples[(95 * len(samples) + 99) // 100 - 1]


def _print_pixel_result(
    name: StringLiteral,
    samples: List[Int],
    rounds: Int,
    checksum: Int,
):
    var visited = _PIXEL_COUNT * rounds
    var p50 = _p50(samples)
    var p95 = _p95(samples)
    print(
        "case=",
        name,
        " p50_elapsed_ns=",
        p50,
        " p95_elapsed_ns=",
        p95,
        " p50_ns_per_pixel=",
        Float64(p50) / Float64(visited),
        " p95_ns_per_pixel=",
        Float64(p95) / Float64(visited),
        " p50_megapixels_per_second=",
        Float64(visited) * 1.0e3 / Float64(p50),
        " checksum=",
        checksum,
        sep="",
    )


def _print_operation_result(
    name: StringLiteral,
    samples: List[Int],
    operations: Int,
    checksum: Int,
):
    var p50 = _p50(samples)
    var p95 = _p95(samples)
    print(
        "case=",
        name,
        " p50_elapsed_ns=",
        p50,
        " p95_elapsed_ns=",
        p95,
        " p50_ns_per_operation=",
        Float64(p50) / Float64(operations),
        " p95_ns_per_operation=",
        Float64(p95) / Float64(operations),
        " checksum=",
        checksum,
        sep="",
    )


def main() raises:
    var clear_surface = Surface(_WIDTH, _HEIGHT)
    var blend_surface = Surface(_WIDTH, _HEIGHT)
    var scalar_surface = Surface(_WIDTH, _HEIGHT)
    var path_fill_surface = Surface(_WIDTH, _HEIGHT)
    var path_blend_surface = Surface(_WIDTH, _HEIGHT)
    var narrow_surface = Surface(1024, 1)
    var narrow_scalar_surface = Surface(1024, 1)
    var first = Rgba8(UInt8(12), UInt8(34), UInt8(56), UInt8(255))
    var second = Rgba8(UInt8(98), UInt8(76), UInt8(54), UInt8(255))
    var source = Rgba8(UInt8(73), UInt8(41), UInt8(19), UInt8(127))
    var path = PathBuilder.circle(
        Point(Float64(_WIDTH) * 0.5, Float64(_HEIGHT) * 0.5),
        Float64(_HEIGHT) * 0.44,
    )

    print(
        "BENCH_HEADER kagerou surface mojo=1.0.0 ",
        'command="pixi run bench-surface" width=1920 height=1080 ',
        "rounds=16 path_rounds=8 scalar_rounds=2 warmup_rounds=3 ",
        "samples=15 full_frame_scalar_samples=9 statistics=p50,p95 ",
        "compiler_options=-O3 ",
        "format=premultiplied_rgba8 simd_channels=16",
        sep="",
    )

    var clear_samples = _measure_clear(clear_surface, first, second)
    var clear_pixel = clear_surface.pixel(_WIDTH - 1, _HEIGHT - 1)
    _print_pixel_result(
        "clear_simd",
        clear_samples,
        _ROUNDS,
        Int(clear_pixel.red()) + Int(clear_pixel.alpha()),
    )

    var blend_samples = _measure_blend(blend_surface, source)
    var blend_pixel = blend_surface.pixel(_WIDTH - 1, _HEIGHT - 1)
    _print_pixel_result(
        "source_over_simd",
        blend_samples,
        _ROUNDS,
        Int(blend_pixel.red()) + Int(blend_pixel.alpha()),
    )

    var scalar_samples = _measure_scalar_blend(scalar_surface, source)
    var scalar_pixel = scalar_surface.pixel(_WIDTH - 1, _HEIGHT - 1)
    _print_pixel_result(
        "source_over_scalar",
        scalar_samples,
        _SCALAR_ROUNDS,
        Int(scalar_pixel.red()) + Int(scalar_pixel.alpha()),
    )

    var path_fill_samples = _measure_path_fill(path_fill_surface, path, first)
    var path_fill_pixel = path_fill_surface.pixel(_WIDTH // 2, _HEIGHT // 2)
    _print_operation_result(
        "path_fill",
        path_fill_samples,
        _PATH_ROUNDS,
        Int(path_fill_pixel.red()) + Int(path_fill_pixel.alpha()),
    )

    var path_blend_samples = _measure_path_blend(path_blend_surface, path, source)
    var path_blend_pixel = path_blend_surface.pixel(_WIDTH // 2, _HEIGHT // 2)
    _print_operation_result(
        "path_source_over",
        path_blend_samples,
        _PATH_ROUNDS,
        Int(path_blend_pixel.red()) + Int(path_blend_pixel.alpha()),
    )

    var narrow_samples = _measure_narrow_spans(narrow_surface, source, False)
    var narrow_pixel = narrow_surface.pixel(512, 0)
    _print_operation_result(
        "short_span_public",
        narrow_samples,
        _NARROW_SPAN_COUNT,
        Int(narrow_pixel.red()) + Int(narrow_pixel.alpha()),
    )

    var narrow_scalar_samples = _measure_narrow_spans(
        narrow_scalar_surface, source, True
    )
    var narrow_scalar_pixel = narrow_scalar_surface.pixel(512, 0)
    _print_operation_result(
        "narrow_span_scalar_oracle",
        narrow_scalar_samples,
        _NARROW_SPAN_COUNT,
        Int(narrow_scalar_pixel.red()) + Int(narrow_scalar_pixel.alpha()),
    )
