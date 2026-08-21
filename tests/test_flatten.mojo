from kagerou import (
    DEFAULT_FLATTEN_TOLERANCE,
    Path,
    PathBuilder,
    PathVerb,
    Point,
)
from std.collections import List
from std.math import cos, exp, pi, sin, sqrt
from std.testing import TestSuite, assert_raises, assert_true


comptime _INTERVAL_COUNT = 12
comptime _DOMAIN_END = 6.0
comptime _FLATTEN_ERROR = (
    "flatten tolerance must be a positive finite device-space distance "
    "(0.25 recommended for antialiased output)"
)


def _line_count(path: Path) -> Int:
    var count = 0
    for verb in path.verbs():
        if verb == PathVerb.LINE:
            count += 1
    return count


def _point_segment_distance(
    x: Float64,
    y: Float64,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
) -> Float64:
    var dx = x1 - x0
    var dy = y1 - y0
    var length_squared = dx * dx + dy * dy
    if length_squared == 0.0:
        dx = x - x0
        dy = y - y0
        return sqrt(dx * dx + dy * dy)
    var factor = ((x - x0) * dx + (y - y0) * dy) / length_squared
    factor = max(0.0, min(1.0, factor))
    dx = x - (x0 + factor * dx)
    dy = y - (y0 + factor * dy)
    return sqrt(dx * dx + dy * dy)


def _minimum_polyline_distance(
    coordinates: Span[Float64, _],
    x: Float64,
    y: Float64,
) -> Float64:
    var result = _point_segment_distance(
        x,
        y,
        coordinates[0],
        coordinates[1],
        coordinates[2],
        coordinates[3],
    )
    for index in range(4, len(coordinates), 2):
        result = min(
            result,
            _point_segment_distance(
                x,
                y,
                coordinates[index - 2],
                coordinates[index - 1],
                coordinates[index],
                coordinates[index + 1],
            ),
        )
    return result


def _assert_only_flat_verbs(path: Path) raises:
    for verb in path.verbs():
        assert_true(
            verb == PathVerb.MOVE or verb == PathVerb.LINE or verb == PathVerb.CLOSE
        )


def _assert_quadratic_error_bound(
    start: Point,
    control: Point,
    endpoint: Point,
    tolerance: Float64,
) raises:
    var builder = PathBuilder()
    builder.move_to(start)
    builder.quad_to(control, endpoint)
    var flattened = builder^.finish().flattened(tolerance)
    _assert_only_flat_verbs(flattened)
    var coordinates = flattened.coordinates()
    for sample in range(257):
        var t = Float64(sample) / 256.0
        var u = 1.0 - t
        var x = u * u * start.x() + 2.0 * u * t * control.x() + t * t * endpoint.x()
        var y = u * u * start.y() + 2.0 * u * t * control.y() + t * t * endpoint.y()
        assert_true(_minimum_polyline_distance(coordinates, x, y) <= tolerance)
    assert_true(coordinates[len(coordinates) - 2] == endpoint.x())
    assert_true(coordinates[len(coordinates) - 1] == endpoint.y())


def _assert_cubic_error_bound(
    start: Point,
    control1: Point,
    control2: Point,
    endpoint: Point,
    tolerance: Float64,
) raises:
    var builder = PathBuilder()
    builder.move_to(start)
    builder.cubic_to(control1, control2, endpoint)
    var flattened = builder^.finish().flattened(tolerance)
    _assert_only_flat_verbs(flattened)
    var coordinates = flattened.coordinates()
    for sample in range(257):
        var t = Float64(sample) / 256.0
        var u = 1.0 - t
        var x = (
            u * u * u * start.x()
            + 3.0 * u * u * t * control1.x()
            + 3.0 * u * t * t * control2.x()
            + t * t * t * endpoint.x()
        )
        var y = (
            u * u * u * start.y()
            + 3.0 * u * u * t * control1.y()
            + 3.0 * u * t * t * control2.y()
            + t * t * t * endpoint.y()
        )
        assert_true(_minimum_polyline_distance(coordinates, x, y) <= tolerance)
    assert_true(coordinates[len(coordinates) - 2] == endpoint.x())
    assert_true(coordinates[len(coordinates) - 1] == endpoint.y())


def test_flattening_sampled_error_bound_for_quadratics_and_cubics() raises:
    var tolerances: List[Float64] = [1.0, 0.25, 0.01]
    for tolerance in tolerances:
        _assert_quadratic_error_bound(
            Point(0.0, 0.0), Point(8.0, 20.0), Point(16.0, 0.0), tolerance
        )
        _assert_quadratic_error_bound(
            Point(3.0, -2.0), Point(12.0, 9.0), Point(3.0, -2.0), tolerance
        )
        _assert_cubic_error_bound(
            Point(0.0, 0.0),
            Point(0.0, 20.0),
            Point(20.0, -20.0),
            Point(20.0, 0.0),
            tolerance,
        )
        _assert_cubic_error_bound(
            Point(1.0, 1.0),
            Point(1.0, 1.0),
            Point(1.0, 1.0),
            Point(1.000001, 1.000002),
            tolerance,
        )


