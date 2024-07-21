import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.ActivityMonitor;

const PI2 = $.Toybox.Math.PI * 2;
const PIH = PI2 / 4;

class GeoHunterView extends WatchUi.WatchFace {
    // private var drawSecondsHand as Boolean;
    private var _bgColor as Graphics.ColorType;
    private var _tickColor as Graphics.ColorType;

    private var _indexColorBright as Graphics.ColorType;
    private var _indexColorDim as Graphics.ColorType;
    private var _indexColor as Graphics.ColorType;

    private var _handColorBright as Graphics.ColorType;
    private var _handColorDim as Graphics.ColorType;
    private var _handColor as Graphics.ColorType;

    private var _pinionColor as Graphics.ColorType;

    private var _lowPowerMode as Boolean;

    private var _offscreenBuffer as BufferedBitmap?;

    private var _hourHandParts as Array<Polygon>;
    private var _minuteHandParts as Array<Polygon>;
    private var _secondsHand as Polygon;
    private var _subdialHand as Polygon;

    private var _indexPoly as Polygon;
    private var _indexLength as Lang.Float;
    private var _indexWidth as Lang.Float;

    (:initialized) private var _screenSize as Lang.Float;
    (:initialized) private var _centreOffset as Lang.Float;
    (:initialized) private var _pt as Lang.Float;

    private function pt(val as Lang.Numeric) as Float {
        return (val as Float) * _pt;
    }

    public function initialize() {
        WatchFace.initialize();
        _bgColor = 0x000000;
        _tickColor = 0xAAAAAA;

        _indexColorBright = 0xFFFFFF;
        _indexColorDim = 0xCCCCCC;
        _indexColor = _indexColorBright;

        _handColorBright = 0xFFFFFF;
        _handColorDim = 0xCCCCCC;
        _handColor = _handColorBright;

        _pinionColor = 0x999999;
        _lowPowerMode = false;

        var points = [
            getHandPoints1(),
            getHandPoints2(),
            getHandPoints3()
        ];

        _hourHandParts = [
            new Polygon(points[0]),
            new Polygon(points[1]),
            new Polygon(points[2]),
        ];

        _minuteHandParts = [
            new Polygon(points[0]),
            new Polygon(points[1]),
            new Polygon(points[2])
        ];
        _minuteHandParts[0].extend(55f, 80f);
        _minuteHandParts[1].extend(55f, 80f);
        _minuteHandParts[2].extend(55f, 80f);

        points = getSubdialHandPoints();
        _subdialHand = new Polygon(points);

        points = getSecondsHandPoints();
        _secondsHand = new Polygon(points);
        // _secondsHand.translate(-3f, 0f);

        points = getIndexPoints();
        _indexPoly = new Polygon(points);
        _indexLength = 55f;
        _indexWidth = 10f;
    }

    // Hour and minutes hands are the same shape, just extended to different sizes
    // 1: inner part
    private function getHandPoints1() as Array<Point> {
        return [
            [-3, 0],
            [-3, 120],
            [ 0, 132],
            [ 3, 120],
            [ 3, 0]
        ] as Array<Point>;
    }
    // 2: outer part
    private function getHandPoints2() as Array<Point> {
        return [
            [ 0, 30],
            [-8, 36],
            [-8, 110],
            [ 0, 132],
            [ 8, 110],
            [ 8, 36],
        ] as Array<Point>;
    }

    // 3: 'lume', TODO
    private function getHandPoints3() as Array<Point> {
        return [
            [-3, 60],
            [-3, 110],
            [ 3, 110],
            [ 3, 60]
        ] as Array<Point>;
    }

    private function getSecondsHandPoints() as Array<Point> {
        return [
            [-3, -80],
            [-3, 0],
            [-1, 0],
            [0, 190],
            [1, 0],
            [3, 0],
            [3, -80]
        ] as Array<Point>;
    }

    private function getSubdialHandPoints() as Array<Point> {
        return [
            [-1, 0],
            [-1, 20],
            [-2.5, 22],
            [-2.5, 55],
            [ 0, 60],
            [ 2.5, 55],
            [ 2.5, 22],
            [ 1, 20],
            [ 1, 0]
        ] as Array<Point>;
    }

    private function getIndexPoints() as Array<Point> {
        return [
            [-4, 0],
            [4, 0],
            [4, 55],
            [-4, 55]
        ] as Array<Point>;
    }

    public function onLayout(dc as Dc) as Void {
        createOffscreenBuffers(dc);
        // TODO: scale polys to match screen size (_screenSize / 390)
    }

    public function onEnterSleep() as Void {
        _lowPowerMode = true;
        _handColor = _handColorDim;
        _indexColor = _indexColorDim;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _lowPowerMode = false;
        _handColor = _handColorBright;
        _indexColor = _indexColorBright;
        WatchUi.requestUpdate();
    }

