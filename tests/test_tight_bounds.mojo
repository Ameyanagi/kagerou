from kagerou import AffineTransform, Path, PathBuilder, Point
from std.math import abs, sqrt
from std.testing import TestSuite, assert_raises, assert_true


def _quadratic(p0: Float64, p1: Float64, p2: Float64) raises -> Path:
    var builder = PathBuilder()
    builder.move_to(Point(0.0, p0))
    builder.quad_to(Point(1.0, p1), Point(2.0, p2))
    return builder^.finish()


def _cubic(p0: Float64, p1: Float64, p2: Float64, p3: Float64) raises -> Path:
    var builder = PathBuilder()
    builder.move_to(Point(0.0, p0))
    builder.cubic_to(Point(1.0, p1), Point(2.0, p2), Point(3.0, p3))
    return builder^.finish()


def test_quadratic_exact_extremum_and_control_box() raises:
    var path = _quadratic(0.0, 2.0, 0.0)
    assert_true(path.bounds() == path.control_bounds())
    assert_true(path.bounds().max_y() == 2.0)
    assert_true(path.tight_bounds().max_y() == 1.0)
    assert_true(path.tight_bounds().min_y() == 0.0)
    assert_true(path.tight_bounds().min_x() == 0.0)
    assert_true(path.tight_bounds().max_x() == 2.0)


def test_cubic_two_interior_extrema() raises:
    var bounds = _cubic(0.0, 1.0, -1.0, 0.0).tight_bounds()
    assert_true(abs(bounds.max_y() - sqrt(3.0) / 6.0) < 1e-15)
    assert_true(abs(bounds.min_y() + sqrt(3.0) / 6.0) < 1e-15)


def test_degenerate_constant_linear_and_double_root() raises:
    assert_true(_quadratic(2.0, 2.0, 2.0).tight_bounds().max_y() == 2.0)
    assert_true(_quadratic(0.0, 1.0, 2.0).tight_bounds().max_y() == 2.0)
    assert_true(_cubic(0.0, 1.0, 2.0, 3.0).tight_bounds().min_y() == 0.0)
    assert_true(_cubic(0.0, 2.0, 2.0, 0.0).tight_bounds().max_y() == 1.5)
    # (2t-1)^3 has a double derivative root but no interior extremum.
    var stationary = _cubic(-1.0, 1.0, -1.0, 1.0).tight_bounds()
    assert_true(stationary.min_y() == -1.0)
    assert_true(stationary.max_y() == 1.0)
    assert_true(_cubic(0.0, 0.0, 0.0, 1.0).tight_bounds().max_y() == 1.0)


def test_near_linear_and_endpoint_roots() raises:
    var near = _cubic(0.0, 2.0, 2.0, 1e-14).tight_bounds()
    assert_true(abs(near.max_y() - 1.5) < 3e-15)
    assert_true(near.min_y() == 0.0)
    var near_endpoint = _quadratic(0.0, -1e-10, 1.0).tight_bounds()
    assert_true(near_endpoint.min_y() < 0.0)
    assert_true(abs(near_endpoint.min_y() / -1e-20 - 1.0) < 1e-8)


def test_huge_finite_and_subnormal_coordinates() raises:
    var bounds = _quadratic(-1e308, 1e308, -1e308).tight_bounds()
    assert_true(bounds.min_y() == -1e308)
    assert_true(bounds.max_y() == 0.0)
    var large = _cubic(0.0, 1e308, -1e308, 0.0).tight_bounds()
    assert_true(abs(large.max_y() / 1e308 - sqrt(3.0) / 6.0) < 1e-15)
    assert_true(abs(large.min_y() / 1e308 + sqrt(3.0) / 6.0) < 1e-15)
    var tiny = _quadratic(0.0, 1e-310, 0.0).tight_bounds()
    assert_true(abs(tiny.max_y() / 1e-310 - 0.5) < 1e-12)


def test_transforms_and_multiple_closed_subpaths() raises:
    var path = _quadratic(0.0, 2.0, 0.0)
    var moved = path.transformed(AffineTransform.translation(5.0, -7.0))
    assert_true(moved.tight_bounds().min_x() == 5.0)
    assert_true(moved.tight_bounds().max_y() == -6.0)
    var rotated = path.transformed(AffineTransform(0.0, -1.0, 1.0, 0.0, 0.0, 0.0))
    assert_true(abs(rotated.tight_bounds().min_x() + 1.0) < 1e-15)
    var sheared = path.transformed(AffineTransform(1.0, 1.0, 0.0, 1.0, 0.0, 0.0))
    # x(t) + y(t) = 6t - 4t^2 reaches 2.25 at t=0.75, not a
    # transformed corner of the original axis-aligned bounding rectangle.
    assert_true(abs(sheared.tight_bounds().max_x() - 2.25) < 1e-15)
    var builder = PathBuilder()
    builder.move_to(Point(-2.0, 4.0))
    builder.line_to(Point(3.0, -1.0))
    builder.close()
    builder.move_to(Point(10.0, 10.0))
    builder.quad_to(Point(12.0, 14.0), Point(14.0, 10.0))
    builder.close()
    var combined = builder^.finish().tight_bounds()
    assert_true(combined.min_x() == -2.0)
    assert_true(abs(combined.max_y() - 12.0) < 3e-15)


def test_empty_bounds_contract() raises:
    var builder = PathBuilder()
    var path = builder^.finish()
    with assert_raises(contains="path bounds are undefined for an empty path"):
        _ = path.tight_bounds()
    with assert_raises(contains="path bounds are undefined for an empty path"):
        _ = path.control_bounds()


def test_dense_bernstein_reference_over_diverse_cubics() raises:
    # Independent Bernstein evaluation, including monotone, near-linear,
    # inflectional, and oppositely signed control configurations.
    for seed in range(81):
        var p0 = Float64(seed % 3 - 1)
        var p1 = Float64((seed // 3) % 3 - 1)
        var p2 = Float64((seed // 9) % 3 - 1)
        var p3 = Float64((seed // 27) % 3 - 1)
        var bounds = _cubic(p0, p1, p2, p3).tight_bounds()
        var sampled_min = p0
        var sampled_max = p0
        for index in range(1001):
            var t = Float64(index) / 1000.0
            var u = 1.0 - t
            var value = (
                u * u * u * p0
                + 3.0 * u * u * t * p1
                + 3.0 * u * t * t * p2
                + t * t * t * p3
            )
            assert_true(value >= bounds.min_y() - 2e-15)
            assert_true(value <= bounds.max_y() + 2e-15)
            sampled_min = min(sampled_min, value)
            sampled_max = max(sampled_max, value)
        assert_true(abs(sampled_min - bounds.min_y()) < 6e-6)
        assert_true(abs(sampled_max - bounds.max_y()) < 6e-6)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
