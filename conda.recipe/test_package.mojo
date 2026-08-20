from kagerou import AffineTransform, Point
from std.math import abs
from std.testing import assert_true


def main() raises:
    var transform = AffineTransform.rotation(0.5).followed_by(
        AffineTransform.translation(3.0, -2.0)
    )
    var point = Point(4.0, 6.0)
    var restored = transform.inverted().apply(transform.apply(point))
    assert_true(abs(restored.x() - 4.0) <= 1e-12)
    assert_true(abs(restored.y() - 6.0) <= 1e-12)
