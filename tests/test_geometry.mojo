from kagerou import AffineTransform, Point
from std.math import abs
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance


def _near_relative(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance * max(1.0, abs(left), abs(right))


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


def test_rotation_uses_counterclockwise_radians() raises:
    var quarter_turn = AffineTransform.rotation(1.5707963267948966)
    _assert_point(quarter_turn.apply(Point(2.0, 3.0)), -3.0, 2.0)
    _assert_point(AffineTransform.rotation(0.0).apply(Point(-4.0, 5.0)), -4.0, 5.0)


def test_rotation_rejects_nonfinite_angles() raises:
    with assert_raises(contains="rotation angle must be finite"):
        _ = AffineTransform.rotation(Float64("nan"))
    with assert_raises(contains="rotation angle must be finite"):
        _ = AffineTransform.rotation(Float64("inf"))


def test_inverse_round_trip_and_composition_identity() raises:
    var transform = (
        AffineTransform.scale(1.5, 0.75)
        .followed_by(AffineTransform.rotation(0.37))
        .followed_by(AffineTransform.translation(-8.0, 3.5))
    )
    var inverse = transform.inverted()
    var point = Point(12.25, -6.5)

    _assert_point(inverse.apply(transform.apply(point)), point.x(), point.y())
    _assert_point(transform.apply(inverse.apply(point)), point.x(), point.y())
    _assert_point(transform.followed_by(inverse).apply(point), point.x(), point.y())
    _assert_point(inverse.followed_by(transform).apply(point), point.x(), point.y())


def test_inverse_reverses_composition_order() raises:
    var first = AffineTransform(2.0, 0.25, -0.5, 1.5, 3.0, -4.0)
    var second = AffineTransform.rotation(-0.62).followed_by(
        AffineTransform.translation(8.0, 2.0)
    )
    var point = Point(-1.25, 7.0)
    var composed_inverse = first.followed_by(second).inverted()
    var reversed_inverses = second.inverted().followed_by(first.inverted())
    var expected = reversed_inverses.apply(point)
    _assert_point(composed_inverse.apply(point), expected.x(), expected.y())


def test_inverse_handles_negative_determinant() raises:
    var transform = AffineTransform(0.0, 1.0, 1.0, 0.0, 2.0, -3.0)
    var inverse = transform.inverted()
    var point = Point(4.0, -7.0)
    _assert_point(inverse.apply(transform.apply(point)), point.x(), point.y())
    _assert_point(transform.apply(inverse.apply(point)), point.x(), point.y())


def test_inverse_reports_exact_singular_transforms() raises:
    with assert_raises(contains="transform is singular"):
        _ = AffineTransform.scale(0.0, 1.0).inverted()
    with assert_raises(contains="transform is singular"):
        _ = AffineTransform(1.0, 2.0, 2.0, 4.0, 3.0, -1.0).inverted()
    with assert_raises(contains="transform is singular"):
        _ = AffineTransform(1e308, 1e-308, 1e308, 1e-308, 0.0, 0.0).inverted()


def test_inverse_revalidates_mutated_storage() raises:
    var transform = AffineTransform.identity()
    transform._yy = Float64("nan")
    with assert_raises(contains="transform yy must be finite"):
        _ = transform.inverted()

    transform = AffineTransform.identity()
    transform._xx = 0.0
    transform._xy = 0.0
    with assert_raises(contains="transform is singular"):
        _ = transform.inverted()


def test_inverse_handles_extreme_finite_row_scales() raises:
    var transform = AffineTransform.scale(1e308, 1e-308)
    var inverse = transform.inverted()
    _assert_point(inverse.apply(Point(1e308, 1e-308)), 1.0, 1.0)


def test_inverse_preserves_mixed_scale_off_diagonal() raises:
    var transform = AffineTransform(1e308, 1e-308, 0.0, 1e-308, 0.0, 0.0)
    var inverse = transform.inverted()
    var output = Point(0.0, 1.0)
    var source = inverse.apply(output)
    assert_true(source.x() < 0.0)
    assert_true(_near_relative(source.x(), -1e-308))
    assert_true(_near_relative(source.y(), 1e308))
    _assert_point(transform.apply(source), output.x(), output.y())

    var restored = inverse.apply(transform.apply(source))
    assert_true(restored.x() < 0.0)
    assert_true(_near_relative(restored.x(), source.x()))
    assert_true(_near_relative(restored.y(), source.y()))


def test_inverse_does_not_misclassify_mixed_scale_determinant() raises:
    var transform = AffineTransform(1e308, 1e-308, 1e308, 2e-308, 0.0, 0.0)
    var inverse = transform.inverted()
    var output = Point(1.0, 0.0)
    var source = inverse.apply(output)
    assert_true(source.x() > 0.0)
    assert_true(source.y() < 0.0)
    assert_true(_near_relative(source.x(), 2e-308))
    assert_true(_near_relative(source.y(), -1e308))
    _assert_point(transform.apply(source), output.x(), output.y())

    var restored = inverse.apply(transform.apply(source))
    assert_true(restored.x() > 0.0)
    assert_true(restored.y() < 0.0)
    assert_true(_near_relative(restored.x(), source.x()))
    assert_true(_near_relative(restored.y(), source.y()))


def test_inverse_translation_allows_finite_cancellation() raises:
    var transform = AffineTransform(2e-308, 1e-308, 1e-308, 2e-308, 3.0, 3.0)
    var inverse = transform.inverted()
    var source = inverse.apply(Point())
    assert_true(_near_relative(source.x(), -1e308))
    assert_true(_near_relative(source.y(), -1e308))
    _assert_point(transform.apply(source), 0.0, 0.0)

    var restored = inverse.apply(transform.apply(source))
    assert_true(_near_relative(restored.x(), source.x()))
    assert_true(_near_relative(restored.y(), source.y()))


def test_inverse_rejects_nonrepresentable_result() raises:
    with assert_raises(contains="transform xx must be finite"):
        _ = AffineTransform.scale(1e-320, 1.0).inverted()
    with assert_raises(contains="transform xy is not representable"):
        _ = AffineTransform(1e308, 1.0, 0.0, 1e308, 0.0, 0.0).inverted()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
