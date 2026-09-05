from kagerou import (
    AffineTransform,
    FillRule,
    Path,
    PathBuilder,
    PixelRect,
    Point,
    Rect,
    Rgba8,
    Surface,
)
from std.collections import List
from std.math import abs
from std.testing import TestSuite, assert_raises, assert_true


def _triangle(shift: Float64) raises -> Path:
    var builder = PathBuilder()
    builder.move_to(Point(shift, shift))
    builder.line_to(Point(shift + 6.0, shift))
    builder.line_to(Point(shift, shift + 6.0))
    return builder^.finish()


def _reference_count(
    x: Int, y: Int, n: Int, shift: Float64, kind: Int, even_odd: Bool
) -> Int:
    # Analytic shapes, with no production flattening, edges, sorting, or
    # interpolation. The quadratic cap is y = 2x-x*x on x in [0,2].
    var count = 0
    for sy in range(n):
        for sx in range(n):
            var px = Float64(x) + (Float64(sx) + 0.5) / Float64(n) - shift
            var py = Float64(y) + (Float64(sy) + 0.5) / Float64(n) - shift
            var inside: Bool
            if kind == 0:
                inside = px >= 0.0 and py >= 0.0 and px + py < 6.0
            elif kind == 1:
                var dx = px - 3.0
                var dy = py - 3.0
                inside = dx * dx + dy * dy < 2.25 * 2.25
            elif kind == 2:
                inside = (
                    px >= 0.0 and px < 2.0 and py >= 0.0 and py < 2.0 * px - px * px
                )
            else:
                var outer = px >= 0.0 and px < 6.0 and py >= 0.0 and py < 6.0
                var inner = px >= 1.5 and px < 4.5 and py >= 1.5 and py < 4.5
                inside = outer and (not inner if even_odd else True)
            if inside:
                count += 1
    return count


def _shape(shift: Float64, kind: Int) raises -> Path:
    if kind == 0:
        return _triangle(shift)
    if kind == 1:
        return PathBuilder.circle(Point(shift + 3.0, shift + 3.0), 2.25)
    var builder = PathBuilder()
    if kind == 2:
        builder.move_to(Point(shift, shift))
        builder.quad_to(Point(shift + 1.0, shift + 2.0), Point(shift + 2.0, shift))
    else:
        builder.add_rect(Rect(shift, shift, shift + 6.0, shift + 6.0))
        builder.add_rect(Rect(shift + 1.5, shift + 1.5, shift + 4.5, shift + 4.5))
    return builder^.finish()


def test_fractional_masks_against_independent_analytic_shapes() raises:
    var white = Rgba8(255, 255, 255, 255)
    for quality in range(2, 17):
        for translation in range(3):
            var shift = Float64(translation) * 0.19 - 0.21
            for kind in range(4):
                var path = _shape(shift, kind)
                for rule in range(2):
                    var surface = Surface(8, 8, 37)
                    var fill_rule = FillRule.NONZERO if rule == 0 else FillRule.EVEN_ODD
                    surface.fill_path_clipped(
                        path, PixelRect(1, 0, 6, 7), white, fill_rule, 0.00001, quality
                    )
                    for y in range(8):
                        for x in range(8):
                            var expected = 0
                            if x >= 1 and x < 7 and y < 7:
                                var count = _reference_count(
                                    x, y, quality, shift, kind, rule == 1
                                )
                                expected = (count * 255 + quality * quality // 2) // (
                                    quality * quality
                                )
                            var actual = Int(surface.pixel(x, y).alpha())
                            # The circle factory is a four-cubic approximation
                            # (radial error < .00028r), not an exact circle.
                            var tolerance = (255 + quality * quality - 1) // (
                                quality * quality
                            ) if kind == 1 else 0
                            assert_true(abs(actual - expected) <= tolerance)
                        for padding in range(32, 37):
                            assert_true(surface.bytes()[y * 37 + padding] == UInt8(0))


