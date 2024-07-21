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

        _pinionColor = 0x777777;
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

        _subdialHand = new Polygon(points[0]);
        _subdialHand.scale(0.5f, 0.32f).translate(-(_subdialHand.width() / 2f), -_subdialHand.height() - 4f);

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
        // drawBatteryHand(offscreenDc);
        drawHands(offscreenDc);
        if (!_lowPowerMode) {
            drawSecondsHand(offscreenDc);
        }

        screenDc.drawBitmap(0, 0, _offscreenBuffer);
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

            var poly1 = new Polygon(cardinalPolyPoints).translate(-_indexWidth + 6, 0f);
            var poly2 = new Polygon(cardinalPolyPoints).translate(_indexWidth - 6, 0f);
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
        var angleHour =   PI2 * ((clockTime.min/60f + clockTime.hour) / 12f);
        var angleMinute = PI2 *  (clockTime.min/60f                 )       ;
        var pinionSize = 12f;

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

    private function drawBatteryHand(dc as Dc) as Void {
        var x = 140f;
        var y = 195f;

        var battery = 100f - System.getSystemStats().battery;
        var angle0 = -63f;
        var angle100 = 63f;
        var angle = (angle100 - angle0) * (battery/100f) + angle0;
        var angleRad = (angle/360) * PI2 - PIH;

        var hand = new Polygon(_subdialHand.points())
            .rotate(angleRad)
            .translate(x, y);

        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, x, y, 4f);
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
