"""Render a clipped source-over circle into an owned software surface."""

from kagerou import PixelRect, PathBuilder, Point, Rgba8, Surface


def main() raises:
    var surface = Surface(200, 160)
    var circle = PathBuilder.circle(Point(100.0, 80.0), 48.0)
    var blue = Rgba8(UInt8(16), UInt8(48), UInt8(96), UInt8(128))
    surface.blend_path_clipped(
        circle,
        PixelRect(60, 30, 80, 100),
        blue,
    )
    print(surface.pixel(100, 80))