def test_coverage_compositing_rounding_and_transparent_fill() raises:
    var half = PathBuilder.rectangle(Rect(0.0, 0.0, 0.5, 1.0))
    var destination = Rgba8(31, 63, 127, 255)
    var source = Rgba8(80, 40, 20, 128)
    var fill = Surface(1, 1)
    fill.clear(destination)
    fill.fill_path(half, source, samples_per_axis=4)
    assert_true(fill.pixel(0, 0) == Rgba8(56, 52, 74, 192))
    var blend = Surface(1, 1)
    blend.clear(destination)
    blend.blend_path(half, source, samples_per_axis=4)
    # Effective source (40,20,10,64), then existing byte source-over formula.
    assert_true(blend.pixel(0, 0) == Rgba8(63, 67, 105, 255))
    fill.clear(destination)
    fill.fill_path(half, Rgba8(0, 0, 0, 0), samples_per_axis=4)
    assert_true(fill.pixel(0, 0) == Rgba8(16, 32, 64, 128))
    blend.clear(destination)
    blend.blend_path(half, Rgba8(0, 0, 0, 0), samples_per_axis=4)
    assert_true(blend.pixel(0, 0) == destination)
    fill.validate()
    blend.validate()


def test_binary_default_compatibility_and_full_coverage() raises:
    var path = _triangle(0.19)
    var source = Rgba8(80, 40, 20, 128)
    var binary = Surface(8, 8)
    var explicit = Surface(8, 8)
    binary.fill_path(path, source)
    explicit.fill_path(path, source, samples_per_axis=1)
    assert_true(binary == explicit)
    var rectangle = PathBuilder.rectangle(Rect(-5e307, -5e307, 5e307, 5e307))
    for quality in range(2, 17):
        var surface = Surface(3, 3)
        surface.fill_path(rectangle, source, samples_per_axis=quality)
        for y in range(3):
            for x in range(3):
                assert_true(surface.pixel(x, y) == source)


def test_quality_validation_and_empty_extreme_clips() raises:
    var builder = PathBuilder()
    var empty = builder^.finish()
    var surface = Surface(0, 0)
    with assert_raises(contains="samples_per_axis must be within [1, 16]; got 0"):
        surface.fill_path(empty, Rgba8(0, 0, 0, 0), samples_per_axis=0)
    with assert_raises(contains="samples_per_axis must be within [1, 16]; got 17"):
        surface.blend_path(empty, Rgba8(0, 0, 0, 0), samples_per_axis=17)
    var visible = Surface(2, 2)
    var path = _triangle(0.0)
    visible.fill_path_clipped(
        path,
        PixelRect(Int.MIN, Int.MIN, Int.MAX, Int.MAX),
        Rgba8(255, 255, 255, 255),
        samples_per_axis=16,
    )
    assert_true(visible.pixel(0, 0).alpha() == UInt8(0))


def test_all_256_coverage_steps_match_independent_compositor() raises:
    var destination = Rgba8(9, 101, 149, 177)
    var source = Rgba8(73, 31, 7, 113)
    for covered in range(257):
        var builder = PathBuilder()
        var rows = covered // 16
        var remainder = covered % 16
        builder.add_rect(Rect(0.0, 0.0, 1.0, Float64(rows) / 16.0))
        if remainder != 0:
            builder.add_rect(
                Rect(
                    0.0,
                    Float64(rows) / 16.0,
                    Float64(remainder) / 16.0,
                    Float64(rows + 1) / 16.0,
                )
            )
        var path = builder^.finish()
        var fill = Surface(1, 1)
        var blend = Surface(1, 1)
        fill.clear(destination)
        blend.clear(destination)
        fill.fill_path(path, source, samples_per_axis=16)
        blend.blend_path(path, source, samples_per_axis=16)
        var sources: List[Int] = [73, 31, 7, 113]
        var destinations: List[Int] = [9, 101, 149, 177]
        var effective_alpha = (113 * covered + 128) // 256
        for channel in range(4):
            var expected_fill = (
                sources[channel] * covered
                + destinations[channel] * (256 - covered)
                + 128
            ) // 256
            var effective_source = (sources[channel] * covered + 128) // 256
            var expected_blend = (
                effective_source
                + (destinations[channel] * (255 - effective_alpha) + 127) // 255
            )
            assert_true(Int(fill.bytes()[channel]) == expected_fill)
            assert_true(Int(blend.bytes()[channel]) == expected_blend)
        fill.validate()
        blend.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
