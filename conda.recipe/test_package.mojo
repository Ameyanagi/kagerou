from kagerou import AffineTransform, Point
from std.testing import assert_true


def main() raises:
    assert_true(AffineTransform.identity().apply(Point()).x() == 0.0)
