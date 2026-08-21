from kagerou import (
    AffineTransform,
    FillRule,
    Path,
    PathBuilder,
    PathVerb,
    Point,
    Rect,
)
from std.collections import List
from std.math import abs, sqrt
from std.testing import TestSuite, assert_raises, assert_true


def _assert_rect(
    rect: Rect,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
) raises:
    assert_true(rect.min_x() == x0)
    assert_true(rect.min_y() == y0)
    assert_true(rect.max_x() == x1)
    assert_true(rect.max_y() == y1)


def _line_path(end_x: Float64 = 3.0) raises -> Path:
    var builder = PathBuilder()
    builder.move_to(Point(1.0, 2.0))
    builder.line_to(Point(end_x, 4.0))
    return builder^.finish()


def _mixed_path() raises -> Path:
    var builder = PathBuilder()
    builder.move_to(Point(1.0, 2.0))
    builder.line_to(Point(3.0, 4.0))
    builder.quad_to(Point(5.0, 6.0), Point(7.0, 8.0))
    builder.cubic_to(
        Point(9.0, 10.0),
        Point(11.0, 12.0),
        Point(13.0, 14.0),
    )
    builder.close()
    return builder^.finish()


def test_builder_rejects_drawing_before_move_to() raises:
    var line_builder = PathBuilder()
    with assert_raises(
        contains="line_to before move_to: begin a subpath with move_to first"
    ):
        line_builder.line_to(Point())

    var quad_builder = PathBuilder()
    with assert_raises(
        contains="quad_to before move_to: begin a subpath with move_to first"
    ):
        quad_builder.quad_to(Point(), Point())

    var cubic_builder = PathBuilder()
    with assert_raises(
        contains="cubic_to before move_to: begin a subpath with move_to first"
    ):
        cubic_builder.cubic_to(Point(), Point(), Point())

    var close_builder = PathBuilder()
    with assert_raises(
        contains="close before move_to: begin a subpath with move_to first"
    ):
        close_builder.close()


def test_builder_rejects_post_close_draw_until_new_move() raises:
    var builder = PathBuilder()
    builder.move_to(Point(0.0, 0.0))
    builder.line_to(Point(1.0, 0.0))
    builder.close()
    with assert_raises(
        contains="line_to before move_to: begin a subpath with move_to first"
    ):
        builder.line_to(Point(2.0, 0.0))

    builder.move_to(Point(2.0, 0.0))
    builder.line_to(Point(3.0, 0.0))
    var path = builder^.finish()
    var verbs = path.verbs()
    assert_true(len(verbs) == 5)
    assert_true(verbs[2] == PathVerb.CLOSE)
    assert_true(verbs[3] == PathVerb.MOVE)
    assert_true(verbs[4] == PathVerb.LINE)


def test_finish_drops_pending_empty_subpaths() raises:
    var empty_builder = PathBuilder()
    var empty = empty_builder^.finish()

    var move_only_builder = PathBuilder()
    move_only_builder.move_to(Point(4.0, 5.0))
    var move_only = move_only_builder^.finish()
    assert_true(move_only == empty)
    assert_true(move_only.is_empty())

    var drawn_builder = PathBuilder()
    drawn_builder.move_to(Point(1.0, 2.0))
    drawn_builder.line_to(Point(1.0, 4.0))
    drawn_builder.move_to(Point(8.0, 9.0))
    var trailing_move = drawn_builder^.finish()
    assert_true(trailing_move == _line_path(1.0))


def test_consecutive_move_to_keeps_only_drawn_from_move() raises:
    var builder = PathBuilder()
    builder.move_to(Point(-10.0, -20.0))
    builder.move_to(Point(1.0, 2.0))
    builder.line_to(Point(3.0, 4.0))
    var path = builder^.finish()
    var coordinates = path.coordinates()
    assert_true(path.verb_count() == 2)
    assert_true(path.point_count() == 2)
    assert_true(coordinates[0] == 1.0)
    assert_true(coordinates[1] == 2.0)
    assert_true(coordinates[2] == 3.0)
    assert_true(coordinates[3] == 4.0)


