import Toybox.Lang;
import Toybox.Graphics;

typedef Point as [Float, Float];

class Polygon {
    private var _points as Array<Point>;
    (:initialized) private var _width as Float;
    (:initialized) private var _height as Float;

    public function initialize(points as Array<Point>) {
        var count = points.size();

        self._points = new Array<Point>[count];
        for (var i = 0; i < count; i += 1) {
            var p = points[i];
            self._points[i] = [p[0], p[1]];
        }
        self.measure();
    }

    private function measure() as Polygon {
        var minX = 999999f;
        var minY = 999999f;
        var maxX = -999999f;
        var maxY = -999999f;

        var count = self._points.size();

        for (var i = 0; i < count; i += 1) {
            var p = self._points[i];
            if (p[0] < minX) {
                minX = p[0];
            }
            if (p[0] > maxX) {
                maxX = p[0];
            }
            if (p[1] < minY) {
                minY = p[1];
            }
            if (p[1] > maxY) {
                maxY = p[1];
            }
        }

        self._width = maxX - minX;
        self._height = maxY - minY;
        return self;
    }

    public function points() as Array<Point> {
        return self._points;
    }

    public function width() as Float {
        return self._width;
    }

    public function height() as Float {
        return self._height;
    }

    public function rotatedPoints(angle as Float) as Array<Point> {
        var points = self._points;
        var count = points.size();
        var newPoints = new Array<Point>[count];

        var sinA = Math.sin(angle);
        var cosA = Math.cos(angle);

        for (var i = 0; i < count; i += 1) {
            var x = points[i][0];
            var y = points[i][1];
            newPoints[i] = [
                x * cosA - y * sinA,
                y * cosA + x * sinA
            ] as Point;
        }
        return newPoints;
    }

    public function rotate(angle as Float) as Polygon {
        self._points = rotatedPoints(angle);
        self.measure();
        return self;
    }

    public function translate(dx as Float, dy as Float) as Polygon {
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

    public function scale(fx as Float, fy as Float) as Polygon {
        var poly = self._points;
        var count = poly.size();
        for (var i = 0; i < count; i += 1) {
            poly[i] = [
                poly[i][0] * fx,
                poly[i][1] * fy
            ];
        }
        self.measure();
        return self;
    }

    public function extend(delta as Float, threshold as Float) as Polygon {
        var poly = self._points;
        var count = poly.size();
        for (var i = 0; i < count; i += 1) {
            if (poly[i][1] >= threshold) {
                poly[i][1] += delta;
            }
        }
        self.measure();
        return self;
    }

    public function draw(dc as Dc) as Polygon {
        var prevPoint = self._points[0];
        var count = self._points.size();
        for (var i = 1; i < count; i += 1) {
            var point = self._points[i];
            dc.drawLine(prevPoint[0], prevPoint[1], point[0], point[1]);
            prevPoint = point;
        }
        var point = self._points[0];
        dc.drawLine(prevPoint[0], prevPoint[1], point[0], point[1]);

        return self;
    }

    public function fill(dc as Dc) as Polygon {
        dc.fillPolygon(self._points);
        return self;
    }
}

