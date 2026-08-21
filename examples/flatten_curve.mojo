from kagerou import AffineTransform, Path, PathBuilder, PathVerb, Point
from std.collections import List
from std.math import cos, exp, pi, sin


comptime _INTERVAL_COUNT = 12
comptime _DOMAIN_END = 6.0


def _signal(x: Float64) -> Float64:
    return exp(-x / 3.0) * sin(2.0 * pi * x)


def _signal_derivative(x: Float64) -> Float64:
    return exp(-x / 3.0) * (2.0 * pi * cos(2.0 * pi * x) - sin(2.0 * pi * x) / 3.0)


def _damped_sine_path() raises -> Path:
    """Approximate the analytic signal with 12 cubic Hermite intervals."""
    var step = _DOMAIN_END / Float64(_INTERVAL_COUNT)
    var builder = PathBuilder()
    builder.move_to(Point(0.0, _signal(0.0)))
    for index in range(_INTERVAL_COUNT):
        var x0 = Float64(index) * step
        var x1 = Float64(index + 1) * step
        var y0 = _signal(x0)
        var y1 = _signal(x1)
        # Cubic Hermite-to-Bézier conversion: endpoint derivatives determine
        # controls one third of the interval along each endpoint tangent.
        builder.cubic_to(
            Point(x0 + step / 3.0, y0 + step * _signal_derivative(x0) / 3.0),
            Point(x1 - step / 3.0, y1 - step * _signal_derivative(x1) / 3.0),
            Point(x1, y1),
        )
    return builder^.finish()


def _line_count(path: Path) -> Int:
    var count = 0
    for verb in path.verbs():
        if verb == PathVerb.LINE:
            count += 1
    return count


def main() raises:
    # The analytic curve is first built in raw mathematical coordinates. The
    # viewport transform flips y once at the y-down device-space boundary.
    var curve = _damped_sine_path()
    print("line segments at tolerance 1.0:", _line_count(curve.flattened(1.0)))
    print("line segments at tolerance 0.25:", _line_count(curve.flattened(0.25)))
    print("line segments at tolerance 0.01:", _line_count(curve.flattened(0.01)))

    var xs: List[Float64] = [0.0, 3.0, 6.0]
    var ys: List[Float64] = [_signal(0.0), _signal(3.0), _signal(6.0)]
    var viewport = AffineTransform.scale(800.0 / 6.0, -250.0).followed_by(
        AffineTransform.translation(0.0, 300.0)
    )
    viewport.apply_batch(xs, ys)
    for index in range(len(xs)):
        print("viewport sample", index, xs[index], ys[index])
