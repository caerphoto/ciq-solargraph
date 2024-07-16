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

class ElegantView extends WatchUi.WatchFace {
    // private var drawSecondsHand as Boolean;
    private var _handColor as Graphics.ColorType;
    private var _pinionColor as Graphics.ColorType;

    private var _lowPowerMode as Boolean;

    private var _offscreenBuffer as BufferedBitmap?;
    private var _dial as Bitmap;

    (:initialized) private var _screenSize as Lang.Number;
    (:initialized) private var _centreOffset as Lang.Number;
    (:initialized) private var _pt as Lang.Float;


    public function initialize() {
        WatchFace.initialize();
        _handColor = 0xFFFFFF;
        _pinionColor = 0xBBBBBB;
        _lowPowerMode = false;
        _dial = new WatchUi.Bitmap({ :rezId => $.Rez.Drawables.Dial, :locX => 0, :locY => 0});
        // PI2 = Math.PI * 2.0;
        // PIH = Math.PI / 2.0;
    }

    public function onLayout(dc as Dc) as Void {
        createOffscreenBuffers(dc);
    }

    public function onEnterSleep() as Void {
        _lowPowerMode = true;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _lowPowerMode = false;
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

    private function drawHands(dc as Dc) {
        var clockTime = System.getClockTime();
        var angleHour = PI2 * ((clockTime.min/60f + clockTime.hour) / 12f) - PIH;
        var angleMin =  PI2 *  (clockTime.min/60f                 )        - PIH;

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);

        var length = _screenSize / 4f;
        var x = length * Math.cos(angleHour);
        var y = length * Math.sin(angleHour);
        dc.setPenWidth(20);
        dc.drawLine(_centreOffset, _centreOffset, x + _centreOffset, y + _centreOffset);

        length = _screenSize / 2.1f;
        x = length * Math.cos(angleMin);
        y = length * Math.sin(angleMin);
        dc.setPenWidth(10);
        dc.drawLine(_centreOffset, _centreOffset, x + _centreOffset, y + _centreOffset);
    }
}
