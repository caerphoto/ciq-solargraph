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
    private var _backgroundColor as Graphics.ColorType;
    private var _handColorBright as Graphics.ColorType;
    private var _handColorDim as Graphics.ColorType;
    private var _handColor as Graphics.ColorType;
    private var _pinionColor as Graphics.ColorType;

    private var _lowPowerMode as Boolean;

    private var _offscreenBuffer as BufferedBitmap?;
    private var _dialBright as Bitmap;
    private var _dialDim as Bitmap;
    private var _dial as Bitmap;

    private var _minuteHand as Polygon;
    private var _hourHand as Polygon;
    private var _subdialHand as Polygon;

    (:initialized) private var _screenSize as Lang.Number;
    (:initialized) private var _centreOffset as Lang.Number;
    (:initialized) private var _pt as Lang.Float;

    public function initialize() {
        WatchFace.initialize();
        _backgroundColor = 0x000000;

        _handColorBright = 0xFFFFFF;
        _handColorDim = 0xCCCCCC;
        _handColor = _handColorBright;

        _pinionColor = 0x777777;
        _lowPowerMode = false;

        _dialBright = new WatchUi.Bitmap({ :rezId => $.Rez.Drawables.DialBright, :locX => 0, :locY => 0});
        _dialDim = new WatchUi.Bitmap({ :rezId => $.Rez.Drawables.DialDim, :locX => 0, :locY => 0});
        _dial = _dialBright;

        var points = getHandPoints();
        _minuteHand = new Polygon(points);
        _minuteHand.translate(-(_minuteHand.width() / 2f), -_minuteHand.height() - 6f);
        _hourHand = new Polygon(points);
        _hourHand.scale(1f, 0.65f).translate(-(_hourHand.width() / 2f), -_hourHand.height() - 6f);
        _subdialHand = new Polygon(points);
        _subdialHand.scale(0.5f, 0.32f).translate(-(_subdialHand.width() / 2f), -_subdialHand.height() - 4f);
    }

    private function getHandPoints() as Array<Point> {
        // All hands are the same shape, just scaled to different sizes
        return [
            [4.677,178.677],
            [2.677,155.677],
            [0.677,112.677],
            [4.677,68.677],
            [8.677,0.677],
            [12.677,68.677],
            [16.677,112.677],
            [14.677,155.677],
            [12.677,178.677]
        ] as Array<Point>;
    }

    public function onLayout(dc as Dc) as Void {
        createOffscreenBuffers(dc);
    }

    public function onEnterSleep() as Void {
        _lowPowerMode = true;
        _dial = _dialDim;
        _handColor = _handColorDim;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _lowPowerMode = false;
        _dial = _dialBright;
        _handColor = _handColorBright;
        WatchUi.requestUpdate();
    }

    function onUpdate(screenDc as Dc) as Void {
        var offscreenDc = _offscreenBuffer.getDc();
        screenDc.clearClip();
        if (offscreenDc has :setAntiAlias) {
            offscreenDc.setAntiAlias(true);
            screenDc.setAntiAlias(true);
        }

        _dial.draw(offscreenDc);
        drawBatteryHand(offscreenDc);
        if (!_lowPowerMode) {
            drawSecondsHand(offscreenDc);
        }
        drawHands(offscreenDc);

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

        _centreOffset = dc.getWidth() / 2;
        _screenSize = dc.getWidth();
        _pt = _screenSize / 300.0f;
    }

    private function drawHands(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var angleHour = PI2 * ((clockTime.min/60f + clockTime.hour) / 12f);
        var angleMin =  PI2 *  (clockTime.min/60f                 )       ;
        var pinionSize = 12;

        var hand = new Polygon(_hourHand.points())
            .rotate(angleHour)
            .translate(_centreOffset, _centreOffset);

        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        hand = new Polygon(_minuteHand.points())
            .rotate(angleMin)
            .translate(_centreOffset, _centreOffset);

        dc.setColor(_backgroundColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        hand.draw(dc);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, _centreOffset, _centreOffset, pinionSize);
    }

    private function drawPinion(dc as Dc, x as Number, y as Number, size as Number) as Void {
        dc.setColor(_backgroundColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size + 1);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size);

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setColor(_backgroundColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 2);
    }

    private function drawBatteryHand(dc as Dc) as Void {
        var x = 140;
        var y = 195;

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

        drawPinion(dc, x, y, 4);
    }

    private function drawSecondsHand(dc as Dc) as Void {
        var x = _centreOffset;
        var y = 287;
        var time = System.getClockTime();
        var angle = (time.sec / 60f) * PI2;

        var hand = new Polygon(_subdialHand.points())
            .rotate(angle)
            .translate(x, y);

        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        hand.draw(dc);
        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, x, y, 4);
    }
}
