"""Print a self-contained SVG containing nearest-neighbor software pixels."""

from kagerou import FillRule, PathBuilder, PixelRect, Point, Rect, Rgba8, Surface


def main() raises:
    print(
        '<svg xmlns="http://www.w3.org/2000/svg" width="960" height="300" viewBox="0 0'
        ' 960 300">'
    )
    print(
        '<rect width="960" height="300" fill="#f6f7fa"/><g font-family="sans-serif"'
        ' fill="#14263c">'
    )
    print(
        '<text x="20" y="27" font-size="18">Kagerou: regular-grid coverage, identical'
        " 32 x 32 software surfaces</text>"
    )
    for index in range(4):
        var quality = 1 << index
        var surface = Surface(32, 32)
        surface.clear(Rgba8(245, 247, 251, 255))
        var diagonal = PathBuilder()
        diagonal.move_to(Point(1.2, 1.6))
        diagonal.line_to(Point(28.7, 6.3))
        diagonal.line_to(Point(2.6, 13.8))
        surface.fill_path(
            diagonal^.finish(),
            Rgba8(28, 76, 133, 255),
            tolerance=0.01,
            samples_per_axis=quality,
        )
        var rings = PathBuilder()
        rings.add_circle(Point(16.2, 21.3), 8.1)
        rings.add_circle(Point(16.2, 21.3), 5.8)
        surface.blend_path_clipped(
            rings^.finish(),
            PixelRect(2, 2, 26, 27),
            Rgba8(128, 49, 21, 160),
            FillRule.EVEN_ODD,
            0.01,
            quality,
        )
        var tiny = PathBuilder.circle(Point(4.3, 23.6), 0.65)
        surface.fill_path(
            tiny, Rgba8(28, 76, 133, 255), tolerance=0.005, samples_per_axis=quality
        )
        var left = 20 + index * 238
        print(
            '<text x="',
            left,
            '" y="56" font-size="15">',
            quality,
            " x ",
            quality,
            " samples per pixel</text>",
            sep="",
        )
        print('<g shape-rendering="crispEdges">')
        for y in range(32):
            for x in range(32):
                var pixel = surface.pixel(x, y)
                print(
                    '<rect x="',
                    left + x * 6,
                    '" y="',
                    68 + y * 6,
                    '" width="6" height="6" fill="rgb(',
                    Int(pixel.red()),
                    ",",
                    Int(pixel.green()),
                    ",",
                    Int(pixel.blue()),
                    ')"/>',
                    sep="",
                )
        print("</g>")
    print(
        '<text x="20" y="287" font-size="13">Diagonal, even-odd ring with a rectangular'
        " clip, and a subpixel circle. Flatten tolerance: 0.01 / 0.005"
        " px.</text></g></svg>"
    )