def test_verb_and_coordinate_layout() raises:
    var path = _mixed_path()
    var verbs = path.verbs()
    var coordinates = path.coordinates()
    var expected_verbs: List[PathVerb] = [
        PathVerb.MOVE,
        PathVerb.LINE,
        PathVerb.QUAD,
        PathVerb.CUBIC,
        PathVerb.CLOSE,
    ]
    assert_true(len(verbs) == len(expected_verbs))
    var summed_points = 0
    for index in range(len(verbs)):
        assert_true(verbs[index] == expected_verbs[index])
        summed_points += verbs[index].point_count()
    assert_true(len(coordinates) == 2 * summed_points)
    assert_true(len(coordinates) == 14)
    for index in range(len(coordinates)):
        assert_true(coordinates[index] == Float64(index + 1))


def test_path_equality_is_exact_and_structural() raises:
    assert_true(_mixed_path() == _mixed_path())
    assert_true(_line_path(3.0) == _line_path(3.0))
    assert_true(_line_path(3.0) != _line_path(5.0))
    assert_true(_line_path(3.0) != _mixed_path())


def test_transformed_maps_every_stored_point() raises:
    var path = _mixed_path()
    var transform = AffineTransform.translation(20.0, -7.0)
    var transformed = path.transformed(transform)
    var source = path.coordinates()
    var destination = transformed.coordinates()
    assert_true(len(source) == len(destination))
    for index in range(0, len(source), 2):
        var expected = transform.apply(Point(source[index], source[index + 1]))
        assert_true(destination[index] == expected.x())
        assert_true(destination[index + 1] == expected.y())
    assert_true(transformed.verbs()[0] == PathVerb.MOVE)
    assert_true(transformed.verbs()[4] == PathVerb.CLOSE)


def test_transformed_rejects_nonfinite_results() raises:
    var builder = PathBuilder()
    builder.move_to(Point(2.0, 0.0))
    builder.line_to(Point(3.0, 1.0))
    var path = builder^.finish()
    with assert_raises(contains="point x must be finite"):
        _ = path.transformed(AffineTransform.scale(1e308, 1.0))


def test_bounds_rejects_empty_and_bounds_lines_exactly() raises:
    var builder = PathBuilder()
    var empty = builder^.finish()
    with assert_raises(
        contains="path bounds are undefined for an empty path: add a subpath first"
    ):
        _ = empty.bounds()

    var line_builder = PathBuilder()
    line_builder.move_to(Point(-2.0, 4.0))
    line_builder.line_to(Point(5.0, -1.0))
    var line = line_builder^.finish()
    _assert_rect(line.bounds(), -2.0, -1.0, 5.0, 4.0)


def test_curve_bounds_include_all_control_points() raises:
    var builder = PathBuilder()
    builder.move_to(Point(2.0, 3.0))
    builder.quad_to(Point(-4.0, 10.0), Point(6.0, 1.0))
    builder.cubic_to(
        Point(12.0, -8.0),
        Point(-9.0, 14.0),
        Point(4.0, 5.0),
    )
    var path = builder^.finish()
    var bounds = path.bounds()
    _assert_rect(bounds, -9.0, -8.0, 12.0, 14.0)
    assert_true(bounds.min_x() <= 2.0 and bounds.min_x() <= 4.0)
    assert_true(bounds.min_y() <= 1.0 and bounds.min_y() <= 5.0)
    assert_true(bounds.max_x() >= 6.0 and bounds.max_x() >= 4.0)
    assert_true(bounds.max_y() >= 3.0 and bounds.max_y() >= 5.0)


def test_rectangle_layout_and_bounds() raises:
    var rect = Rect(-2.0, 1.0, 6.0, 7.0)
    var path = PathBuilder.rectangle(rect)
    var verbs = path.verbs()
    var coordinates = path.coordinates()
    assert_true(path.verb_count() == 5)
    assert_true(path.point_count() == 4)
    assert_true(verbs[0] == PathVerb.MOVE)
    assert_true(verbs[1] == PathVerb.LINE)
    assert_true(verbs[2] == PathVerb.LINE)
    assert_true(verbs[3] == PathVerb.LINE)
    assert_true(verbs[4] == PathVerb.CLOSE)
    var expected: List[Float64] = [-2.0, 1.0, 6.0, 1.0, 6.0, 7.0, -2.0, 7.0]
    for index in range(len(expected)):
        assert_true(coordinates[index] == expected[index])
    assert_true(path.bounds() == rect)


