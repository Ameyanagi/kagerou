"""Long-running compiled workload for native sampling profilers."""

from kagerou import Rgba8, Surface
from std.benchmark import keep


comptime _WIDTH = 1920
comptime _HEIGHT = 1080
comptime _PASSES = 16_384


def main() raises:
    var surface = Surface(_WIDTH, _HEIGHT)
    var first = Rgba8(UInt8(73), UInt8(41), UInt8(19), UInt8(127))
    var second = Rgba8(UInt8(17), UInt8(53), UInt8(89), UInt8(131))
    surface.clear(Rgba8(UInt8(11), UInt8(23), UInt8(37), UInt8(255)))

    for index in range(_PASSES):
        surface.blend_rect(
            0,
            0,
            _WIDTH,
            _HEIGHT,
            first if index % 2 == 0 else second,
        )
        if index % 256 == 0:
            keep(surface.pixel(index % _WIDTH, index % _HEIGHT).alpha())

    var observed = surface.pixel(_WIDTH - 1, _HEIGHT - 1)
    print("profile_surface checksum=", Int(observed.alpha()), sep="")
