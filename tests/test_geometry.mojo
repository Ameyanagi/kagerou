from kagerou import AffineTransform, Point
from std.math import abs
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance


def _assert_point(point: Point, x: Float64, y: Float64) raises:
    assert_true(_near(point.x(), x))
    assert_true(_near(point.y(), y))


def test_identity_preserves_point() raises:
    var point = Point(2.0, -3.0)
    _assert_point(AffineTransform.identity().apply(point), 2.0, -3.0)


def test_translation_and_scale_have_expected_geometry() raises:
    var point = Point(2.0, 3.0)
    _assert_point(AffineTransform.translation(4.0, -1.0).apply(point), 6.0, 2.0)
    _assert_point(AffineTransform.scale(2.0, 0.5).apply(point), 4.0, 1.5)


def test_point_translation_is_checked() raises:
    var point = Point(1.5, -2.0)
    _assert_point(point.translated(2.5, 3.0), 4.0, 1.0)
    with assert_raises(contains="translation x must be finite"):
        _ = point.translated(Float64("nan"), 0.0)
    with assert_raises(contains="translation y must be finite"):
        _ = point.translated(0.0, Float64("inf"))

    point._x = Float64("nan")
    with assert_raises(contains="point x must be finite"):
        _ = point.translated(1.0, 1.0)


def test_point_translation_rejects_floating_overflow() raises:
    with assert_raises(contains="point x must be finite"):
        _ = Point(1e308, 0.0).translated(1e308, 0.0)


def test_composition_order_is_explicit() raises:
    var translate = AffineTransform.translation(1.0, 2.0)
    var scale = AffineTransform.scale(2.0, 3.0)
    var composed = translate.followed_by(scale)
    _assert_point(composed.apply(Point(4.0, 5.0)), 10.0, 21.0)


def test_dense_affine_composition_matches_sequential_application() raises:
    var first = AffineTransform(1.5, -0.25, 0.75, 2.0, -3.0, 4.0)
    var second = AffineTransform(-1.0, 0.5, 1.25, 0.8, 2.0, -5.0)
    var point = Point(2.5, -1.5)
    var sequential = second.apply(first.apply(point))
    var composed = first.followed_by(second).apply(point)
    _assert_point(composed, sequential.x(), sequential.y())


def test_non_finite_geometry_is_rejected() raises:
    with assert_raises(contains="point x must be finite"):
        _ = Point(Float64("nan"), 0.0)
    with assert_raises(contains="transform tx must be finite"):
        _ = AffineTransform.translation(Float64("inf"), 0.0)


def test_public_operations_revalidate_mutated_storage() raises:
    var point = Point(1.0, 2.0)
    point._x = Float64("nan")
    with assert_raises(contains="point x must be finite"):
        _ = point.x()
    with assert_raises(contains="point x must be finite"):
        _ = AffineTransform.identity().apply(point)

    var transform = AffineTransform.identity()
    transform._xy = Float64("inf")
    with assert_raises(contains="transform xy must be finite"):
        _ = transform.apply(Point())
    with assert_raises(contains="transform xy must be finite"):
        _ = transform.followed_by(AffineTransform.identity())


def test_apply_rejects_floating_overflow() raises:
    var huge_scale = AffineTransform.scale(1e308, 1.0)
    with assert_raises(contains="point x must be finite"):
        _ = huge_scale.apply(Point(2.0, 0.0))


def test_composition_rejects_floating_overflow() raises:
    var huge_scale = AffineTransform.scale(1e308, 1.0)
    var double_scale = AffineTransform.scale(2.0, 1.0)
    with assert_raises(contains="transform xx must be finite"):
        _ = huge_scale.followed_by(double_scale)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
