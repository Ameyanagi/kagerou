"""Validated path vocabulary and stateful path construction."""

from std.builtin.comparable import Equatable
from std.collections import List, Optional
from std.io import Writable, Writer

from .geometry import (
    AffineTransform,
    Point,
    Rect,
    _Validated,
    _is_finite,
    _validate_finite,
)


# The standard four-cubic circle construction follows from matching a
# quadrant's endpoint tangents: kappa = 4 / 3 * (sqrt(2) - 1).
comptime _CIRCLE_KAPPA = 0.5522847498307936


struct PathVerb(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """A nominal path command with a fixed number of stored points."""

    var _value: Int

    comptime MOVE = PathVerb(_value=0)
    comptime LINE = PathVerb(_value=1)
    comptime QUAD = PathVerb(_value=2)
    comptime CUBIC = PathVerb(_value=3)
    comptime CLOSE = PathVerb(_value=4)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def point_count(self) -> Int:
        """Return the number of points stored for this command."""
        if self == Self.MOVE or self == Self.LINE:
            return 1
        if self == Self.QUAD:
            return 2
        if self == Self.CUBIC:
            return 3
        return 0

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        if self == Self.MOVE:
            writer.write("MOVE")
        elif self == Self.LINE:
            writer.write("LINE")
        elif self == Self.QUAD:
            writer.write("QUAD")
        elif self == Self.CUBIC:
            writer.write("CUBIC")
        else:
            writer.write("CLOSE")


struct FillRule(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Select the winding rule used when a path is filled.

    ``NONZERO``, the default everywhere, counts signed boundary crossings.
    ``EVEN_ODD`` uses crossing parity. This type is rendering vocabulary in K1;
    rasterization is introduced in a later milestone.
    """

    var _value: Int

    comptime NONZERO = FillRule(_value=0)
    comptime EVEN_ODD = FillRule(_value=1)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("NONZERO" if self == Self.NONZERO else "EVEN_ODD")


struct Path(Copyable, Equatable, Movable, Writable):
    """An immutable-by-contract path with structure-of-arrays storage.

    ``_coordinates`` contains interleaved x/y pairs and its length equals twice
    the sum of ``verb.point_count()`` over ``_verbs``. Coordinates are finite,
    the first verb is ``MOVE``, and every drawing verb belongs to a subpath;
    ``CLOSE`` ends its current subpath. Construction through ``PathBuilder`` or
    its factories establishes these invariants. Direct underscore-field
    mutation is out of contract; call ``validate`` explicitly after unusual
    low-level mutation when a checkpoint is needed.
    """

    var _verbs: List[PathVerb]
    var _coordinates: List[Float64]

    def __init__(
        out self,
        *,
        var _verbs: List[PathVerb],
        var _coordinates: List[Float64],
        _validated: _Validated,
    ):
        self._verbs = _verbs^
        self._coordinates = _coordinates^

    def is_empty(self) -> Bool:
        return len(self._verbs) == 0

    def verb_count(self) -> Int:
        return len(self._verbs)

    def point_count(self) -> Int:
        return len(self._coordinates) // 2

    def verbs(self) -> Span[PathVerb, origin_of(self._verbs)]:
        """Return a borrowed view of the command stream."""
        return Span(self._verbs)

    def coordinates(self) -> Span[Float64, origin_of(self._coordinates)]:
        """Return a borrowed view of interleaved x/y coordinate storage."""
        return Span(self._coordinates)

    def validate(self) raises:
        """Re-check storage arity, subpath structure, and finiteness."""
        var expected_coordinates = 0
        for verb in self._verbs:
            expected_coordinates += 2 * verb.point_count()
        if len(self._coordinates) != expected_coordinates:
            raise Error(
                String(
                    "path coordinate arity does not match verbs: expected ",
                    expected_coordinates,
                    ", got ",
                    len(self._coordinates),
                )
            )

        if len(self._verbs) > 0 and self._verbs[0] != PathVerb.MOVE:
            raise Error("path must begin with MOVE")

        var has_current_subpath = False
        for verb in self._verbs:
            if verb == PathVerb.MOVE:
                has_current_subpath = True
            elif not has_current_subpath:
                raise Error("path drawing verb requires a preceding MOVE")
            elif verb == PathVerb.CLOSE:
                has_current_subpath = False

        for coordinate in self._coordinates:
            _validate_finite(coordinate, "path coordinate")

    def transformed(self, transform: AffineTransform) raises -> Self:
        """Return a copy with every stored point mapped by ``transform``."""
        var coordinates = List[Float64](capacity=len(self._coordinates))
        for index in range(0, len(self._coordinates), 2):
            var point = Point(
                self._coordinates[index],
                self._coordinates[index + 1],
                _validated=_Validated(),
            )
            var mapped = transform.apply(point)
            coordinates.append(mapped.x())
            coordinates.append(mapped.y())
        var verbs = self._verbs.copy()
        return Self(
            _verbs=verbs^,
            _coordinates=coordinates^,
            _validated=_Validated(),
        )

    def bounds(self) raises -> Rect:
        """Return conservative control-box bounds over every stored point.

        Quadratic and cubic control points are included. Because each curve is
        contained by its control hull, this is conservative and may exceed the
        curve's tight bounds.
        """
        if self.is_empty():
            raise Error(
                "path bounds are undefined for an empty path: add a subpath first"
            )

        var min_x = self._coordinates[0]
        var min_y = self._coordinates[1]
        var max_x = min_x
        var max_y = min_y
        for index in range(2, len(self._coordinates), 2):
            min_x = min(min_x, self._coordinates[index])
            min_y = min(min_y, self._coordinates[index + 1])
            max_x = max(max_x, self._coordinates[index])
            max_y = max(max_y, self._coordinates[index + 1])
        return Rect(min_x, min_y, max_x, max_y)

    def __eq__(self, other: Self) -> Bool:
        if len(self._verbs) != len(other._verbs):
            return False
        if len(self._coordinates) != len(other._coordinates):
            return False
        for index in range(len(self._verbs)):
            if self._verbs[index] != other._verbs[index]:
                return False
        for index in range(len(self._coordinates)):
            if self._coordinates[index] != other._coordinates[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Path(",
            self.verb_count(),
            " verbs, ",
            self.point_count(),
            " points)",
        )


struct PathBuilder(Movable):
    """Build valid paths with explicit subpath state transitions.

    A closed subpath has no current point. Drawing after ``close`` is rejected
    until ``move_to`` explicitly starts another subpath.
    """

    var _verbs: List[PathVerb]
    var _coordinates: List[Float64]
    var _pending_move: Optional[Point]
    var _has_current_point: Bool

    def __init__(out self):
        self._verbs = List[PathVerb]()
        self._coordinates = List[Float64]()
        self._pending_move = None
        self._has_current_point = False

    def _append_point(mut self, point: Point):
        self._coordinates.append(point.x())
        self._coordinates.append(point.y())

    def _commit_pending_move(mut self):
        if self._pending_move:
            var point = self._pending_move.value()
            self._verbs.append(PathVerb.MOVE)
            self._append_point(point)
            self._pending_move = None
            self._has_current_point = True

    def _require_current_point(self, operation: String) raises:
        if not self._pending_move and not self._has_current_point:
            raise Error(
                String(
                    operation,
                    " before move_to: begin a subpath with move_to first",
                )
            )

    def _line_to_validated(mut self, point: Point):
        self._commit_pending_move()
        self._verbs.append(PathVerb.LINE)
        self._append_point(point)

    def _close_validated(mut self):
        self._commit_pending_move()
        self._verbs.append(PathVerb.CLOSE)
        self._has_current_point = False

    def move_to(mut self, point: Point):
        """Start a subpath, replacing any preceding undrawn ``MOVE``."""
        self._pending_move = point
        self._has_current_point = False

    def line_to(mut self, point: Point) raises:
        self._require_current_point("line_to")
        self._line_to_validated(point)

    def quad_to(mut self, control: Point, point: Point) raises:
        self._require_current_point("quad_to")
        self._commit_pending_move()
        self._verbs.append(PathVerb.QUAD)
        self._append_point(control)
        self._append_point(point)

    def cubic_to(
        mut self,
        control1: Point,
        control2: Point,
        point: Point,
    ) raises:
        self._require_current_point("cubic_to")
        self._commit_pending_move()
        self._verbs.append(PathVerb.CUBIC)
        self._append_point(control1)
        self._append_point(control2)
        self._append_point(point)

    def close(mut self) raises:
        """Close the current subpath with a straight segment to its start.

        Filling implicitly closes open subpaths. Their winding is interpreted
        by ``FillRule`` at rasterization time, with ``FillRule.NONZERO`` as the
        default. After this call, drawing requires a new explicit ``move_to``.
        """
        self._require_current_point("close")
        self._close_validated()

    def finish(var self) -> Path:
        """Consume this builder, dropping any pending undrawn ``MOVE``."""
        var verbs = self._verbs^
        self._verbs = List[PathVerb]()
        var coordinates = self._coordinates^
        self._coordinates = List[Float64]()
        return Path(
            _verbs=verbs^,
            _coordinates=coordinates^,
            _validated=_Validated(),
        )

    @staticmethod
    def rectangle(rect: Rect) -> Path:
        """Return a positive-winding rectangle in coordinate-space order.

        The order is min corner, top-right, max corner, bottom-left, then close.
        It has positive nonzero winding; in a y-down display it appears visually
        clockwise. ``CLOSE`` supplies the fourth side.
        """
        var builder = PathBuilder()
        builder.move_to(
            Point(
                rect.min_x(),
                rect.min_y(),
                _validated=_Validated(),
            )
        )
        builder._line_to_validated(
            Point(
                rect.max_x(),
                rect.min_y(),
                _validated=_Validated(),
            )
        )
        builder._line_to_validated(
            Point(
                rect.max_x(),
                rect.max_y(),
                _validated=_Validated(),
            )
        )
        builder._line_to_validated(
            Point(
                rect.min_x(),
                rect.max_y(),
                _validated=_Validated(),
            )
        )
        builder._close_validated()
        return builder^.finish()

    @staticmethod
    def circle(center: Point, radius: Float64) raises -> Path:
        """Return the standard four-cubic kappa approximation of a circle.

        Matching each quadrant's endpoint positions and tangents gives
        ``kappa = 4 / 3 * (sqrt(2) - 1)``. The path begins at ``center.x + r``
        and follows positive coordinate-space winding before closing.
        """
        if not _is_finite(radius) or radius <= 0.0:
            raise Error("circle radius must be a positive finite device-space distance")

        var cx = center.x()
        var cy = center.y()
        var offset = radius * _CIRCLE_KAPPA
        var builder = PathBuilder()
        builder.move_to(Point(cx + radius, cy))
        builder.cubic_to(
            Point(cx + radius, cy + offset),
            Point(cx + offset, cy + radius),
            Point(cx, cy + radius),
        )
        builder.cubic_to(
            Point(cx - offset, cy + radius),
            Point(cx - radius, cy + offset),
            Point(cx - radius, cy),
        )
        builder.cubic_to(
            Point(cx - radius, cy - offset),
            Point(cx - offset, cy - radius),
            Point(cx, cy - radius),
        )
        builder.cubic_to(
            Point(cx + offset, cy - radius),
            Point(cx + radius, cy - offset),
            Point(cx + radius, cy),
        )
        builder.close()
        return builder^.finish()
