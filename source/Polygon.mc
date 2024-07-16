import Toybox.Lang;

typedef Vec as [Float, Float];
typedef Point as [Float, Float];

class Polygon {
    private var _points as Array<Point>;

    public function initialize(points as Array<Point>) {
        var count = points.size();
        self._points = new Array<Point>[count];
        for (var i = 0; i < count; i += 1) {
            var p = points[i];
            self._points[i] = [p[0], p[1]];
        }
    }

    public function points() as Array<Point> {
        return self._points;
    }

    public function rotate(angle) as Polygon {
        var poly = self._points;
        var count = poly.size();
        var sinA = Math.sin(angle);
        var cosA = Math.cos(angle);

        for (var i = 0; i < count; i += 1) {
            var x = poly[i][0];
            var y = poly[i][1];
            self._points[i] = [
                x * cosA - y * sinA,
                y * cosA + x * sinA
            ] as Point;
        }
        return self;
    }

    public function translate(dx, dy) as Polygon {
        var poly = self._points;
        var count = poly.size();
        for (var i = 0; i < count; i += 1) {
            poly[i] = [
                poly[i][0] + dx,
                poly[i][1] + dy
            ];
        }
        return self;
    }

    function scale(fx, fy) as Polygon {
        var poly = self._points;
        var count = poly.size();
        for (var i = 0; i < count; i += 1) {
            poly[i] = [
                poly[i][0] * fx,
                poly[i][1] * fy
            ];
        }
        return self;
    }
}

