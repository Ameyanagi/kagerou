"""Validated two-dimensional points and affine transforms."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer
from std.math import cos, ldexp, sin
from std.memory import bitcast


comptime _FLOAT64_FRACTION_MASK = UInt64(0x000F_FFFF_FFFF_FFFF)
comptime _FLOAT64_EXPONENT_MASK = UInt64(0x7FF)
comptime _FLOAT64_HIDDEN_BIT = UInt64(0x0010_0000_0000_0000)
# A binary64 product has at most 106 significand bits. Aligning one such
# product by 149 places its highest possible bit at signed Int256 bit 254.
comptime _PRODUCT_SIGNIFICAND_BITS = 106
comptime _MAX_EXACT_ALIGNMENT = 149


def _is_finite(value: Float64) -> Bool:
    return value == value and value - value == 0.0


def _validate_finite(value: Float64, name: String) raises:
    if not _is_finite(value):
        raise Error(name + " must be finite")


struct _Validated:
    def __init__(out self):
        pass


struct _FloatParts(Copyable, ImplicitlyCopyable):
    var negative: Bool
    var significand: UInt64
    var exponent: Int

    def __init__(out self, negative: Bool, significand: UInt64, exponent: Int):
        self.negative = negative
        self.significand = significand
        self.exponent = exponent


struct _ScaledInteger(Copyable, ImplicitlyCopyable):
    """An exact integer significand multiplied by a power of two."""

    var significand: Int256
    var exponent: Int

    def __init__(out self, significand: Int256, exponent: Int):
        self.significand = significand
        self.exponent = exponent


def _float_parts(value: Float64) -> _FloatParts:
    """Return the exact finite binary64 significand and base-two exponent."""
    var bits = bitcast[DType.uint64](value)
    var negative = ((bits >> 63) & UInt64(1)) != UInt64(0)
    var raw_exponent = Int((bits >> 52) & _FLOAT64_EXPONENT_MASK)
    var significand = bits & _FLOAT64_FRACTION_MASK
    if raw_exponent == 0:
        return _FloatParts(negative, significand, -1074)
    return _FloatParts(negative, significand | _FLOAT64_HIDDEN_BIT, raw_exponent - 1075)


def _bit_length(value: Int256) -> Int:
    var cursor = value
    var length = 0
    while cursor != 0:
        cursor >>= 1
        length += 1
    return length


def _exact_product(left: Float64, right: Float64) -> _ScaledInteger:
    """Multiply two finite binary64 values without exponent loss."""
    var left_parts = _float_parts(left)
    var right_parts = _float_parts(right)
    if left_parts.significand == 0 or right_parts.significand == 0:
        return _ScaledInteger(Int256(0), 0)

    var significand = Int256(left_parts.significand) * Int256(right_parts.significand)
    var shift = _PRODUCT_SIGNIFICAND_BITS - _bit_length(significand)
    significand <<= Int256(shift)
    if left_parts.negative != right_parts.negative:
        significand = -significand
    return _ScaledInteger(
        significand, left_parts.exponent + right_parts.exponent - shift
    )


def _combine_products(
    first: _ScaledInteger,
    second: _ScaledInteger,
    subtract_second: Bool = False,
) -> _ScaledInteger:
    """Combine exact products without overflowing or underflowing Float64."""
    var second_significand = second.significand
    if subtract_second:
        second_significand = -second_significand
    if first.significand == 0:
        return _ScaledInteger(second_significand, second.exponent)
    if second_significand == 0:
        return first

    var difference = first.exponent - second.exponent
    if difference > _MAX_EXACT_ALIGNMENT:
        return first
    if difference < -_MAX_EXACT_ALIGNMENT:
        return _ScaledInteger(second_significand, second.exponent)
    if difference >= 0:
        return _ScaledInteger(
            (first.significand << Int256(difference)) + second_significand,
            second.exponent,
        )
    return _ScaledInteger(
        first.significand + (second_significand << Int256(-difference)),
        first.exponent,
    )


def _scale_power_of_two(value: Float64, exponent: Int) -> Float64:
    """Apply a base-two exponent in stdlib-safe binary64-sized steps."""
    var result = value
    var remaining = exponent
    while remaining > 1023:
        result = ldexp(result, Int32(1023))
        remaining -= 1023
    while remaining < -1022:
        result = ldexp(result, Int32(-1022))
        remaining += 1022
    return ldexp(result, Int32(remaining))


def _divide_by_scaled(
    numerator: Float64, denominator: _ScaledInteger, name: String
) raises -> Float64:
    """Divide a finite binary64 numerator by an exact scaled integer."""
    if numerator == 0.0:
        return numerator

    var parts = _float_parts(numerator)
    var denominator_significand = denominator.significand
    var negative = parts.negative
    if denominator_significand < 0:
        denominator_significand = -denominator_significand
        negative = not negative

    var ratio = Float64(parts.significand) / Float64(denominator_significand)
    if negative:
        ratio = -ratio
    var result = _scale_power_of_two(ratio, parts.exponent - denominator.exponent)
    _validate_finite(result, name)
    if result == 0.0:
        raise Error(name + " is not representable")
    return result


def _scaled_to_float(value: _ScaledInteger, name: String) raises -> Float64:
    """Round an exact scaled integer to a finite, non-underflowed binary64."""
    if value.significand == 0:
        return 0.0

    var significand = value.significand
    var negative = significand < 0
    if negative:
        significand = -significand
    var result = _scale_power_of_two(Float64(significand), value.exponent)
    if negative:
        result = -result
    _validate_finite(result, name)
    if result == 0.0:
        raise Error(name + " is not representable")
    return result


def _stable_product_sum(
    first_left: Float64,
    first_right: Float64,
    second_left: Float64,
    second_right: Float64,
    name: String,
) raises -> Float64:
    return _scaled_to_float(
        _combine_products(
            _exact_product(first_left, first_right),
            _exact_product(second_left, second_right),
        ),
        name,
    )


struct Point(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """A constructor-validated point in continuous 2D coordinates.

    Construction establishes the coordinate invariants and public operations
    trust them thereafter. Direct mutation of underscore-prefixed storage is out
    of contract; call ``validate`` explicitly after unusual low-level mutation
    when a checkpoint is needed.
    """

    var _x: Float64
    var _y: Float64

    def __init__(out self, x: Float64 = 0.0, y: Float64 = 0.0) raises:
        _validate_finite(x, "point x")
        _validate_finite(y, "point y")
        self._x = x
        self._y = y

    def validate(self) raises:
        """Validate both stored coordinates explicitly."""
        _validate_finite(self._x, "point x")
        _validate_finite(self._y, "point y")

    def x(self) -> Float64:
        return self._x

    def y(self) -> Float64:
        return self._y

    def translated(self, dx: Float64, dy: Float64) raises -> Self:
        _validate_finite(dx, "translation x")
        _validate_finite(dy, "translation y")
        return Self(self._x + dx, self._y + dy)

    def __eq__(self, other: Self) -> Bool:
        return self._x == other._x and self._y == other._y

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Point(", self._x, ", ", self._y, ")")


struct AffineTransform(Copyable, ImplicitlyCopyable):
    """A constructor-validated 2D affine 2-by-3 matrix.

    A point is mapped to ``(xx*x + xy*y + tx, yx*x + yy*y + ty)``.
    ``followed_by(next)`` applies this transform first and ``next`` second.
    """

    var _xx: Float64
    var _xy: Float64
    var _yx: Float64
    var _yy: Float64
    var _tx: Float64
    var _ty: Float64

    def __init__(
        out self,
        xx: Float64,
        xy: Float64,
        yx: Float64,
        yy: Float64,
        tx: Float64,
        ty: Float64,
    ) raises:
        _validate_finite(xx, "transform xx")
        _validate_finite(xy, "transform xy")
        _validate_finite(yx, "transform yx")
        _validate_finite(yy, "transform yy")
        _validate_finite(tx, "transform tx")
        _validate_finite(ty, "transform ty")
        self._xx = xx
        self._xy = xy
        self._yx = yx
        self._yy = yy
        self._tx = tx
        self._ty = ty

    @staticmethod
    def _from_validated(
        xx: Float64,
        xy: Float64,
        yx: Float64,
        yy: Float64,
        tx: Float64,
        ty: Float64,
    ) -> Self:
        return Self(xx, xy, yx, yy, tx, ty, _validated=_Validated())

    def __init__(
        out self,
        xx: Float64,
        xy: Float64,
        yx: Float64,
        yy: Float64,
        tx: Float64,
        ty: Float64,
        *,
        _validated: _Validated,
    ):
        self._xx = xx
        self._xy = xy
        self._yx = yx
        self._yy = yy
        self._tx = tx
        self._ty = ty

    @staticmethod
    def identity() -> Self:
        return Self._from_validated(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

    @staticmethod
    def translation(dx: Float64, dy: Float64) raises -> Self:
        return Self(1.0, 0.0, 0.0, 1.0, dx, dy)

    @staticmethod
    def scale(x_factor: Float64, y_factor: Float64) raises -> Self:
        return Self(x_factor, 0.0, 0.0, y_factor, 0.0, 0.0)

    @staticmethod
    def rotation(radians: Float64) raises -> Self:
        """Return a counterclockwise rotation around the origin."""
        _validate_finite(radians, "rotation angle")
        var cosine = cos(radians)
        var sine = sin(radians)
        return Self(cosine, -sine, sine, cosine, 0.0, 0.0)

    def validate(self) raises:
        """Validate all stored coefficients explicitly."""
        _validate_finite(self._xx, "transform xx")
        _validate_finite(self._xy, "transform xy")
        _validate_finite(self._yx, "transform yx")
        _validate_finite(self._yy, "transform yy")
        _validate_finite(self._tx, "transform tx")
        _validate_finite(self._ty, "transform ty")

    def xx(self) -> Float64:
        return self._xx

    def xy(self) -> Float64:
        return self._xy

    def yx(self) -> Float64:
        return self._yx

    def yy(self) -> Float64:
        return self._yy

    def tx(self) -> Float64:
        return self._tx

    def ty(self) -> Float64:
        return self._ty

    def apply(self, point: Point) raises -> Point:
        return Point(
            self._xx * point._x + self._xy * point._y + self._tx,
            self._yx * point._x + self._yy * point._y + self._ty,
        )

    def followed_by(self, next: Self) raises -> Self:
        """Compose transforms in application order: ``next(self(point))``."""
        return Self(
            next._xx * self._xx + next._xy * self._yx,
            next._xx * self._xy + next._xy * self._yy,
            next._yx * self._xx + next._yy * self._yx,
            next._yx * self._xy + next._yy * self._yy,
            next._xx * self._tx + next._xy * self._ty + next._tx,
            next._yx * self._tx + next._yy * self._ty + next._ty,
        )

    def inverted(self) raises -> Self:
        """Return the inverse or raise when the linear part is singular.

        Singularity is exact in K0.3; a near-singular tolerance belongs to the
        separately reviewed K0.4 policy. Exact integer significands and tracked
        base-two exponents prevent determinant overflow and underflow.
        """
        var determinant = _combine_products(
            _exact_product(self._xx, self._yy),
            _exact_product(self._xy, self._yx),
            subtract_second=True,
        )
        if determinant.significand == 0:
            raise Error("transform is singular")

        var inverse_xx = _divide_by_scaled(self._yy, determinant, "transform xx")
        var inverse_xy = _divide_by_scaled(-self._xy, determinant, "transform xy")
        var inverse_yx = _divide_by_scaled(-self._yx, determinant, "transform yx")
        var inverse_yy = _divide_by_scaled(self._xx, determinant, "transform yy")
        var inverse_tx = _stable_product_sum(
            -inverse_xx,
            self._tx,
            -inverse_xy,
            self._ty,
            "transform tx",
        )
        var inverse_ty = _stable_product_sum(
            -inverse_yx,
            self._tx,
            -inverse_yy,
            self._ty,
            "transform ty",
        )
        return Self(
            inverse_xx,
            inverse_xy,
            inverse_yx,
            inverse_yy,
            inverse_tx,
            inverse_ty,
        )
