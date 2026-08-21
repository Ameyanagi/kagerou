from kagerou import AffineTransform, Point, Rect, Vec2
from std.math import abs
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance


def _near_relative(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance * max(1.0, abs(left), abs(right))


def _assert_point(point: Point, x: Float64, y: Float64) raises:
    assert_true(_near(point.x(), x))
    assert_true(_near(point.y(), y))


def _assert_vector(vector: Vec2, dx: Float64, dy: Float64) raises:
    assert_true(_near(vector.dx(), dx))
    assert_true(_near(vector.dy(), dy))


def _assert_rect(
    rect: Rect,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
) raises:
    assert_true(_near(rect.min_x(), x0))
    assert_true(_near(rect.min_y(), y0))
    assert_true(_near(rect.max_x(), x1))
    assert_true(_near(rect.max_y(), y1))


def test_vector_constructor_rejects_nonfinite_components() raises:
    with assert_raises(contains="vector dx must be finite"):
        _ = Vec2(Float64("nan"), 0.0)
    with assert_raises(contains="vector dx must be finite"):
        _ = Vec2(Float64("inf"), 0.0)
    with assert_raises(contains="vector dy must be finite"):
        _ = Vec2(0.0, Float64("nan"))
    with assert_raises(contains="vector dy must be finite"):
        _ = Vec2(0.0, Float64("inf"))


def test_vector_products_and_length() raises:
    var vector = Vec2(3.0, 4.0)
    var other = Vec2(2.0, -1.0)
    assert_true(vector.dot(other) == 2.0)
    assert_true(vector.cross(other) == -11.0)
    assert_true(vector.length() == 5.0)


def test_vector_products_and_length_reject_overflow() raises:
    with assert_raises(contains="vector dot product must be finite"):
        _ = Vec2(1e308, 0.0).dot(Vec2(2.0, 0.0))
    with assert_raises(contains="vector cross product must be finite"):
        _ = Vec2(1e308, 0.0).cross(Vec2(0.0, 2.0))
    with assert_raises(contains="vector length must be finite"):
        _ = Vec2(1e308, 0.0).length()


def test_vector_arithmetic_is_checked() raises:
    var vector = Vec2(3.0, -4.0)
    _assert_vector(vector + Vec2(2.0, 1.0), 5.0, -3.0)
    _assert_vector(vector - Vec2(2.0, 1.0), 1.0, -5.0)
    _assert_vector(vector * 2.0, 6.0, -8.0)
    _assert_vector(-vector, -3.0, 4.0)
    with assert_raises(contains="vector scale factor must be finite, got inf"):
        _ = vector * Float64("inf")
    with assert_raises(contains="vector dx must be finite"):
        _ = Vec2(1e308, 0.0) + Vec2(1e308, 0.0)
    with assert_raises(contains="vector dx must be finite"):
        _ = Vec2(1e308, 0.0) * 2.0


def test_point_vector_interop_round_trip() raises:
    var start = Point(-2.0, 5.0)
    var end = Point(3.0, -1.0)
    var delta = end - start
    _assert_vector(delta, 5.0, -6.0)
    _assert_point(start + delta, end.x(), end.y())
    _assert_point(end - delta, start.x(), start.y())


def test_point_vector_translation_rejects_overflow() raises:
    with assert_raises(contains="point x must be finite"):
        _ = Point(1e308, 0.0) + Vec2(1e308, 0.0)


def test_transform_applies_linear_part_to_vectors() raises:
    var vector = Vec2(2.0, 3.0)
    _assert_vector(AffineTransform.translation(5.0, 7.0).apply(vector), 2.0, 3.0)

    var quarter_turn = AffineTransform.rotation(1.5707963267948966)
    _assert_vector(quarter_turn.apply(vector), -3.0, 2.0)

    var transform = AffineTransform(2.0, 0.0, 0.0, 3.0, 5.0, 7.0)
    _assert_point(transform.apply(Point(1.0, 2.0)), 7.0, 13.0)
    _assert_vector(transform.apply(Vec2(1.0, 2.0)), 2.0, 6.0)


def test_transform_vector_application_rejects_overflow() raises:
    var huge_scale = AffineTransform.scale(1e308, 1.0)
    with assert_raises(contains="vector dx must be finite"):
        _ = huge_scale.apply(Vec2(2.0, 0.0))


def test_rect_constructor_rejects_unsorted_edges() raises:
    with assert_raises(contains="rect x0 (2.0) must not exceed x1 (1.0)"):
        _ = Rect(2.0, 0.0, 1.0, 1.0)
    with assert_raises(contains="rect y0 (2.0) must not exceed y1 (1.0)"):
        _ = Rect(0.0, 2.0, 1.0, 1.0)


def test_rect_constructor_rejects_nonfinite_edges_and_extents() raises:
    with assert_raises(contains="rect x0 must be finite"):
        _ = Rect(Float64("nan"), 0.0, 1.0, 1.0)
    with assert_raises(contains="rect y0 must be finite"):
        _ = Rect(0.0, Float64("inf"), 1.0, 1.0)
    with assert_raises(contains="rect x1 must be finite"):
        _ = Rect(0.0, 0.0, Float64("inf"), 1.0)
    with assert_raises(contains="rect y1 must be finite"):
        _ = Rect(0.0, 0.0, 1.0, Float64("nan"))
    with assert_raises(contains="rect width must be finite"):
        _ = Rect(-1e308, 0.0, 1e308, 1.0)
    with assert_raises(contains="rect height must be finite"):
        _ = Rect(0.0, -1e308, 1.0, 1e308)


def test_rect_from_points_sorts_both_axes() raises:
    var rect = Rect.from_points(Point(5.0, 7.0), Point(1.0, 2.0))
    _assert_rect(rect, 1.0, 2.0, 5.0, 7.0)
    with assert_raises(contains="rect width must be finite"):
        _ = Rect.from_points(Point(-1e308, 0.0), Point(1e308, 1.0))


def test_rect_accessors_dimensions_and_center() raises:
    var rect = Rect(-2.0, 1.0, 6.0, 7.0)
    assert_true(rect.min_x() == -2.0)
    assert_true(rect.min_y() == 1.0)
    assert_true(rect.max_x() == 6.0)
    assert_true(rect.max_y() == 7.0)
    assert_true(rect.width() == 8.0)
    assert_true(rect.height() == 6.0)
    _assert_point(rect.center(), 2.0, 4.0)

    var large_rect = Rect(1e308, 0.0, 1.6e308, 2.0)
    var large_center = large_rect.center()
    assert_true(_near_relative(large_center.x(), 1.3e308))
    assert_true(large_center.y() == 1.0)


def test_rect_contains_closed_boundaries() raises:
    var rect = Rect(1.0, 2.0, 5.0, 7.0)
    assert_true(rect.contains(Point(3.0, 4.0)))
    assert_true(rect.contains(Point(1.0, 2.0)))
    assert_true(rect.contains(Point(5.0, 7.0)))
    assert_true(not rect.contains(Point(0.0, 4.0)))
    assert_true(not rect.contains(Point(3.0, 8.0)))


def test_rect_union_and_intersection() raises:
    var first = Rect(0.0, 0.0, 4.0, 4.0)
    var second = Rect(2.0, -1.0, 6.0, 2.0)
    _assert_rect(first.union(second), 0.0, -1.0, 6.0, 4.0)
    _assert_rect(first.intersection(second), 2.0, 0.0, 4.0, 2.0)
    assert_true(first.intersection(first) == first)


def test_rect_disjoint_intersection_is_clamped_empty() raises:
    var intersection = Rect(0.0, 0.0, 1.0, 1.0).intersection(Rect(3.0, 4.0, 5.0, 6.0))
    _assert_rect(intersection, 3.0, 4.0, 3.0, 4.0)
    assert_true(intersection.is_empty())
    assert_true(Rect(0.0, 0.0, 0.0, 2.0).is_empty())


def test_rect_union_rejects_nonfinite_combined_extent() raises:
    var left = Rect(-1e308, 0.0, -5e307, 1.0)
    var right = Rect(5e307, 0.0, 1e308, 1.0)
    with assert_raises(contains="rect width must be finite"):
        _ = left.union(right)


def test_rect_inflation_grows_and_shrinks() raises:
    var rect = Rect(0.0, 0.0, 4.0, 6.0)
    _assert_rect(rect.inflated(1.0), -1.0, -1.0, 5.0, 7.0)
    _assert_rect(rect.inflated(-1.0), 1.0, 1.0, 3.0, 5.0)
    _assert_rect(rect.inflated(-2.0), 2.0, 2.0, 2.0, 4.0)


def test_rect_inflation_rejects_invalid_results() raises:
    var rect = Rect(0.0, 0.0, 4.0, 6.0)
    with assert_raises(
        contains=(
            "rect inflation amount -3.0 collapses the rect past its center "
            "(width 4.0, height 6.0): use a smaller deflation"
        )
    ):
        _ = rect.inflated(-3.0)
    with assert_raises(contains="rect inflation amount must be finite"):
        _ = rect.inflated(Float64("nan"))
    with assert_raises(contains="rect inflation amount must be finite"):
        _ = rect.inflated(Float64("inf"))
    with assert_raises(contains="rect x0 must be finite"):
        _ = Rect(-1e308, 0.0, -5e307, 1.0).inflated(1e308)


def test_vector_and_rect_validate_mutated_storage() raises:
    var vector = Vec2(1.0, 2.0)
    vector._dy = Float64("nan")
    with assert_raises(contains="vector dy must be finite"):
        vector.validate()

    var rect = Rect(0.0, 0.0, 2.0, 3.0)
    rect._x1 = -1.0
    with assert_raises(contains="rect x0 (0.0) must not exceed x1 (-1.0)"):
        rect.validate()


def test_vector_and_rect_equality_and_string_representation() raises:
    var vector = Vec2(1.5, -2.25)
    assert_true(vector == Vec2(1.5, -2.25))
    assert_true(vector != Vec2(1.5, 2.25))
    assert_true(String(vector) == "Vec2(1.5, -2.25)")

    var rect = Rect(1.0, -2.0, 3.5, 4.25)
    assert_true(rect == Rect(1.0, -2.0, 3.5, 4.25))
    assert_true(rect != Rect(1.0, -2.0, 3.5, 5.0))
    assert_true(String(rect) == "Rect(1.0, -2.0, 3.5, 4.25)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