def _assert_circle_sample_radius(
    coordinates: Span[Float64, _],
    center: Point,
    radius: Float64,
) raises:
    for segment in range(4):
        var start = 3 * segment
        for sample in range(11):
            var t = Float64(sample) / 10.0
            var u = 1.0 - t
            var x = (
                u * u * u * coordinates[2 * start]
                + 3.0 * u * u * t * coordinates[2 * (start + 1)]
                + 3.0 * u * t * t * coordinates[2 * (start + 2)]
                + t * t * t * coordinates[2 * (start + 3)]
            )
            var y = (
                u * u * u * coordinates[2 * start + 1]
                + 3.0 * u * u * t * coordinates[2 * (start + 1) + 1]
                + 3.0 * u * t * t * coordinates[2 * (start + 2) + 1]
                + t * t * t * coordinates[2 * (start + 3) + 1]
            )
            var dx = x - center.x()
            var dy = y - center.y()
            var sampled_radius = sqrt(dx * dx + dy * dy)
            assert_true(abs(sampled_radius - radius) <= 5e-4 * radius)


def test_circle_verb_pattern_quadrants_and_radial_error() raises:
    var center = Point(2.0, -3.0)
    var radius = 10.0
    var path = PathBuilder.circle(center, radius)
    var verbs = path.verbs()
    var coordinates = path.coordinates()
    assert_true(len(verbs) == 6)
    assert_true(verbs[0] == PathVerb.MOVE)
    for index in range(1, 5):
        assert_true(verbs[index] == PathVerb.CUBIC)
    assert_true(verbs[5] == PathVerb.CLOSE)
    assert_true(path.point_count() == 13)

    var expected_quadrants: List[Float64] = [
        12.0,
        -3.0,
        2.0,
        7.0,
        -8.0,
        -3.0,
        2.0,
        -13.0,
        12.0,
        -3.0,
    ]
    for quadrant in range(5):
        var pair = 3 * quadrant
        assert_true(coordinates[2 * pair] == expected_quadrants[2 * quadrant])
        assert_true(coordinates[2 * pair + 1] == expected_quadrants[2 * quadrant + 1])
    _assert_circle_sample_radius(coordinates, center, radius)


def test_circle_rejects_invalid_radius_and_overflow() raises:
    var center = Point()
    with assert_raises(
        contains="circle radius must be a positive finite device-space distance"
    ):
        _ = PathBuilder.circle(center, 0.0)
    with assert_raises(
        contains="circle radius must be a positive finite device-space distance"
    ):
        _ = PathBuilder.circle(center, -1.0)
    with assert_raises(
        contains="circle radius must be a positive finite device-space distance"
    ):
        _ = PathBuilder.circle(center, Float64("nan"))
    with assert_raises(
        contains="circle radius must be a positive finite device-space distance"
    ):
        _ = PathBuilder.circle(center, Float64("inf"))
    with assert_raises(contains="point x must be finite"):
        _ = PathBuilder.circle(Point(1e308, 0.0), 1e308)


def test_path_verb_and_fill_rule_nominal_values() raises:
    assert_true(PathVerb.MOVE == PathVerb.MOVE)
    assert_true(PathVerb.MOVE != PathVerb.LINE)
    assert_true(PathVerb.QUAD != PathVerb.CUBIC)
    assert_true(PathVerb.MOVE.point_count() == 1)
    assert_true(PathVerb.LINE.point_count() == 1)
    assert_true(PathVerb.QUAD.point_count() == 2)
    assert_true(PathVerb.CUBIC.point_count() == 3)
    assert_true(PathVerb.CLOSE.point_count() == 0)
    assert_true(String(PathVerb.MOVE) == "MOVE")
    assert_true(String(PathVerb.CLOSE) == "CLOSE")

    assert_true(FillRule.NONZERO == FillRule.NONZERO)
    assert_true(FillRule.NONZERO != FillRule.EVEN_ODD)
    assert_true(String(FillRule.NONZERO) == "NONZERO")
    assert_true(String(FillRule.EVEN_ODD) == "EVEN_ODD")


def test_built_path_validates_and_writes_summary() raises:
    var path = _mixed_path()
    path.validate()
    assert_true(String(path) == "Path(5 verbs, 7 points)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
