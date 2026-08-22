from kagerou import (
    AffineTransform,
    PathBuilder,
    PixelRect,
    Point,
    Rgba8,
    Surface,
)
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

    var mixed = AffineTransform(1e308, 1e-308, 0.0, 1e-308, 0.0, 0.0)
    var mixed_source = mixed.inverted().apply(Point(0.0, 1.0))
    assert_true(mixed_source.x() < 0.0)
    var mixed_round_trip = mixed.apply(mixed_source)
    assert_true(abs(mixed_round_trip.x()) <= 1e-12)
    assert_true(abs(mixed_round_trip.y() - 1.0) <= 1e-12)

    var cancellation = AffineTransform(2e-308, 1e-308, 1e-308, 2e-308, 3.0, 3.0)
    var cancellation_source = cancellation.inverted().apply(Point())
    var cancellation_round_trip = cancellation.apply(cancellation_source)
    assert_true(abs(cancellation_round_trip.x()) <= 1e-12)
    assert_true(abs(cancellation_round_trip.y()) <= 1e-12)

    var surface = Surface(2, 1)
    var color = Rgba8(UInt8(64), UInt8(32), UInt8(16), UInt8(128))
    surface.blend_span(0, 0, 2, color)
    assert_true(surface.pixel(1, 0) == color)

    var builder = PathBuilder()
    builder.move_to(Point(0.0, 0.0))
    builder.line_to(Point(2.0, 0.0))
    builder.line_to(Point(0.0, 1.0))
    surface.fill_path_clipped(builder^.finish(), PixelRect(0, 0, 1, 1), color)
    assert_true(surface.pixel(0, 0) == color)
    assert_true(surface.row_bytes() == 8)
    var storage = surface.bytes()
    assert_true(len(storage) == 8)
    assert_true(storage[0] == color.red())
    assert_true(storage[7] == color.alpha())
