from kagerou import AffineTransform, Point


def main() raises:
    var model_point = Point(2.0, 3.0)
    var transform = (
        AffineTransform.scale(8.0, 8.0)
        .followed_by(AffineTransform.rotation(0.25))
        .followed_by(AffineTransform.translation(16.0, 12.0))
    )
    var surface_point = transform.apply(model_point)
    var restored_point = transform.inverted().apply(surface_point)
    print(surface_point.x(), surface_point.y())
    print(restored_point.x(), restored_point.y())