    function onUpdate(screenDc as Dc) as Void {
        var offscreenDc = _offscreenBuffer.getDc();
        screenDc.clearClip();
        if (offscreenDc has :setAntiAlias) {
            offscreenDc.setAntiAlias(true);
            screenDc.setAntiAlias(true);
        }

        offscreenDc.setColor(_bgColor, _bgColor);
        offscreenDc.clear();

        // _dial.draw(offscreenDc);
        drawTicks(offscreenDc);
        drawIndices(offscreenDc);
        drawDate(offscreenDc);
        drawSteps(offscreenDc);
        drawBatteryDial(offscreenDc);
        drawBatteryHand(offscreenDc);
        drawHands(offscreenDc);

        screenDc.drawBitmap(0, 0, _offscreenBuffer);

        if (!_lowPowerMode) {
            drawSecondsHand(screenDc);
        }
    }

    private function createOffscreenBuffers(dc as Dc) as Void {
        var bufOpts = {
            :width=>dc.getWidth(),
            :height=>dc.getHeight()
        };

        if (Graphics has :createBufferedBitmap) {
            _offscreenBuffer = Graphics.createBufferedBitmap(bufOpts).get();
        } else {
            // older devices, this is somewhat less efficient and uses more heap
            _offscreenBuffer = new Graphics.BufferedBitmap(bufOpts);
        }

        _centreOffset = dc.getWidth() / 2f;
        _screenSize = dc.getWidth() as Lang.Float;
        _pt = _screenSize / 390.0f;
    }

