"""Long-running compiled path-raster workload for native sampling profilers."""

from kagerou import PathBuilder, Point, Rgba8, Surface
from std.benchmark import keep


comptime _WIDTH = 1920
comptime _HEIGHT = 1080
comptime _PASSES = 65_536


def main() raises:
    var surface = Surface(_WIDTH, _HEIGHT)
    var path = PathBuilder.circle(
        Point(Float64(_WIDTH) * 0.5, Float64(_HEIGHT) * 0.5),
        Float64(_HEIGHT) * 0.44,
    )
    var color = Rgba8(UInt8(73), UInt8(41), UInt8(19), UInt8(127))

    for index in range(_PASSES):
        surface.blend_path(path, color)
        if index % 128 == 0:
            keep(surface.pixel(index % _WIDTH, index % _HEIGHT).alpha())

    var observed = surface.pixel(_WIDTH // 2, _HEIGHT // 2)
    print("profile_path checksum=", Int(observed.alpha()), sep="")