def test_circle_factory_cubics_meet_sampled_error_bound() raises:
    var circle = PathBuilder.circle(Point(2.0, -3.0), 20.0)
    var coordinates = circle.coordinates()
    var tolerances: List[Float64] = [1.0, 0.25, 0.01]
    for tolerance in tolerances:
        for segment in range(4):
            var start = 3 * segment
            _assert_cubic_error_bound(
                Point(coordinates[2 * start], coordinates[2 * start + 1]),
                Point(
                    coordinates[2 * (start + 1)],
                    coordinates[2 * (start + 1) + 1],
                ),
                Point(
                    coordinates[2 * (start + 2)],
                    coordinates[2 * (start + 2) + 1],
                ),
                Point(
                    coordinates[2 * (start + 3)],
                    coordinates[2 * (start + 3) + 1],
                ),
                tolerance,
            )


def _signal(x: Float64) -> Float64:
    return exp(-x / 3.0) * sin(2.0 * pi * x)


def _signal_derivative(x: Float64) -> Float64:
    return exp(-x / 3.0) * (2.0 * pi * cos(2.0 * pi * x) - sin(2.0 * pi * x) / 3.0)


def _damped_sine_path() raises -> Path:
    var step = _DOMAIN_END / Float64(_INTERVAL_COUNT)
    var builder = PathBuilder()
    builder.move_to(Point(0.0, _signal(0.0)))
    for index in range(_INTERVAL_COUNT):
        var x0 = Float64(index) * step
        var x1 = Float64(index + 1) * step
        var y0 = _signal(x0)
        var y1 = _signal(x1)
        builder.cubic_to(
            Point(x0 + step / 3.0, y0 + step * _signal_derivative(x0) / 3.0),
            Point(x1 - step / 3.0, y1 - step * _signal_derivative(x1) / 3.0),
            Point(x1, y1),
        )
    return builder^.finish()


def test_damped_sine_golden_counts_and_monotonicity() raises:
    var path = _damped_sine_path()
    var coarse = _line_count(path.flattened(1.0))
    var default = _line_count(path.flattened(0.25))
    var precise = _line_count(path.flattened(0.01))
    assert_true(coarse == 13)
    assert_true(default == 21)
    assert_true(precise == 93)
    assert_true(precise >= default and default >= coarse)


def test_flattened_vocabulary_and_exact_curve_endpoints() raises:
    var builder = PathBuilder()
    builder.move_to(Point(0.0, 0.0))
    builder.quad_to(Point(2.0, 5.0), Point(4.0, 1.0))
    builder.cubic_to(Point(5.0, -4.0), Point(7.0, 6.0), Point(8.0, 0.0))
    builder.close()
    var flattened = builder^.finish().flattened(0.25)
    _assert_only_flat_verbs(flattened)
    var coordinates = flattened.coordinates()
    var found_quadratic_endpoint = False
    var found_cubic_endpoint = False
    for index in range(0, len(coordinates), 2):
        if coordinates[index] == 4.0 and coordinates[index + 1] == 1.0:
            found_quadratic_endpoint = True
        if coordinates[index] == 8.0 and coordinates[index + 1] == 0.0:
            found_cubic_endpoint = True
    assert_true(found_quadratic_endpoint)
    assert_true(found_cubic_endpoint)
    assert_true(flattened.verbs()[flattened.verb_count() - 1] == PathVerb.CLOSE)


def test_invalid_flatten_tolerances_use_teaching_message() raises:
    var builder = PathBuilder()
    builder.move_to(Point())
    builder.line_to(Point(1.0, 1.0))
    var path = builder^.finish()
    with assert_raises(contains=_FLATTEN_ERROR):
        _ = path.flattened(0.0)
    with assert_raises(contains=_FLATTEN_ERROR):
        _ = path.flattened(-1.0)
    with assert_raises(contains=_FLATTEN_ERROR):
        _ = path.flattened(Float64("nan"))
    with assert_raises(contains=_FLATTEN_ERROR):
        _ = path.flattened(Float64("inf"))


def test_straight_curves_flatten_to_one_line_each() raises:
    var quadratic_builder = PathBuilder()
    quadratic_builder.move_to(Point(0.0, 0.0))
    quadratic_builder.quad_to(Point(5.0, 5.0), Point(10.0, 10.0))
    assert_true(_line_count(quadratic_builder^.finish().flattened()) == 1)

    var cubic_builder = PathBuilder()
    cubic_builder.move_to(Point(0.0, 0.0))
    cubic_builder.cubic_to(Point(3.0, 3.0), Point(7.0, 7.0), Point(10.0, 10.0))
    assert_true(_line_count(cubic_builder^.finish().flattened()) == 1)


def test_flattening_line_path_is_exactly_idempotent() raises:
    var builder = PathBuilder()
    builder.move_to(Point(-2.0, 3.0))
    builder.line_to(Point(4.0, 5.0))
    builder.line_to(Point(8.0, -1.0))
    builder.close()
    var path = builder^.finish()
    assert_true(path.flattened() == path)
    assert_true(DEFAULT_FLATTEN_TOLERANCE == 0.25)
    assert_true(path.flattened() == path.flattened(DEFAULT_FLATTEN_TOLERANCE))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