    private function drawTicks(dc as Dc) as Void {
        var length = 12*_pt;
        var inset = 1*_pt;
        var x1 = 0;
        var y1 = 0;
        var x2 = 0;
        var y2 = 0;
        var radius = (_screenSize - inset*2f) / 2f;

        dc.setColor(_tickColor, _bgColor);
        dc.setPenWidth(1);
        var step = PI2/60f;
        var angle = 0f;
        for (var tick = 0; tick < 30; tick += 1) {
            if (tick % 5 == 0) {
                angle += step;
                continue;
            }
            var cosA = Math.cos(angle);
            var sinA = Math.sin(angle);
            x1 =  radius * cosA;
            y1 =  radius * sinA;
            x2 = -radius * cosA;
            y2 = -radius * sinA;
            dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);
            angle += step;
        }
        dc.setColor(_bgColor, _bgColor);
        dc.fillCircle(_centreOffset, _centreOffset, radius - length);
    }

    private function drawIndices(dc as Dc) as Void {
        var step = PI2/12f;
        var angle = step;
        var offset = (_screenSize / 2f) - _indexLength;

        dc.setPenWidth(4);

        // Non-cardinal indices
        for (var index = 1; index < 12; index += 1) {
            if (index % 3 == 0) {
                angle += step;
                continue;
            }

            var x = offset * Math.cos(angle) + _centreOffset;
            var y = offset * Math.sin(angle) + _centreOffset;

            var poly = new Polygon(_indexPoly.points())
                .rotate(angle - PIH)
                .translate(x, y);

            dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
            poly.draw(dc);
            dc.setColor(_indexColor, Graphics.COLOR_TRANSPARENT);
            poly.fill(dc);

            angle += step;
        }

        // Cardinal indices
        var cardinalScale = 1.2f;
        angle = -PIH;
        step = PI2/4f;
        offset = (_screenSize / 2f) - _indexLength * cardinalScale;
        var cardinalPolyPoints = new Polygon(_indexPoly.points()).scale(1f / cardinalScale, cardinalScale).points();
        for (var index = 0; index < 4; index += 1) {
            var x = offset * Math.cos(angle) + _centreOffset;
            var y = offset * Math.sin(angle) + _centreOffset;

            var poly1 = new Polygon(cardinalPolyPoints).translate(-_indexWidth + 5, 0f);
            var poly2 = new Polygon(cardinalPolyPoints).translate(_indexWidth - 5, 0f);
            poly1.rotate(angle - PIH).translate(x, y);
            poly2.rotate(angle - PIH).translate(x, y);

            dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
            poly1.draw(dc);
            poly2.draw(dc);
            dc.setColor(_indexColor, Graphics.COLOR_TRANSPARENT);
            poly1.fill(dc);
            poly2.fill(dc);

            angle += step;
        }
    }

    private function drawHands(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var angleHour =   PI2 * ((clockTime.min/60f + clockTime.hour) / 12f) - Math.PI;
        var angleMinute = PI2 *  (clockTime.min/60f                 )        - Math.PI;
        var pinionSize = 12f*_pt;

        // Hours hand
        var polys = [
            new Polygon(_hourHandParts[0].points()),
            new Polygon(_hourHandParts[1].points()),
            new Polygon(_hourHandParts[2].points())
        ];
        polys[0].rotate(angleHour)
            .translate(_centreOffset, _centreOffset);
        polys[1].rotate(angleHour)
            .translate(_centreOffset, _centreOffset);
        polys[2].rotate(angleHour)
            .translate(_centreOffset, _centreOffset);

        // Note: only need to outline first 2 parts in _bgColor
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        polys[0].draw(dc);
        polys[1].draw(dc);

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        polys[1].fill(dc);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        polys[0].fill(dc);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        polys[2].fill(dc);

        // Minutes hand
        polys = [
            new Polygon(_minuteHandParts[0].points()),
            new Polygon(_minuteHandParts[1].points()),
            new Polygon(_minuteHandParts[2].points())
        ];
        polys[0].rotate(angleMinute)
            .translate(_centreOffset, _centreOffset);
        polys[1].rotate(angleMinute)
            .translate(_centreOffset, _centreOffset);
        polys[2].rotate(angleMinute)
            .translate(_centreOffset, _centreOffset);

        // Note: only need to outline first 2 parts
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        polys[0].draw(dc);
        polys[1].draw(dc);

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        polys[1].fill(dc);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        polys[0].fill(dc);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        polys[2].fill(dc);

        drawPinion(dc, _centreOffset, _centreOffset, pinionSize);
    }

    private function drawPinion(dc as Dc, x as Float, y as Float, size as Float) as Void {
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size + 1);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size);

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 2);
    }

    private function drawBatteryDial(dc as Dc) as Void {
        var radius = pt(74);
        var x = pt(138);
        var y = pt(185);

        // Note: degrees, not radians
        var start = 120f;
        var end = 240f;
        var arcStart = 128f;
        var arcEnd = 240f;

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pt(34));
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, arcStart, arcEnd);

        dc.setColor(_indexColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pt(18));
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, arcStart, arcEnd);

        var lowStart = ((arcEnd - arcStart) / 5f) * 3f + arcStart + 5;
        dc.setColor(0xCC8800, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, lowStart, arcEnd);
        lowStart = ((arcEnd - arcStart) / 5f) * 4f + arcStart + 4;
        dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, lowStart, arcEnd);

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pt(135), pt(195), radius - pt(12));

        x = pt(135);
        y = pt(195);
        var sectors = 5;
        var sectorSize = (end - start) / (sectors as Float);
        dc.setPenWidth(3);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        for (var index = 0; index < sectors; index += 1) {
            radius += 1;
            var angle = start + index * sectorSize;
            angle = (angle / 360f) * PI2;
            var x2 = radius * Math.cos(angle);
            var y2 = radius * Math.sin(angle);
            dc.drawLine(x, y, x + x2, y + y2);
        }
    }

    private function drawBatteryHand(dc as Dc) as Void {
        var x = 135f*_pt;
        var y = 195f*_pt;

        var battery = System.getSystemStats().battery;
        var angle0 = 120f;
        var angle100 = 240f;
        var angle = (angle100 - angle0) * (battery/100f) + angle0;
        var angleRad = (angle/360) * PI2 - PIH;

        var hand = new Polygon(_subdialHand.points())
            .rotate(angleRad)
            .translate(x, y);

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        hand.draw(dc);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, x, y, 4f);
    }

    private function drawDate(dc as Dc) as Void {
        var width = pt(45);
        var height = pt(32);
        var x = pt(_screenSize - width - 23);
        var y = pt(_centreOffset - height/2f);

        var now = Time.now();
        var date = Time.Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dateStr = date.day;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setPenWidth(pt(15));
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, width, height);
        dc.fillRectangle(x, y, width, height);

        dc.setPenWidth(pt(7));
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, width, height);

        dc.setPenWidth(pt(5));
        dc.setColor(_indexColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, width, height);

        dc.drawText(
            x + width/2 + 2, y + height/2,
            Graphics.FONT_XTINY,
            dateStr, justify
        );
    }

    private function thousandsSep(num) as String {
        var hundreds = num % 1000;
        var thousands = Math.floor(num / 1000.0);
        if (thousands > 0) {
            return thousands.format("%d") + "," + hundreds.format("%03d");
        } else {
            return hundreds.format("%d");
        }
    }

    private function drawSteps(dc as Dc) as Void {
        var font = Graphics.FONT_TINY;
        var steps = ActivityMonitor.getInfo().steps;
        var stepsStr = "----";
        if (steps != null) {
            stepsStr = thousandsSep(steps);
        }
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centreOffset, _centreOffset + _screenSize / 5,
            font, stepsStr,
            Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawSecondsHand(dc as Dc) as Void {
        var time = System.getClockTime();
        var angle = (time.sec / 60f) * PI2;

        var hand = new Polygon(_secondsHand.points())
            .rotate(angle)
            .translate(_centreOffset, _centreOffset);

        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, _centreOffset, _centreOffset, 4f);
    }
}
