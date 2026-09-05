"""Coverage quality/cost benchmark: fixed geometry, independent circle mask."""

from kagerou import PathBuilder, Point, Rgba8, Surface
from std.benchmark import keep
from std.collections import List
from std.math import abs
from std.time import perf_counter_ns


def _sort(mut values: List[Int]):
    for i in range(1, len(values)):
        var value = values[i]
        var j = i
        while j > 0 and values[j - 1] > value:
            values[j] = values[j - 1]
            j -= 1
        values[j] = value


def main() raises:
    var path = PathBuilder.circle(Point(31.17, 31.39), 24.23)
    var white = Rgba8(255, 255, 255, 255)
    var surface = Surface(64, 64)
    # Independent analytic 256x256 circle sampling per pixel; computed once
    # outside the measurement. This deliberately includes the cubic-circle
    # approximation's error as part of the end-to-end quality measurement.
    var reference = List[Float64](length=4096, fill=0.0)
    for y in range(64):
        for x in range(64):
            var hits = 0
            for sy in range(256):
                var dy = Float64(y) + (Float64(sy) + 0.5) / 256.0 - 31.39
                for sx in range(256):
                    var dx = Float64(x) + (Float64(sx) + 0.5) / 256.0 - 31.17
                    if dx * dx + dy * dy < 24.23 * 24.23:
                        hits += 1
            reference[y * 64 + x] = Float64(hits) / 65536.0
    print(
        "samples_per_axis,tolerance,p50_us,p95_us,mean_absolute_coverage_error,partial_pixels,checksum"
    )
    for setting in range(10):
        var quality = 1 << (setting % 5)
        var tolerance = 0.25 if setting < 5 else 0.01
        for _ in range(3):
            surface.fill_path(
                path, white, tolerance=tolerance, samples_per_axis=quality
            )
        var times = List[Int]()
        for _ in range(15):
            var started = perf_counter_ns()
            for round in range(40):
                surface.fill_path(
                    path, white, tolerance=tolerance, samples_per_axis=quality
                )
                keep(surface.pixel((round * 13) % 64, (round * 17) % 64).alpha())
            times.append(perf_counter_ns() - started)
        _sort(times)
        surface.clear(Rgba8(0, 0, 0, 0))
        surface.fill_path(path, white, tolerance=tolerance, samples_per_axis=quality)
        var error = 0.0
        var partial = 0
        var checksum = 0
        for y in range(64):
            for x in range(64):
                var alpha = Int(surface.pixel(x, y).alpha())
                checksum += alpha
                if alpha > 0 and alpha < 255:
                    partial += 1
                error += abs(Float64(alpha) / 255.0 - reference[y * 64 + x])
        print(
            quality,
            tolerance,
            Float64(times[7]) / 40000.0,
            Float64(times[14]) / 40000.0,
            error / 4096.0,
            partial,
            checksum,
            sep=",",
        )
