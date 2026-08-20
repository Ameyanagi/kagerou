"""Validated two-dimensional points and affine transforms."""


def _is_finite(value: Float64) -> Bool:
    return value == value and value - value == 0.0


def _validate_finite(value: Float64, name: String) raises:
    if not _is_finite(value):
        raise Error(name + " must be finite")


struct Point(Copyable, ImplicitlyCopyable):
    """A constructor-validated point in continuous 2D coordinates.

    Public observations and operations revalidate current storage because Mojo
    1.0 struct fields remain externally mutable.
    """

    var _x: Float64
    var _y: Float64

    def __init__(out self, x: Float64 = 0.0, y: Float64 = 0.0) raises:
        _validate_finite(x, "point x")
        _validate_finite(y, "point y")
        self._x = x
        self._y = y

    def _validate(self) raises:
        _validate_finite(self._x, "point x")
        _validate_finite(self._y, "point y")

    def x(self) raises -> Float64:
        self._validate()
        return self._x

    def y(self) raises -> Float64:
        self._validate()
        return self._y

    def translated(self, dx: Float64, dy: Float64) raises -> Self:
        self._validate()
        _validate_finite(dx, "translation x")
        _validate_finite(dy, "translation y")
        return Self(self._x + dx, self._y + dy)


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
    def identity() raises -> Self:
        return Self(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)

    @staticmethod
    def translation(dx: Float64, dy: Float64) raises -> Self:
        return Self(1.0, 0.0, 0.0, 1.0, dx, dy)

    @staticmethod
    def scale(x_factor: Float64, y_factor: Float64) raises -> Self:
        return Self(x_factor, 0.0, 0.0, y_factor, 0.0, 0.0)

    def _validate(self) raises:
        _validate_finite(self._xx, "transform xx")
        _validate_finite(self._xy, "transform xy")
        _validate_finite(self._yx, "transform yx")
        _validate_finite(self._yy, "transform yy")
        _validate_finite(self._tx, "transform tx")
        _validate_finite(self._ty, "transform ty")

    def apply(self, point: Point) raises -> Point:
        self._validate()
        point._validate()
        return Point(
            self._xx * point._x + self._xy * point._y + self._tx,
            self._yx * point._x + self._yy * point._y + self._ty,
        )

    def followed_by(self, next: Self) raises -> Self:
        """Compose transforms in application order: ``next(self(point))``."""
        self._validate()
        next._validate()
        return Self(
            next._xx * self._xx + next._xy * self._yx,
            next._xx * self._xy + next._xy * self._yy,
            next._yx * self._xx + next._yy * self._yx,
            next._yx * self._xy + next._yy * self._yy,
            next._xx * self._tx + next._xy * self._ty + next._tx,
            next._yx * self._tx + next._yy * self._ty + next._ty,
        )
