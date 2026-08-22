from kagerou import (
    FillRule,
    PathBuilder,
    PixelRect,
    Point,
    Rect,
    Rgba8,
    Surface,
)
from std.testing import TestSuite, assert_raises, assert_true


def _assert_pixel(
    pixel: Rgba8,
    red: Int,
    green: Int,
    blue: Int,
    alpha: Int,
) raises:
    assert_true(Int(pixel.red()) == red)
    assert_true(Int(pixel.green()) == green)
    assert_true(Int(pixel.blue()) == blue)
    assert_true(Int(pixel.alpha()) == alpha)


def _pattern(index: Int, salt: Int = 0) raises -> Rgba8:
    var alpha = (index * 37 + salt * 29) % 256
    return Rgba8(
        UInt8((alpha * ((index * 17 + 31) % 256)) // 255),
        UInt8((alpha * ((index * 43 + 7) % 256)) // 255),
        UInt8((alpha * ((index * 71 + 19) % 256)) // 255),
        UInt8(alpha),
    )


def _seed_pair(mut optimized: Surface, mut reference: Surface) raises:
    for y in range(optimized.height()):
        for x in range(optimized.width()):
            var pixel = _pattern(y * optimized.width() + x, 3)
            optimized.set_pixel(x, y, pixel)
            reference.set_pixel(x, y, pixel)


def _assert_surfaces_equal(left: Surface, right: Surface) raises:
    assert_true(left.width() == right.width())
    assert_true(left.height() == right.height())
    for y in range(left.height()):
        for x in range(left.width()):
            assert_true(left.pixel(x, y) == right.pixel(x, y))


def test_rgba8_requires_and_exposes_premultiplied_channels() raises:
    var color = Rgba8(UInt8(64), UInt8(32), UInt8(16), UInt8(128))
    _assert_pixel(color, 64, 32, 16, 128)
    assert_true(color == Rgba8(UInt8(64), UInt8(32), UInt8(16), UInt8(128)))
    assert_true(color != Rgba8(UInt8(63), UInt8(32), UInt8(16), UInt8(128)))
    assert_true(String(color) == "Rgba8(64, 32, 16, 128)")

    with assert_raises(
        contains="red channel 129 must not exceed alpha 128 in premultiplied RGBA8"
    ):
        _ = Rgba8(UInt8(129), UInt8(0), UInt8(0), UInt8(128))
    with assert_raises(
        contains="green channel 2 must not exceed alpha 1 in premultiplied RGBA8"
    ):
        _ = Rgba8(UInt8(0), UInt8(2), UInt8(0), UInt8(1))
    with assert_raises(
        contains="blue channel 255 must not exceed alpha 254 in premultiplied RGBA8"
    ):
        _ = Rgba8(UInt8(0), UInt8(0), UInt8(255), UInt8(254))


def test_surface_dimensions_stride_and_pixel_access() raises:
    var surface = Surface(2, 2, 12)
    assert_true(surface.width() == 2)
    assert_true(surface.height() == 2)
    assert_true(surface.stride() == 12)
    _assert_pixel(surface.pixel(0, 0), 0, 0, 0, 0)

    var pixel = Rgba8(UInt8(7), UInt8(8), UInt8(9), UInt8(10))
    surface.set_pixel(1, 1, pixel)
    assert_true(surface.pixel(1, 1) == pixel)
    _assert_pixel(surface.pixel(0, 1), 0, 0, 0, 0)

    with assert_raises(contains="surface x coordinate must be within [0, 2); got -1"):
        _ = surface.pixel(-1, 0)
    with assert_raises(contains="surface x coordinate must be within [0, 2); got 2"):
        surface.set_pixel(2, 0, pixel)
    with assert_raises(contains="surface y coordinate must be within [0, 2); got 2"):
        _ = surface.pixel(0, 2)


def test_surface_read_only_bytes_include_padding_and_report_visible_row_bytes() raises:
    var surface = Surface(2, 1, 10)
    surface.set_pixel(0, 0, Rgba8(UInt8(1), UInt8(2), UInt8(3), UInt8(4)))
    surface.set_pixel(1, 0, Rgba8(UInt8(5), UInt8(6), UInt8(7), UInt8(8)))
    surface._pixels[8] = UInt8(0xA5)
    surface._pixels[9] = UInt8(0x5A)

    assert_true(surface.row_bytes() == 8)
    var storage = surface.bytes()
    assert_true(len(storage) == 10)
    var expected = [1, 2, 3, 4, 5, 6, 7, 8, 0xA5, 0x5A]
    for index in range(len(expected)):
        assert_true(storage[index] == UInt8(expected[index]))


def test_surface_rejects_invalid_dimensions_stride_and_overflow() raises:
    with assert_raises(contains="surface width must be nonnegative; got -1"):
        _ = Surface(-1, 1)
    with assert_raises(contains="surface height must be nonnegative; got -1"):
        _ = Surface(1, -1)
    with assert_raises(contains="surface stride must be nonnegative; got -1"):
        _ = Surface(1, 1, -1)
    with assert_raises(
        contains="surface stride must be at least width * 4 bytes (8); got 7"
    ):
        _ = Surface(2, 1, 7)
    with assert_raises(
        contains="surface row byte count overflows Int for width 9223372036854775807"
    ):
        _ = Surface(Int.MAX, 0)
    with assert_raises(
        contains="surface storage byte count overflows Int for stride 4 and height"
    ):
        _ = Surface(1, Int.MAX, 4)


def test_empty_surfaces_have_explicit_noop_fill_and_blend_behavior() raises:
    var transparent = Rgba8(UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    var color = Rgba8(UInt8(3), UInt8(2), UInt8(1), UInt8(4))
    var zero_width = Surface(0, 3)
    zero_width.clear(color)
    zero_width.fill_span(Int.MIN, 0, Int.MAX, color)
    zero_width.fill_rect(Int.MIN, Int.MIN, Int.MAX, Int.MAX, color)
    zero_width.blend_span(Int.MIN, 0, Int.MAX, transparent)
    zero_width.blend_rect(Int.MIN, Int.MIN, Int.MAX, Int.MAX, transparent)

    var zero_height = Surface(3, 0)
    zero_height.clear(color)
    zero_height.fill_rect(0, 0, 3, 1, color)
    zero_height.blend_rect(0, 0, 3, 1, color)

    # Empty width means no storage and no row walk, even at the largest height.
    var tall_empty = Surface(0, Int.MAX)
    tall_empty.validate()
    tall_empty.clear(color)
    tall_empty.fill_rect(0, 0, Int.MAX, Int.MAX, color)
    tall_empty.blend_rect(0, 0, Int.MAX, Int.MAX, color)

    with assert_raises(contains="surface x coordinate must be within [0, 0); got 0"):
        _ = zero_width.pixel(0, 0)
    with assert_raises(contains="surface y coordinate must be within [0, 0); got 0"):
        _ = zero_height.pixel(0, 0)


def test_clear_and_solid_fill_clip_without_touching_other_pixels() raises:
    var surface = Surface(6, 4, 32)
    var background = Rgba8(UInt8(5), UInt8(10), UInt8(15), UInt8(20))
    var foreground = Rgba8(UInt8(30), UInt8(20), UInt8(10), UInt8(40))
    surface.clear(background)
    surface.fill_span(-2, 1, 5, foreground)
    surface.fill_rect(4, -1, 4, 3, foreground)

    for y in range(4):
        for x in range(6):
            var filled = (y == 1 and x < 3) or (y < 2 and x >= 4)
            assert_true(surface.pixel(x, y) == (foreground if filled else background))

    surface.fill_span(Int.MIN, 2, Int.MAX, foreground)
    surface.fill_rect(Int.MAX, Int.MAX, Int.MAX, Int.MAX, foreground)
    with assert_raises(contains="fill span length must be nonnegative; got -1"):
        surface.fill_span(0, 0, -1, foreground)
    with assert_raises(contains="fill rect width must be nonnegative; got -1"):
        surface.fill_rect(0, 0, -1, 1, foreground)
    with assert_raises(contains="fill rect height must be nonnegative; got -1"):
        surface.fill_rect(0, 0, 1, -1, foreground)


def test_source_over_alpha_edges_and_reference_value() raises:
    var destination = Rgba8(UInt8(10), UInt8(20), UInt8(30), UInt8(40))
    var transparent = Rgba8(UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    var opaque = Rgba8(UInt8(200), UInt8(100), UInt8(50), UInt8(255))
    var half = Rgba8(UInt8(64), UInt8(32), UInt8(16), UInt8(128))
    var surface = Surface(3, 1)
    surface.clear(destination)

    surface.blend_span(0, 0, 1, transparent)
    surface.blend_span(1, 0, 1, opaque)
    surface.blend_span(2, 0, 1, half)
    assert_true(surface.pixel(0, 0) == destination)
    assert_true(surface.pixel(1, 0) == opaque)
    _assert_pixel(surface.pixel(2, 0), 69, 42, 31, 148)

    var empty_destination = Surface(1, 1)
    empty_destination.blend_span(0, 0, 1, half)
    assert_true(empty_destination.pixel(0, 0) == half)


def test_simd_span_batches_and_scalar_tails_are_exactly_differential() raises:
    var alphas = [0, 1, 2, 63, 127, 128, 129, 254, 255]
    for length in range(20):
        for alpha in alphas:
            var source = Rgba8(
                UInt8(alpha // 2),
                UInt8(alpha // 3),
                UInt8(alpha // 5),
                UInt8(alpha),
            )
            var optimized = Surface(length + 4, 1, (length + 5) * 4)
            var reference = Surface(length + 4, 1, (length + 5) * 4)
            _seed_pair(optimized, reference)
            optimized.blend_span(1, 0, length, source)
            reference._blend_span_scalar(1, 0, length, source)
            _assert_surfaces_equal(optimized, reference)


def test_simd_rect_batches_match_scalar_reference_under_clipping() raises:
    var origins = [-9, -2, 0, 3, 8, Int.MAX]
    var source = Rgba8(UInt8(77), UInt8(31), UInt8(9), UInt8(143))
    for x in origins:
        for y in origins:
            # The 41-byte stride deliberately misaligns every row after the
            # first, exercising the SIMD kernel's explicit byte alignment.
            var optimized = Surface(9, 7, 41)
            var reference = Surface(9, 7, 41)
            _seed_pair(optimized, reference)
            optimized.blend_rect(x, y, 11, 9, source)
            reference._blend_rect_scalar(x, y, 11, 9, source)
            _assert_surfaces_equal(optimized, reference)

    var surface = Surface(1, 1)
    with assert_raises(contains="blend span length must be nonnegative; got -1"):
        surface.blend_span(0, 0, -1, source)
    with assert_raises(contains="blend rect width must be nonnegative; got -1"):
        surface.blend_rect(0, 0, -1, 1, source)
    with assert_raises(contains="blend rect height must be nonnegative; got -1"):
        surface.blend_rect(0, 0, 1, -1, source)


def test_vector_batches_and_scalar_tails_preserve_row_padding_sentinels() raises:
    var surface = Surface(5, 3, 23)
    var background = Rgba8(UInt8(9), UInt8(7), UInt8(5), UInt8(11))
    var source = Rgba8(UInt8(41), UInt8(23), UInt8(7), UInt8(99))
    surface.clear(background)
    for y in range(surface.height()):
        for byte in range(surface.row_bytes(), surface.stride()):
            surface._pixels[y * surface.stride() + byte] = UInt8(0xA5)

    # Exact four-pixel vectors at both the row origin and visible row end, plus
    # a five-pixel rectangle that exercises a scalar tail.
    surface.blend_span(0, 0, 4, source)
    surface.blend_span(1, 1, 4, source)
    surface.blend_rect(0, 2, 5, 1, source)

    var storage = surface.bytes()
    for y in range(surface.height()):
        for byte in range(surface.row_bytes(), surface.stride()):
            assert_true(storage[y * surface.stride() + byte] == UInt8(0xA5))


def test_surface_validate_detects_out_of_contract_storage_mutation() raises:
    var surface = Surface(2, 2)
    surface._stride = 3
    with assert_raises(
        contains="surface stride must be at least width * 4 bytes (8); got 3"
    ):
        surface.validate()

    var invalid_pixel = Surface(1, 1)
    invalid_pixel._pixels[0] = UInt8(1)
    with assert_raises(
        contains=(
            "surface pixel at (0, 0) has red channel 1 greater than alpha 0; "
            "restore premultiplied RGBA8 bytes"
        )
    ):
        invalid_pixel.validate()

    var color = Rgba8(UInt8(1), UInt8(2), UInt8(3), UInt8(4))
    color._blue = UInt8(5)
    with assert_raises(
        contains="blue channel 5 must not exceed alpha 4 in premultiplied RGBA8"
    ):
        color.validate()


def test_surface_equality_includes_layout_and_owned_bytes() raises:
    var color = Rgba8(UInt8(7), UInt8(5), UInt8(3), UInt8(9))
    var left = Surface(2, 2)
    var right = Surface(2, 2)
    assert_true(left == right)
    right.set_pixel(1, 1, color)
    assert_true(left != right)
    left.set_pixel(1, 1, color)
    assert_true(left == right)
    assert_true(left != Surface(2, 2, 12))


def test_pixel_rect_validates_extents_and_clips_path_writes() raises:
    var path = PathBuilder.rectangle(Rect(0.0, 0.0, 6.0, 5.0))
    var color = Rgba8(UInt8(31), UInt8(17), UInt8(9), UInt8(63))
    var surface = Surface(6, 5)
    var clip = PixelRect(2, 1, 2, 3)
    assert_true(clip.x() == 2)
    assert_true(clip.y() == 1)
    assert_true(clip.width() == 2)
    assert_true(clip.height() == 3)
    assert_true(clip == PixelRect(2, 1, 2, 3))
    assert_true(String(clip) == "PixelRect(2, 1, 2, 3)")
    surface.fill_path_clipped(path, clip, color)

    for y in range(5):
        for x in range(6):
            var expected = x >= 2 and x < 4 and y >= 1 and y < 4
            assert_true(
                surface.pixel(x, y) == (color if expected else Rgba8(0, 0, 0, 0))
            )

    with assert_raises(contains="pixel rect width must be nonnegative; got -1"):
        _ = PixelRect(0, 0, -1, 1)
    with assert_raises(contains="pixel rect height must be nonnegative; got -1"):
        _ = PixelRect(0, 0, 1, -1)


def test_path_fill_uses_documented_pixel_center_and_top_left_edges() raises:
    # Centers on the minimum/top edges are included; centers on maximum/bottom
    # edges are excluded. The fractional bounds make every case exact.
    var path = PathBuilder.rectangle(Rect(0.5, 0.5, 3.5, 2.5))
    var color = Rgba8(UInt8(7), UInt8(5), UInt8(3), UInt8(9))
    var surface = Surface(5, 4)
    surface.fill_path(path, color)
    for y in range(4):
        for x in range(5):
            var expected = x < 3 and y < 2
            assert_true(
                surface.pixel(x, y) == (color if expected else Rgba8(0, 0, 0, 0))
            )


def test_open_concave_subpath_is_implicitly_closed() raises:
    var builder = PathBuilder()
    builder.move_to(Point(1.0, 1.0))
    builder.line_to(Point(6.0, 1.0))
    builder.line_to(Point(6.0, 3.0))
    builder.line_to(Point(3.0, 3.0))
    builder.line_to(Point(3.0, 6.0))
    builder.line_to(Point(1.0, 6.0))
    var path = builder^.finish()
    var color = Rgba8(UInt8(20), UInt8(10), UInt8(5), UInt8(40))
    var surface = Surface(8, 8)
    surface.fill_path(path, color)

    assert_true(surface.pixel(1, 1) == color)
    assert_true(surface.pixel(5, 2) == color)
    assert_true(surface.pixel(2, 5) == color)
    assert_true(surface.pixel(4, 4) != color)
    assert_true(surface.pixel(0, 0) != color)


def test_even_odd_and_nonzero_fill_rules_differ_for_nested_same_winding() raises:
    var builder = PathBuilder()
    builder.add_rect(Rect(1.0, 1.0, 8.0, 8.0))
    builder.add_rect(Rect(3.0, 3.0, 6.0, 6.0))
    var path = builder^.finish()
    var color = Rgba8(UInt8(60), UInt8(30), UInt8(15), UInt8(120))
    var nonzero = Surface(9, 9)
    var even_odd = Surface(9, 9)
    nonzero.fill_path(path, color, FillRule.NONZERO)
    even_odd.fill_path(path, color, FillRule.EVEN_ODD)

    for y in range(9):
        for x in range(9):
            var in_outer = x >= 1 and x < 8 and y >= 1 and y < 8
            var in_inner = x >= 3 and x < 6 and y >= 3 and y < 6
            assert_true(
                nonzero.pixel(x, y) == (color if in_outer else Rgba8(0, 0, 0, 0))
            )
            assert_true(
                even_odd.pixel(x, y)
                == (color if in_outer and not in_inner else Rgba8(0, 0, 0, 0))
            )


def test_opposite_winding_nested_paths_have_explicit_hole_masks() raises:
    var builder = PathBuilder()
    builder.add_rect(Rect(1.0, 1.0, 8.0, 8.0))
    builder.move_to(Point(3.0, 3.0))
    builder.line_to(Point(3.0, 6.0))
    builder.line_to(Point(6.0, 6.0))
    builder.line_to(Point(6.0, 3.0))
    builder.close()
    var path = builder^.finish()
    var color = Rgba8(UInt8(51), UInt8(27), UInt8(13), UInt8(101))
    var nonzero = Surface(9, 9)
    var even_odd = Surface(9, 9)
    nonzero.fill_path(path, color, FillRule.NONZERO)
    even_odd.fill_path(path, color, FillRule.EVEN_ODD)

    for y in range(9):
        for x in range(9):
            var expected = (
                x >= 1
                and x < 8
                and y >= 1
                and y < 8
                and not (x >= 3 and x < 6 and y >= 3 and y < 6)
            )
            var expected_pixel = color if expected else Rgba8(0, 0, 0, 0)
            assert_true(nonzero.pixel(x, y) == expected_pixel)
            assert_true(even_odd.pixel(x, y) == expected_pixel)


def test_curved_clipped_blend_matches_scalar_oracle_exactly() raises:
    var path = PathBuilder.circle(Point(7.25, 5.75), 5.5)
    var clip = PixelRect(-3, 2, 14, 8)
    var source = Rgba8(UInt8(77), UInt8(31), UInt8(9), UInt8(143))
    var optimized = Surface(17, 13, 73)
    var reference = Surface(17, 13, 73)
    _seed_pair(optimized, reference)
    optimized.blend_path_clipped(path, clip, source, FillRule.NONZERO, tolerance=0.125)
    reference._blend_path_scalar(path, clip, source, FillRule.NONZERO, tolerance=0.125)
    _assert_surfaces_equal(optimized, reference)


def test_fill_rasterizer_matches_scalar_oracle_for_rules_clips_and_tails() raises:
    var builder = PathBuilder()
    builder.move_to(Point(-2.25, 1.5))
    builder.line_to(Point(15.75, -1.25))
    builder.line_to(Point(12.5, 10.75))
    builder.line_to(Point(6.5, 6.5))
    builder.line_to(Point(-1.5, 12.25))
    builder.close()
    builder.add_rect(Rect(3.5, 3.5, 9.5, 8.5))
    var path = builder^.finish()
    var color = Rgba8(UInt8(43), UInt8(29), UInt8(11), UInt8(91))
    var clips = [
        PixelRect(0, 0, 17, 13),
        PixelRect(-9, -7, 14, 12),
        PixelRect(4, 2, 9, 7),
        PixelRect(Int.MIN, Int.MIN, Int.MAX, Int.MAX),
        PixelRect(Int.MAX, Int.MAX, Int.MAX, Int.MAX),
    ]
    var rules = [FillRule.NONZERO, FillRule.EVEN_ODD]
    for clip in clips:
        for rule in rules:
            var optimized = Surface(17, 13, 73)
            var reference = Surface(17, 13, 73)
            optimized.fill_path_clipped(path, clip, color, rule)
            reference._fill_path_scalar(path, clip, color, rule)
            _assert_surfaces_equal(optimized, reference)


def test_empty_or_fully_clipped_paths_are_noops() raises:
    var empty = PathBuilder().finish()
    var surface = Surface(3, 2)
    var color = Rgba8(UInt8(3), UInt8(2), UInt8(1), UInt8(4))
    surface.fill_path(empty, color)
    surface.blend_path_clipped(
        empty,
        PixelRect(Int.MAX, Int.MAX, Int.MAX, Int.MAX),
        color,
    )
    assert_true(surface == Surface(3, 2))


def test_noop_path_calls_still_validate_tolerance_before_early_return() raises:
    var path = PathBuilder.circle(Point(1.0, 1.0), 1.0)
    var transparent = Rgba8(UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    var surface = Surface(3, 3)
    with assert_raises(contains="flatten tolerance must be a positive finite"):
        surface.fill_path_clipped(
            path,
            PixelRect(0, 0, 0, 0),
            transparent,
            tolerance=0.0,
        )
    with assert_raises(contains="flatten tolerance must be a positive finite"):
        surface.blend_path(path, transparent, tolerance=0.0)


def test_extreme_finite_edges_do_not_overflow_crossing_interpolation() raises:
    var extent = Float64.MAX_FINITE
    var builder = PathBuilder()
    builder.move_to(Point(0.0, -extent))
    builder.line_to(Point(extent, 0.0))
    builder.line_to(Point(0.0, extent))
    builder.line_to(Point(-extent, 0.0))
    builder.close()
    var surface = Surface(3, 3)
    var color = Rgba8(UInt8(11), UInt8(7), UInt8(3), UInt8(15))
    surface.fill_path(builder^.finish(), color)
    assert_true(surface.pixel(1, 1) == color)


def test_extreme_diagonal_preserves_local_pixel_center_residual() raises:
    var extent = Float64.MAX_FINITE
    var color = Rgba8(UInt8(17), UInt8(11), UInt8(5), UInt8(31))

    # The huge diagonal is exactly x = y. As a left boundary it includes
    # centers on x == y and fills the upper-right half-plane.
    var right_builder = PathBuilder()
    right_builder.move_to(Point(-extent, -extent))
    right_builder.line_to(Point(extent, extent))
    right_builder.line_to(Point(extent, -extent))
    right_builder.close()
    var right = Surface(5, 5)
    right.fill_path(right_builder^.finish(), color)
    for y in range(5):
        for x in range(5):
            assert_true(right.pixel(x, y) == (color if x >= y else Rgba8(0, 0, 0, 0)))

    # Reversing the finite half-plane makes x = y the right boundary, so its
    # half-open interval excludes centers on the diagonal.
    var left_builder = PathBuilder()
    left_builder.move_to(Point(-extent, -extent))
    left_builder.line_to(Point(-extent, extent))
    left_builder.line_to(Point(extent, extent))
    left_builder.close()
    var left = Surface(5, 5)
    left.fill_path(left_builder^.finish(), color)
    for y in range(5):
        for x in range(5):
            assert_true(left.pixel(x, y) == (color if x < y else Rgba8(0, 0, 0, 0)))


def test_asymmetric_extreme_edge_preserves_local_apex_residual() raises:
    var extent = Float64.MAX_FINITE
    var builder = PathBuilder()
    builder.move_to(Point(-extent, -extent))
    builder.line_to(Point(10.0, 1.0))
    builder.line_to(Point(extent, -extent))
    builder.close()

    # At y = 0.5 the exact finite-endpoint crossings are immediately below
    # x = 9.5 and x = 10.5. Therefore only the center of pixel 9 is covered.
    # This explicit mask is independent of the shared scalar edge evaluator.
    var color = Rgba8(UInt8(19), UInt8(13), UInt8(7), UInt8(37))
    var surface = Surface(12, 1)
    surface.fill_path(builder^.finish(), color)
    for x in range(surface.width()):
        assert_true(surface.pixel(x, 0) == (color if x == 9 else Rgba8(0, 0, 0, 0)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
