"""Owned premultiplied RGBA8 software surfaces and solid compositing."""

from std.builtin.comparable import Equatable
from std.collections import List
from std.io import Writable, Writer
from std.math import abs, ceil, fma

from .geometry import _is_finite
from .path import DEFAULT_FLATTEN_TOLERANCE, FillRule, Path, PathVerb


comptime _CHANNELS_PER_PIXEL = 4
comptime _SIMD_CHANNELS = 16
comptime _SIMD_PIXELS = _SIMD_CHANNELS // _CHANNELS_PER_PIXEL
comptime _SAFE_INTERPOLATION_MAGNITUDE = 1.0e150
comptime _ORDINARY_INTERPOLATION = 0
comptime _RESIDUAL_INTERPOLATION = 1
comptime _NORMALIZED_INTERPOLATION = 2


struct _ValidatedPixel:
    def __init__(out self):
        pass


def _validate_premultiplied_channel(
    channel: UInt8,
    alpha: UInt8,
    name: StringLiteral,
) raises:
    if channel > alpha:
        raise Error(
            String(
                name,
                " channel ",
                channel,
                " must not exceed alpha ",
                alpha,
                " in premultiplied RGBA8; premultiply straight-alpha colors ",
                "before constructing Rgba8",
            )
        )


struct Rgba8(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """One premultiplied RGBA pixel with four unsigned 8-bit channels.

    Construction requires every color channel to be no greater than alpha.
    Public operations trust that invariant thereafter. Direct mutation of
    underscore-prefixed storage is out of contract; ``validate`` provides an
    explicit checkpoint after unusual low-level mutation.
    """

    var _red: UInt8
    var _green: UInt8
    var _blue: UInt8
    var _alpha: UInt8

    def __init__(
        out self,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
    ) raises:
        _validate_premultiplied_channel(red, alpha, "red")
        _validate_premultiplied_channel(green, alpha, "green")
        _validate_premultiplied_channel(blue, alpha, "blue")
        self._red = red
        self._green = green
        self._blue = blue
        self._alpha = alpha

    def __init__(
        out self,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
        *,
        _validated: _ValidatedPixel,
    ):
        self._red = red
        self._green = green
        self._blue = blue
        self._alpha = alpha

    @staticmethod
    def _from_validated(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
    ) -> Self:
        return Self(red, green, blue, alpha, _validated=_ValidatedPixel())

    def validate(self) raises:
        """Revalidate the stored premultiplication invariant explicitly."""
        _validate_premultiplied_channel(self._red, self._alpha, "red")
        _validate_premultiplied_channel(self._green, self._alpha, "green")
        _validate_premultiplied_channel(self._blue, self._alpha, "blue")

    def red(self) -> UInt8:
        return self._red

    def green(self) -> UInt8:
        return self._green

    def blue(self) -> UInt8:
        return self._blue

    def alpha(self) -> UInt8:
        return self._alpha

    def __eq__(self, other: Self) -> Bool:
        return (
            self._red == other._red
            and self._green == other._green
            and self._blue == other._blue
            and self._alpha == other._alpha
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Rgba8(",
            self._red,
            ", ",
            self._green,
            ", ",
            self._blue,
            ", ",
            self._alpha,
            ")",
        )


struct _ClippedInterval(Copyable, ImplicitlyCopyable):
    var start: Int
    var length: Int

    def __init__(out self, start: Int, length: Int):
        self.start = start
        self.length = length


struct PixelRect(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """A signed-origin, nonnegative-extent rectangle in integer pixels.

    End coordinates are intentionally not stored or exposed: clipping compares
    the origin and extent before addition, so even ``Int.MIN``/``Int.MAX``
    inputs cannot overflow.
    """

    var _x: Int
    var _y: Int
    var _width: Int
    var _height: Int

    def __init__(out self, x: Int, y: Int, width: Int, height: Int) raises:
        _validate_extent(width, "pixel rect", "width")
        _validate_extent(height, "pixel rect", "height")
        self._x = x
        self._y = y
        self._width = width
        self._height = height

    def x(self) -> Int:
        return self._x

    def y(self) -> Int:
        return self._y

    def width(self) -> Int:
        return self._width

    def height(self) -> Int:
        return self._height

    def __eq__(self, other: Self) -> Bool:
        return (
            self._x == other._x
            and self._y == other._y
            and self._width == other._width
            and self._height == other._height
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "PixelRect(",
            self._x,
            ", ",
            self._y,
            ", ",
            self._width,
            ", ",
            self._height,
            ")",
        )


struct _Edge(Copyable, ImplicitlyCopyable):
    var x0: Float64
    var y0: Float64
    var x1: Float64
    var y1: Float64
    var min_y: Float64
    var max_y: Float64
    var slope: Float64
    var residual0: Float64
    var residual1: Float64
    var interpolation_mode: Int
    var winding: Int

    def __init__(
        out self,
        x0: Float64,
        y0: Float64,
        x1: Float64,
        y1: Float64,
    ):
        self.x0 = x0
        self.y0 = y0
        self.x1 = x1
        self.y1 = y1
        self.min_y = min(y0, y1)
        self.max_y = max(y0, y1)
        var uses_extreme_interpolation = (
            max(abs(y0), abs(y1)) > _SAFE_INTERPOLATION_MAGNITUDE
            or max(abs(x0), abs(x1)) > _SAFE_INTERPOLATION_MAGNITUDE
        )
        self.slope = 0.0
        self.residual0 = 0.0
        self.residual1 = 0.0
        self.interpolation_mode = _ORDINARY_INTERPOLATION
        if not uses_extreme_interpolation:
            self.slope = (x1 - x0) / (y1 - y0)
        else:
            self.interpolation_mode = _NORMALIZED_INTERPOLATION
            var x_scale = max(abs(x0), abs(x1))
            var y_scale = max(abs(y0), abs(y1))
            if x_scale == 0.0:
                self.slope = 0.0
            else:
                var normalized_slope = (x1 / x_scale - x0 / x_scale) / (
                    y1 / y_scale - y0 / y_scale
                )
                if x_scale <= y_scale:
                    self.slope = normalized_slope / (y_scale / x_scale)
                else:
                    self.slope = normalized_slope * (x_scale / y_scale)
            if _is_finite(self.slope):
                # A rounded leading slope can lose a locally visible offset
                # when one endpoint is extreme and the other is ordinary. Keep
                # both endpoint residuals and interpolate them at evaluation
                # time instead of pretending either one is a global intercept.
                self.residual0 = fma(-self.slope, y0, x0)
                self.residual1 = fma(-self.slope, y1, x1)
                if _is_finite(self.residual0) and _is_finite(self.residual1):
                    self.interpolation_mode = _RESIDUAL_INTERPOLATION
        self.winding = 1 if y1 > y0 else -1


struct _Crossing(Copyable, ImplicitlyCopyable):
    var x: Float64
    var winding: Int

    def __init__(out self, x: Float64, winding: Int):
        self.x = x
        self.winding = winding


def _clip_interval(origin: Int, length: Int, bound: Int) -> _ClippedInterval:
    """Clip a validated nonnegative extent without overflowing Int."""
    if length == 0 or bound == 0:
        return _ClippedInterval(0, 0)
    if origin < 0:
        # ``length`` is nonnegative and therefore safe to negate. Comparing
        # first avoids negating Int.MIN and avoids forming origin + length when
        # the requested interval lies wholly before zero.
        if origin <= -length:
            return _ClippedInterval(0, 0)
        return _ClippedInterval(0, min(length + origin, bound))
    if origin >= bound:
        return _ClippedInterval(bound, 0)
    return _ClippedInterval(origin, min(length, bound - origin))


def _validate_extent(length: Int, operation: StringLiteral, name: StringLiteral) raises:
    if length < 0:
        raise Error(
            String(
                operation,
                " ",
                name,
                " must be nonnegative; got ",
                length,
                "; use 0 for an empty extent",
            )
        )


def _validate_raster_tolerance(tolerance: Float64) raises:
    if not _is_finite(tolerance) or tolerance <= 0.0:
        raise Error(
            String(
                "flatten tolerance must be a positive finite device-space ",
                "distance (0.25 recommended for antialiased output), got ",
                tolerance,
            )
        )


def _validate_samples(samples_per_axis: Int) raises:
    if samples_per_axis < 1 or samples_per_axis > 16:
        raise Error(
            String(
                "samples_per_axis must be within [1, 16]; got ",
                samples_per_axis,
                "; use 1 for binary coverage or 4/8/16 for antialiasing",
            )
        )


def _first_subsample(boundary: Float64, x: Int, samples: Int) -> Int:
    # Clamp in floating point before converting; off-screen finite coordinates
    # must never overflow an Int. A single pixel keeps all arithmetic bounded.
    var local = (boundary - Float64(x)) * Float64(samples) - 0.5
    if local <= 0.0:
        return 0
    if local >= Float64(samples):
        return samples
    return Int(ceil(local))


def _masked_channel(
    source: UInt8, destination: UInt8, covered: Int, total: Int
) -> UInt8:
    return UInt8(
        (Int(source) * covered + Int(destination) * (total - covered) + total // 2)
        // total
    )


def _clip_is_empty(
    clip: PixelRect,
    surface_width: Int,
    surface_height: Int,
) -> Bool:
    return (
        _clip_interval(clip._x, clip._width, surface_width).length == 0
        or _clip_interval(clip._y, clip._height, surface_height).length == 0
    )


def _checked_row_bytes(width: Int) raises -> Int:
    if width < 0:
        raise Error(
            String(
                "surface width must be nonnegative; got ",
                width,
                "; use 0 for an empty surface",
            )
        )
    if width > Int.MAX // _CHANNELS_PER_PIXEL:
        raise Error(
            String(
                "surface row byte count overflows Int for width ",
                width,
                "; use a smaller width",
            )
        )
    return width * _CHANNELS_PER_PIXEL


def _validate_layout(width: Int, height: Int, stride: Int) raises -> Int:
    var row_bytes = _checked_row_bytes(width)
    if height < 0:
        raise Error(
            String(
                "surface height must be nonnegative; got ",
                height,
                "; use 0 for an empty surface",
            )
        )
    if stride < 0:
        raise Error(
            String(
                "surface stride must be nonnegative; got ",
                stride,
                "; use at least width * 4 bytes",
            )
        )
    if stride < row_bytes:
        raise Error(
            String(
                "surface stride must be at least width * 4 bytes (",
                row_bytes,
                "); got ",
                stride,
                "; increase stride or reduce width",
            )
        )
    if height != 0 and stride > Int.MAX // height:
        raise Error(
            String(
                "surface storage byte count overflows Int for stride ",
                stride,
                " and height ",
                height,
                "; reduce height or stride",
            )
        )
    return stride * height


def _append_edge(
    mut edges: List[_Edge],
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
):
    # Horizontal edges never cross a pixel-center scanline. Omitting them is
    # also what makes shared vertices use one half-open vertical interval.
    if y0 != y1:
        edges.append(_Edge(x0, y0, x1, y1))


def _path_edges(path: Path, tolerance: Float64) raises -> List[_Edge]:
    """Flatten and implicitly close each subpath into directed edges."""
    var flattened = path.flattened(tolerance)
    var edges = List[_Edge](capacity=flattened.point_count())
    var coordinates = flattened.coordinates()
    var coordinate_index = 0
    var has_current = False
    var start_x = 0.0
    var start_y = 0.0
    var current_x = 0.0
    var current_y = 0.0

    for verb in flattened.verbs():
        if verb == PathVerb.MOVE:
            if has_current:
                _append_edge(
                    edges,
                    current_x,
                    current_y,
                    start_x,
                    start_y,
                )
            start_x = coordinates[coordinate_index]
            start_y = coordinates[coordinate_index + 1]
            coordinate_index += 2
            current_x = start_x
            current_y = start_y
            has_current = True
        elif verb == PathVerb.LINE:
            var next_x = coordinates[coordinate_index]
            var next_y = coordinates[coordinate_index + 1]
            coordinate_index += 2
            _append_edge(edges, current_x, current_y, next_x, next_y)
            current_x = next_x
            current_y = next_y
        else:
            _append_edge(edges, current_x, current_y, start_x, start_y)
            has_current = False

    if has_current:
        _append_edge(edges, current_x, current_y, start_x, start_y)
    return edges^


def _first_pixel_center_at_or_after(
    value: Float64,
    lower: Int,
    upper: Int,
) -> Int:
    """Return the first clipped integer whose center is at least ``value``."""
    if value <= Float64(lower) + 0.5:
        return lower
    if value > Float64(upper) - 0.5:
        return upper
    return Int(ceil(value - 0.5))


def _edge_crosses(edge: _Edge, sample_y: Float64) -> Bool:
    return sample_y >= edge.min_y and sample_y < edge.max_y


def _scaled_interpolate(
    value0: Float64,
    parameter0: Float64,
    value1: Float64,
    parameter1: Float64,
    sample: Float64,
) -> Float64:
    """Interpolate finite endpoints without overflowing endpoint differences."""
    var parameter_scale = max(abs(parameter0), abs(parameter1), abs(sample))
    if parameter_scale == 0.0:
        return value0

    var normalized0 = parameter0 / parameter_scale
    var normalized1 = parameter1 / parameter_scale
    var normalized_sample = sample / parameter_scale
    var distance0 = normalized_sample - normalized0
    var distance1 = normalized_sample - normalized1
    var denominator = normalized1 - normalized0
    if denominator == 0.0:
        # Adjacent same-sign extreme parameters can round to the same scaled
        # value. Their direct difference is then small and cannot overflow.
        distance0 = sample - parameter0
        distance1 = sample - parameter1
        denominator = parameter1 - parameter0

    # Interpolate outward from the closer endpoint. The fraction is at most one
    # half for an in-segment sample, so multiplying it by the value scale cannot
    # overflow. Scaling the value delta avoids forming value1 - value0.
    var base = value0
    var other = value1
    var fraction = distance0 / denominator
    if abs(distance1) < abs(distance0):
        base = value1
        other = value0
        fraction = distance1 / -denominator
    fraction = max(0.0, min(1.0, fraction))

    var value_scale = max(abs(base), abs(other))
    if value_scale == 0.0:
        return 0.0
    var normalized_delta = other / value_scale - base / value_scale
    return fma(fraction * value_scale, normalized_delta, base)


def _edge_crossing_x(edge: _Edge, sample_y: Float64) -> Float64:
    if edge.interpolation_mode == _ORDINARY_INTERPOLATION:
        return fma(sample_y - edge.y0, edge.slope, edge.x0)
    if edge.interpolation_mode == _RESIDUAL_INTERPOLATION:
        var residual = _scaled_interpolate(
            edge.residual0,
            edge.y0,
            edge.residual1,
            edge.y1,
            sample_y,
        )
        return fma(sample_y, edge.slope, residual)

    return _scaled_interpolate(
        edge.x0,
        edge.y0,
        edge.x1,
        edge.y1,
        sample_y,
    )


def _sort_crossings(mut crossings: List[_Crossing]):
    """Stable insertion sort; typical path scanlines have few crossings."""
    for index in range(1, len(crossings)):
        var value = crossings[index]
        var destination = index
        while destination > 0 and value.x < crossings[destination - 1].x:
            crossings[destination] = crossings[destination - 1]
            destination -= 1
        crossings[destination] = value


def _is_inside(winding: Int, fill_rule: FillRule) -> Bool:
    if fill_rule == FillRule.EVEN_ODD:
        return winding % 2 != 0
    return winding != 0


def _source_over_channel(
    source: UInt8, destination: UInt8, inverse_alpha: UInt16
) -> UInt8:
    # The largest division intermediate is 65,407, which fits UInt16. Valid
    # premultiplied inputs also prove source + contribution is at most 255.
    var product = destination.cast[DType.uint16]() * inverse_alpha
    var biased = product + UInt16(128)
    var contribution = (biased + (biased >> 8)).cast[DType.uint16]() >> 8
    return (source.cast[DType.uint16]() + contribution).cast[DType.uint8]()


struct Surface(Equatable):
    """An owned, row-major premultiplied RGBA8 software surface.

    ``stride`` is measured in bytes and may include row padding. Construction
    validates dimensions, row size, total-size overflow, and exact owned storage
    length. Pixel access is checked. Solid fill and source-over operations clip
    signed origins and extents to the surface without forming overflowing end
    coordinates.

    Public operations trust constructor-established layout invariants. Direct
    mutation of underscore-prefixed storage is out of contract; ``validate``
    provides an explicit checkpoint after unusual low-level mutation.
    """

    var _width: Int
    var _height: Int
    var _stride: Int
    var _pixels: List[UInt8]

    def __init__(out self, width: Int, height: Int) raises:
        var stride = _checked_row_bytes(width)
        var byte_count = _validate_layout(width, height, stride)
        self._width = width
        self._height = height
        self._stride = stride
        self._pixels = List[UInt8](length=byte_count, fill=UInt8(0))

    def __init__(out self, width: Int, height: Int, stride: Int) raises:
        var byte_count = _validate_layout(width, height, stride)
        self._width = width
        self._height = height
        self._stride = stride
        self._pixels = List[UInt8](length=byte_count, fill=UInt8(0))

    def validate(self) raises:
        """Revalidate layout, storage length, and every visible pixel."""
        var expected = _validate_layout(self._width, self._height, self._stride)
        if len(self._pixels) != expected:
            raise Error(
                String(
                    "surface owned storage length must equal stride * height (",
                    expected,
                    "); got ",
                    len(self._pixels),
                    "; reconstruct the surface with matching storage",
                )
            )
        if self._width == 0 or self._height == 0:
            return
        for y in range(self._height):
            for x in range(self._width):
                var offset = self._offset(x, y)
                var alpha = self._pixels[offset + 3]
                if self._pixels[offset] > alpha:
                    self._raise_invalid_pixel_channel(
                        x, y, "red", self._pixels[offset], alpha
                    )
                if self._pixels[offset + 1] > alpha:
                    self._raise_invalid_pixel_channel(
                        x, y, "green", self._pixels[offset + 1], alpha
                    )
                if self._pixels[offset + 2] > alpha:
                    self._raise_invalid_pixel_channel(
                        x, y, "blue", self._pixels[offset + 2], alpha
                    )

    def _raise_invalid_pixel_channel(
        self,
        x: Int,
        y: Int,
        name: StringLiteral,
        channel: UInt8,
        alpha: UInt8,
    ) raises:
        raise Error(
            String(
                "surface pixel at (",
                x,
                ", ",
                y,
                ") has ",
                name,
                " channel ",
                channel,
                " greater than alpha ",
                alpha,
                "; restore premultiplied RGBA8 bytes or reconstruct the surface",
            )
        )

    def width(self) -> Int:
        return self._width

    def height(self) -> Int:
        return self._height

    def stride(self) -> Int:
        """Return the number of bytes between adjacent row starts."""
        return self._stride

    def row_bytes(self) -> Int:
        """Return visible RGBA bytes per row, excluding stride padding."""
        return self._width * _CHANNELS_PER_PIXEL

    def bytes(self) -> Span[UInt8, origin_of(self._pixels)]:
        """Borrow all owned bytes read-only, including stride padding."""
        return Span(self._pixels)

    def _check_coordinates(self, x: Int, y: Int) raises:
        if x < 0 or x >= self._width:
            raise Error(
                String(
                    "surface x coordinate must be within [0, ",
                    self._width,
                    "); got ",
                    x,
                    "; clip the coordinate before pixel access",
                )
            )
        if y < 0 or y >= self._height:
            raise Error(
                String(
                    "surface y coordinate must be within [0, ",
                    self._height,
                    "); got ",
                    y,
                    "; clip the coordinate before pixel access",
                )
            )

    def _offset(self, x: Int, y: Int) -> Int:
        return y * self._stride + x * _CHANNELS_PER_PIXEL

    def pixel(self, x: Int, y: Int) raises -> Rgba8:
        """Return one checked pixel."""
        self._check_coordinates(x, y)
        var offset = self._offset(x, y)
        return Rgba8._from_validated(
            self._pixels[offset],
            self._pixels[offset + 1],
            self._pixels[offset + 2],
            self._pixels[offset + 3],
        )

    def set_pixel(mut self, x: Int, y: Int, pixel: Rgba8) raises:
        """Overwrite one checked pixel."""
        self._check_coordinates(x, y)
        var offset = self._offset(x, y)
        self._store_pixel(offset, pixel)

    def _store_pixel(mut self, offset: Int, pixel: Rgba8):
        self._pixels[offset] = pixel._red
        self._pixels[offset + 1] = pixel._green
        self._pixels[offset + 2] = pixel._blue
        self._pixels[offset + 3] = pixel._alpha

    def clear(mut self, pixel: Rgba8):
        """Overwrite every visible pixel, preserving any row padding."""
        if self._width == 0 or self._height == 0:
            return
        for y in range(self._height):
            self._fill_contiguous(y * self._stride, self._width, pixel)

    def fill_span(
        mut self,
        x: Int,
        y: Int,
        length: Int,
        pixel: Rgba8,
    ) raises:
        """Overwrite a clipped horizontal solid span."""
        _validate_extent(length, "fill span", "length")
        if y < 0 or y >= self._height:
            return
        var clipped = _clip_interval(x, length, self._width)
        if clipped.length == 0:
            return
        self._fill_contiguous(
            y * self._stride + clipped.start * _CHANNELS_PER_PIXEL,
            clipped.length,
            pixel,
        )

    def fill_rect(
        mut self,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        pixel: Rgba8,
    ) raises:
        """Overwrite a clipped axis-aligned solid integer rectangle."""
        _validate_extent(width, "fill rect", "width")
        _validate_extent(height, "fill rect", "height")
        var clipped_x = _clip_interval(x, width, self._width)
        var clipped_y = _clip_interval(y, height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0:
            return
        for row in range(clipped_y.start, clipped_y.start + clipped_y.length):
            self._fill_contiguous(
                row * self._stride + clipped_x.start * _CHANNELS_PER_PIXEL,
                clipped_x.length,
                pixel,
            )

    def blend_span(
        mut self,
        x: Int,
        y: Int,
        length: Int,
        source: Rgba8,
    ) raises:
        """Premultiplied source-over composite a clipped solid span.

        Complete groups of four pixels use 16-lane UInt8/UInt16 SIMD. The
        remainder uses the exact scalar reference formula.
        """
        _validate_extent(length, "blend span", "length")
        if y < 0 or y >= self._height or source._alpha == UInt8(0):
            return
        var clipped = _clip_interval(x, length, self._width)
        if clipped.length == 0:
            return
        self._blend_contiguous(
            y * self._stride + clipped.start * _CHANNELS_PER_PIXEL,
            clipped.length,
            source,
        )

    def blend_rect(
        mut self,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        source: Rgba8,
    ) raises:
        """Premultiplied source-over composite a clipped solid rectangle."""
        _validate_extent(width, "blend rect", "width")
        _validate_extent(height, "blend rect", "height")
        if source._alpha == UInt8(0):
            return
        var clipped_x = _clip_interval(x, width, self._width)
        var clipped_y = _clip_interval(y, height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0:
            return
        for row in range(clipped_y.start, clipped_y.start + clipped_y.length):
            self._blend_contiguous(
                row * self._stride + clipped_x.start * _CHANNELS_PER_PIXEL,
                clipped_x.length,
                source,
            )

    def fill_path(
        mut self,
        path: Path,
        pixel: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
        samples_per_axis: Int = 1,
    ) raises:
        """Rasterize a path with caller-selected coverage and masked overwrite.

        Curves are flattened at ``tolerance``. Open subpaths close implicitly.
        Vertical edge intervals and filled horizontal intervals are half-open:
        pixel centers on a top/left boundary are included and centers on a
        bottom/right boundary are excluded. ``samples_per_axis=1`` retains
        binary coverage. Values 2..16 sample an N by N centered regular grid.
        Fractional fill interpolates source and destination by coverage, even
        for transparent source; blend uses coverage-scaled source-over.
        """
        self.fill_path_clipped(
            path,
            PixelRect(0, 0, self._width, self._height),
            pixel,
            fill_rule,
            tolerance,
            samples_per_axis,
        )

    def fill_path_clipped(
        mut self,
        path: Path,
        clip: PixelRect,
        pixel: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
        samples_per_axis: Int = 1,
    ) raises:
        """Overwrite path-covered pixels inside ``clip`` and the surface."""
        _validate_raster_tolerance(tolerance)
        _validate_samples(samples_per_axis)
        if path.is_empty() or _clip_is_empty(clip, self._width, self._height):
            return
        var edges = _path_edges(path, tolerance)
        if samples_per_axis == 1:
            self._rasterize_scanlines(
                Span(edges), clip, pixel, fill_rule, composite=False
            )
        else:
            self._rasterize_coverage(
                Span(edges), clip, pixel, fill_rule, samples_per_axis, composite=False
            )

    def blend_path(
        mut self,
        path: Path,
        source: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
        samples_per_axis: Int = 1,
    ) raises:
        """Rasterize and source-over composite a path over the full surface."""
        self.blend_path_clipped(
            path,
            PixelRect(0, 0, self._width, self._height),
            source,
            fill_rule,
            tolerance,
            samples_per_axis,
        )

    def blend_path_clipped(
        mut self,
        path: Path,
        clip: PixelRect,
        source: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
        samples_per_axis: Int = 1,
    ) raises:
        """Rasterize and source-over path pixels inside ``clip``."""
        _validate_raster_tolerance(tolerance)
        _validate_samples(samples_per_axis)
        if source._alpha == UInt8(0):
            return
        if path.is_empty() or _clip_is_empty(clip, self._width, self._height):
            return
        var edges = _path_edges(path, tolerance)
        if samples_per_axis == 1:
            self._rasterize_scanlines(
                Span(edges), clip, source, fill_rule, composite=True
            )
        else:
            self._rasterize_coverage(
                Span(edges), clip, source, fill_rule, samples_per_axis, composite=True
            )

    def _rasterize_coverage(
        mut self,
        edges: Span[_Edge, _],
        clip: PixelRect,
        pixel: Rgba8,
        fill_rule: FillRule,
        samples: Int,
        *,
        composite: Bool,
    ):
        var clipped_x = _clip_interval(clip._x, clip._width, self._width)
        var clipped_y = _clip_interval(clip._y, clip._height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0 or len(edges) == 0:
            return
        var x_end = clipped_x.start + clipped_x.length
        var y_end = clipped_y.start + clipped_y.length
        var min_y = edges[0].min_y
        var max_y = edges[0].max_y
        for edge in edges:
            min_y = min(min_y, edge.min_y)
            max_y = max(max_y, edge.max_y)
        # The first bound may include one extra row; it never drops coverage.
        var first_row = _first_pixel_center_at_or_after(
            min_y - 0.5, clipped_y.start, y_end
        )
        var row_end = _first_pixel_center_at_or_after(
            max_y + 0.5, clipped_y.start, y_end
        )
        if first_row >= row_end:
            return
        var counts = List[UInt16](length=clipped_x.length, fill=UInt16(0))
        var crossings = List[_Crossing](capacity=len(edges))
        var total = samples * samples
        for y in range(first_row, row_end):
            for x in range(len(counts)):
                counts[x] = UInt16(0)
            for sy in range(samples):
                crossings.clear()
                var sample_y = Float64(y) + (Float64(sy) + 0.5) / Float64(samples)
                for edge in edges:
                    if _edge_crosses(edge, sample_y):
                        crossings.append(
                            _Crossing(_edge_crossing_x(edge, sample_y), edge.winding)
                        )
                _sort_crossings(crossings)
                var winding = 0
                var index = 0
                var previous_x = 0.0
                while index < len(crossings):
                    var crossing_x = crossings[index].x
                    if _is_inside(winding, fill_rule):
                        var first = _first_pixel_center_at_or_after(
                            previous_x - 0.5, clipped_x.start, x_end
                        )
                        var end = _first_pixel_center_at_or_after(
                            crossing_x + 0.5, clipped_x.start, x_end
                        )
                        for x in range(first, end):
                            var covered = _first_subsample(
                                crossing_x, x, samples
                            ) - _first_subsample(previous_x, x, samples)
                            counts[x - clipped_x.start] += UInt16(covered)
                    while index < len(crossings) and crossings[index].x == crossing_x:
                        winding += crossings[index].winding
                        index += 1
                    previous_x = crossing_x
            var x = clipped_x.start
            while x < x_end:
                var covered = Int(counts[x - clipped_x.start])
                var end = x + 1
                while end < x_end and Int(counts[end - clipped_x.start]) == covered:
                    end += 1
                var offset = self._offset(x, y)
                if covered == 0:
                    x = end
                    continue
                if composite:
                    var source = Rgba8._from_validated(
                        _masked_channel(pixel._red, UInt8(0), covered, total),
                        _masked_channel(pixel._green, UInt8(0), covered, total),
                        _masked_channel(pixel._blue, UInt8(0), covered, total),
                        _masked_channel(pixel._alpha, UInt8(0), covered, total),
                    )
                    self._blend_contiguous(offset, end - x, source)
                elif covered == total:
                    self._fill_contiguous(offset, end - x, pixel)
                else:
                    for current in range(x, end):
                        var target = self._offset(current, y)
                        self._store_pixel(
                            target,
                            Rgba8._from_validated(
                                _masked_channel(
                                    pixel._red, self._pixels[target], covered, total
                                ),
                                _masked_channel(
                                    pixel._green,
                                    self._pixels[target + 1],
                                    covered,
                                    total,
                                ),
                                _masked_channel(
                                    pixel._blue,
                                    self._pixels[target + 2],
                                    covered,
                                    total,
                                ),
                                _masked_channel(
                                    pixel._alpha,
                                    self._pixels[target + 3],
                                    covered,
                                    total,
                                ),
                            ),
                        )
                x = end

    def _rasterize_scanlines(
        mut self,
        edges: Span[_Edge, _],
        clip: PixelRect,
        pixel: Rgba8,
        fill_rule: FillRule,
        *,
        composite: Bool,
    ):
        var clipped_x = _clip_interval(clip._x, clip._width, self._width)
        var clipped_y = _clip_interval(clip._y, clip._height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0 or len(edges) == 0:
            return

        var clip_y_end = clipped_y.start + clipped_y.length
        var min_y = edges[0].min_y
        var max_y = edges[0].max_y
        for edge in edges:
            min_y = min(min_y, edge.min_y)
            max_y = max(max_y, edge.max_y)
        var first_row = _first_pixel_center_at_or_after(
            min_y, clipped_y.start, clip_y_end
        )
        var row_end = _first_pixel_center_at_or_after(
            max_y, clipped_y.start, clip_y_end
        )
        if first_row >= row_end:
            return

        var crossings = List[_Crossing](capacity=len(edges))
        for y in range(first_row, row_end):
            crossings.clear()
            var sample_y = Float64(y) + 0.5
            for edge in edges:
                if _edge_crosses(edge, sample_y):
                    crossings.append(
                        _Crossing(_edge_crossing_x(edge, sample_y), edge.winding)
                    )
            _sort_crossings(crossings)

            var winding = 0
            var index = 0
            var has_previous = False
            var previous_x = 0.0
            while index < len(crossings):
                var crossing_x = crossings[index].x
                if has_previous and _is_inside(winding, fill_rule):
                    self._paint_path_interval(
                        y,
                        previous_x,
                        crossing_x,
                        clipped_x,
                        pixel,
                        composite=composite,
                        scalar=False,
                    )

                var group_winding = 0
                while index < len(crossings) and crossings[index].x == crossing_x:
                    group_winding += crossings[index].winding
                    index += 1
                winding += group_winding
                previous_x = crossing_x
                has_previous = True

    def _paint_path_interval(
        mut self,
        y: Int,
        left: Float64,
        right: Float64,
        clipped_x: _ClippedInterval,
        pixel: Rgba8,
        *,
        composite: Bool,
        scalar: Bool,
    ):
        if right <= left:
            return
        var clip_end = clipped_x.start + clipped_x.length
        var start = _first_pixel_center_at_or_after(left, clipped_x.start, clip_end)
        var end = _first_pixel_center_at_or_after(right, clipped_x.start, clip_end)
        if start >= end:
            return
        var offset = y * self._stride + start * _CHANNELS_PER_PIXEL
        if composite:
            if scalar:
                self._blend_contiguous_scalar(offset, end - start, pixel)
            else:
                self._blend_contiguous(offset, end - start, pixel)
        elif scalar:
            for x in range(start, end):
                self._store_pixel(y * self._stride + x * _CHANNELS_PER_PIXEL, pixel)
        else:
            self._fill_contiguous(offset, end - start, pixel)

    def _fill_path_scalar(
        mut self,
        path: Path,
        clip: PixelRect,
        pixel: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
    ) raises:
        """Per-pixel traversal oracle used by tests."""
        _validate_raster_tolerance(tolerance)
        if path.is_empty() or _clip_is_empty(clip, self._width, self._height):
            return
        var edges = _path_edges(path, tolerance)
        self._rasterize_path_scalar(
            Span(edges), clip, pixel, fill_rule, composite=False
        )

    def _blend_path_scalar(
        mut self,
        path: Path,
        clip: PixelRect,
        source: Rgba8,
        fill_rule: FillRule = FillRule.NONZERO,
        tolerance: Float64 = DEFAULT_FLATTEN_TOLERANCE,
    ) raises:
        """Per-pixel scalar source-over traversal oracle used by tests."""
        _validate_raster_tolerance(tolerance)
        if source._alpha == UInt8(0):
            return
        if path.is_empty() or _clip_is_empty(clip, self._width, self._height):
            return
        var edges = _path_edges(path, tolerance)
        self._rasterize_path_scalar(
            Span(edges), clip, source, fill_rule, composite=True
        )

    def _rasterize_path_scalar(
        mut self,
        edges: Span[_Edge, _],
        clip: PixelRect,
        pixel: Rgba8,
        fill_rule: FillRule,
        *,
        composite: Bool,
    ):
        var clipped_x = _clip_interval(clip._x, clip._width, self._width)
        var clipped_y = _clip_interval(clip._y, clip._height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0:
            return
        for y in range(clipped_y.start, clipped_y.start + clipped_y.length):
            var sample_y = Float64(y) + 0.5
            for x in range(clipped_x.start, clipped_x.start + clipped_x.length):
                var sample_x = Float64(x) + 0.5
                var winding = 0
                for edge in edges:
                    if (
                        _edge_crosses(edge, sample_y)
                        and _edge_crossing_x(edge, sample_y) <= sample_x
                    ):
                        winding += edge.winding
                if _is_inside(winding, fill_rule):
                    var offset = self._offset(x, y)
                    if composite:
                        self._blend_contiguous_scalar(offset, 1, pixel)
                    else:
                        self._store_pixel(offset, pixel)

    def _fill_contiguous(
        mut self,
        offset: Int,
        pixel_count: Int,
        pixel: Rgba8,
    ):
        if pixel_count == 0:
            return
        var packed = SIMD[DType.uint8, _SIMD_CHANNELS](
            pixel._red,
            pixel._green,
            pixel._blue,
            pixel._alpha,
            pixel._red,
            pixel._green,
            pixel._blue,
            pixel._alpha,
            pixel._red,
            pixel._green,
            pixel._blue,
            pixel._alpha,
            pixel._red,
            pixel._green,
            pixel._blue,
            pixel._alpha,
        )
        var vector_pixels = pixel_count - pixel_count % _SIMD_PIXELS

        # Safety: ``offset`` and ``pixel_count`` are derived only from validated
        # surface layout and clipped visible rows. Each 16-byte store is within
        # one live contiguous List allocation, uses byte alignment, and the
        # origin-tracked pointer cannot escape this method.
        var data = self._pixels.unsafe_ptr()
        for index in range(0, vector_pixels, _SIMD_PIXELS):
            data.unsafe_store[width=_SIMD_CHANNELS, alignment=1](
                offset + index * _CHANNELS_PER_PIXEL, packed
            )
        for index in range(vector_pixels, pixel_count):
            self._store_pixel(offset + index * _CHANNELS_PER_PIXEL, pixel)

    def _blend_contiguous(
        mut self,
        offset: Int,
        pixel_count: Int,
        source: Rgba8,
    ):
        if source._alpha == UInt8(255):
            self._fill_contiguous(offset, pixel_count, source)
            return
        if pixel_count < _SIMD_PIXELS:
            self._blend_contiguous_scalar(offset, pixel_count, source)
            return
        var inverse_alpha = UInt16(255) - source._alpha.cast[DType.uint16]()
        var sources = SIMD[DType.uint16, _SIMD_CHANNELS](
            UInt16(source._red),
            UInt16(source._green),
            UInt16(source._blue),
            UInt16(source._alpha),
            UInt16(source._red),
            UInt16(source._green),
            UInt16(source._blue),
            UInt16(source._alpha),
            UInt16(source._red),
            UInt16(source._green),
            UInt16(source._blue),
            UInt16(source._alpha),
            UInt16(source._red),
            UInt16(source._green),
            UInt16(source._blue),
            UInt16(source._alpha),
        )
        var inverse = SIMD[DType.uint16, _SIMD_CHANNELS](inverse_alpha)
        var bias = SIMD[DType.uint16, _SIMD_CHANNELS](128)
        var vector_pixels = pixel_count - pixel_count % _SIMD_PIXELS

        # Safety: as in ``_fill_contiguous``, clipping proves every byte range
        # lies within one initialized List row. The pointer retains the List's
        # mutable origin, assumes only byte alignment, and never escapes.
        var data = self._pixels.unsafe_ptr()
        for index in range(0, vector_pixels, _SIMD_PIXELS):
            var byte_offset = offset + index * _CHANNELS_PER_PIXEL
            var destination = data.unsafe_load[width=_SIMD_CHANNELS, alignment=1](
                byte_offset
            )
            var product = destination.cast[DType.uint16]() * inverse
            var biased = product + bias
            var contribution = (biased + (biased >> 8)) >> 8
            var result = (sources + contribution).cast[DType.uint8]()
            data.unsafe_store[width=_SIMD_CHANNELS, alignment=1](byte_offset, result)
        var tail_pixels = pixel_count - vector_pixels
        if tail_pixels > 0:
            self._blend_contiguous_scalar(
                offset + vector_pixels * _CHANNELS_PER_PIXEL,
                tail_pixels,
                source,
            )

    def _blend_contiguous_scalar(
        mut self,
        offset: Int,
        pixel_count: Int,
        source: Rgba8,
    ):
        if source._alpha == UInt8(0):
            return
        if source._alpha == UInt8(255):
            self._fill_contiguous(offset, pixel_count, source)
            return
        var inverse_alpha = UInt16(255) - source._alpha.cast[DType.uint16]()
        for index in range(pixel_count):
            var current = offset + index * _CHANNELS_PER_PIXEL
            self._pixels[current] = _source_over_channel(
                source._red, self._pixels[current], inverse_alpha
            )
            self._pixels[current + 1] = _source_over_channel(
                source._green, self._pixels[current + 1], inverse_alpha
            )
            self._pixels[current + 2] = _source_over_channel(
                source._blue, self._pixels[current + 2], inverse_alpha
            )
            self._pixels[current + 3] = _source_over_channel(
                source._alpha, self._pixels[current + 3], inverse_alpha
            )

    def _blend_span_scalar(
        mut self,
        x: Int,
        y: Int,
        length: Int,
        source: Rgba8,
    ) raises:
        """Scalar semantic reference used by differential tests."""
        _validate_extent(length, "blend span", "length")
        if y < 0 or y >= self._height:
            return
        var clipped = _clip_interval(x, length, self._width)
        self._blend_contiguous_scalar(
            y * self._stride + clipped.start * _CHANNELS_PER_PIXEL,
            clipped.length,
            source,
        )

    def _blend_rect_scalar(
        mut self,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        source: Rgba8,
    ) raises:
        """Scalar rectangle reference used by differential tests."""
        _validate_extent(width, "blend rect", "width")
        _validate_extent(height, "blend rect", "height")
        var clipped_x = _clip_interval(x, width, self._width)
        var clipped_y = _clip_interval(y, height, self._height)
        if clipped_x.length == 0 or clipped_y.length == 0:
            return
        for row in range(clipped_y.start, clipped_y.start + clipped_y.length):
            self._blend_contiguous_scalar(
                row * self._stride + clipped_x.start * _CHANNELS_PER_PIXEL,
                clipped_x.length,
                source,
            )

    def __eq__(self, other: Self) -> Bool:
        if (
            self._width != other._width
            or self._height != other._height
            or self._stride != other._stride
            or len(self._pixels) != len(other._pixels)
        ):
            return False
        for index in range(len(self._pixels)):
            if self._pixels[index] != other._pixels[index]:
                return False
        return True
