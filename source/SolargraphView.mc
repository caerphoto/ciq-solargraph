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
const HOUR_RING_RADIUS = 135f;
const HOUR_RING_THICKNESS = 16f;

const HOUR_HAND_LENGTH = 104f;
const MIN_HAND_LENGTH = 178f;
const SEC_HAND_CIRCLE_RADIUS = 152f;

const TICK_RADIUS_INNER = 185f;
const THICK_INDEX_WIDTH = 5;

const INDEX_BRIGHT = 0xFC9930;
const INDEX_DIM = 0xB65F00;

const HAND_BRIGHT = 0xFFCE00;
const HAND_DIM = 0xB19000;

const PINION = 0xFF6000;

const DAY_BRIGHT = 0x58B8FF;
const DAY_DIM = 0x4188BC;
const DUSK_BRIGHT = 0xD6662A;
const DUSK_DIM = 0x964920;
const NIGHT_BRIGHT = 0x746AB9;
const NIGHT_DIM = 0x4E4694;

const BATTERY_DIAL_FULL_DEG = 165f;
const BATTERY_DIAL_EMPTY_DEG = BATTERY_DIAL_FULL_DEG - 60f;
const BATTERY_DIAL_RADIUS = 165f;

class SolargraphView extends WatchUi.WatchFace {
    private var _bgColor as Graphics.ColorType;
    private var _tickColor as Graphics.ColorType;

    private var _indexColorBright as Graphics.ColorType;
    private var _indexColorDim as Graphics.ColorType;
    private var _indexColor as Graphics.ColorType;

    private var _handColorBright as Graphics.ColorType;
    private var _handColorDim as Graphics.ColorType;
    private var _handColor as Graphics.ColorType;

    private var _pinionColor as Graphics.ColorType;

    private var _cardinalDay as Graphics.ColorType;
    private var _cardinalDusk as Graphics.ColorType;
    private var _cardinalNight as Graphics.ColorType;

    private var _lowPowerMode as Boolean;

    private var _offscreenBuffer as BufferedBitmap?;

    private var _hourRingBright as Bitmap;
    private var _hourRingDim as Bitmap;
    private var _hourRing as Bitmap;

    private var _minuteHand as BufferedBitmap;
    private var _hourHand as BufferedBitmap;

    private var _secondsHand as Polygon;
    private var _subdialHand as Polygon;

    (:initialized) private var _screenSize as Lang.Float;
    (:initialized) private var _centreOffset as Lang.Float;
    (:initialized) private var _pt as Lang.Float;

    private function pt(val as Lang.Numeric) as Float {
        return (val as Float) * _pt;
    }

    public function initialize() {
        WatchFace.initialize();
        _bgColor = 0x000000;
        _tickColor = INDEX_DIM;

        _indexColorBright = INDEX_BRIGHT;
        _indexColorDim = INDEX_DIM;
        _indexColor = _indexColorBright;

        _handColorBright = HAND_BRIGHT;
        _handColorDim = HAND_DIM;
        _handColor = _handColorBright;

        _cardinalDay = DAY_BRIGHT;
        _cardinalDusk = DUSK_BRIGHT;
        _cardinalNight = NIGHT_BRIGHT;

        _pinionColor = PINION;
        _lowPowerMode = false;

        _hourRingBright = new WatchUi.Bitmap({ :rezId => $.Rez.Drawables.HourRingBright, :locX => 0, :locY => 0});
        _hourRingDim = new WatchUi.Bitmap({ :rezId => $.Rez.Drawables.HourRingDim, :locX => 0, :locY => 0});
        _hourRing = _hourRingBright;

        var bitmap = WatchUi.loadResource($.Rez.Drawables.MinuteHand);
        var bufOpts = {
            :width => bitmap.getWidth(),
            :height => bitmap.getHeight()
        };
        _minuteHand = Graphics.createBufferedBitmap(bufOpts).get();
        var dc = _minuteHand.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();
        dc.drawBitmap(0, 0, bitmap);

        bitmap = WatchUi.loadResource($.Rez.Drawables.HourHand);
        bufOpts = {
            :width => bitmap.getWidth(),
            :height => bitmap.getHeight()
        };
        _hourHand = Graphics.createBufferedBitmap(bufOpts).get();
        dc = _hourHand.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();
        dc.drawBitmap(0, 0, bitmap);

        var points = getSubdialHandPoints();
        _subdialHand = new Polygon(points);

        points = getSecondsHandPoints();
        _secondsHand = new Polygon(points);
    }

    private function getSecondsHandPoints() as Array<Point> {
        return [
            [-1, 0],
            [0, 185],
            [1, 0],
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

    public function onLayout(dc as Dc) as Void {
        createOffscreenBuffers(dc);
        // TODO: scale polys to match screen size (_screenSize / 390)
    }

    public function onEnterSleep() as Void {
        _lowPowerMode = true;
        _handColor = _handColorDim;
        _indexColor = _indexColorDim;
        _hourRing = _hourRingDim;
        _cardinalDay = DAY_DIM;
        _cardinalDusk = DUSK_DIM;
        _cardinalNight = NIGHT_DIM;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _lowPowerMode = false;
        _handColor = _handColorBright;
        _indexColor = _indexColorBright;
        _hourRing = _hourRingBright;
        _cardinalDay = DAY_BRIGHT;
        _cardinalDusk = DUSK_BRIGHT;
        _cardinalNight = NIGHT_BRIGHT;
        WatchUi.requestUpdate();
    }

    public function onUpdate(screenDc as Dc) as Void {
        var offscreenDc = _offscreenBuffer.getDc();
        screenDc.clearClip();
        if (offscreenDc has :setAntiAlias) {
            offscreenDc.setAntiAlias(true);
            screenDc.setAntiAlias(true);
        }

        offscreenDc.setColor(_bgColor, _bgColor);
        offscreenDc.clear();

        drawTicks(offscreenDc);
        drawBatteryDial(offscreenDc);
        drawBatteryHand(offscreenDc);
        drawIndices(offscreenDc);
        drawDate(offscreenDc);
        // drawSteps(offscreenDc);
        // drawHrSubdial(offscreenDc);
        // drawHrSubdialHand(offscreenDc);

        drawHands(offscreenDc);

        screenDc.drawBitmap(0, 0, _offscreenBuffer);

        if (!_lowPowerMode) {
            drawSecondsHand(screenDc);
        }
    }

    private function createOffscreenBuffers(dc as Dc) as Void {
        var bufOpts = {
            :width => dc.getWidth(),
            :height => dc.getHeight(),
            :colorDepth => 16,
            :alphaBlending => Graphics.ALPHA_BLENDING_FULL
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
        var x1 = 0;
        var y1 = 0;
        var x2 = 0;
        var y2 = 0;
        var radius = _screenSize / 2f;


        dc.setColor(_tickColor, _bgColor);
        if (!_lowPowerMode) {
            dc.fillCircle(_centreOffset, _centreOffset, radius);
            dc.setColor(_bgColor, _bgColor);
            dc.fillCircle(_centreOffset, _centreOffset, radius - 10);
        }
        var step = PI2/60f;
        var angle = 0f;
        for (var tick = 0; tick < 30; tick += 1) {
            if (tick % 5 == 0) {
                dc.setPenWidth(THICK_INDEX_WIDTH);
            } else {
                dc.setPenWidth(1);
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
        if (_lowPowerMode) {
            dc.setColor(_bgColor, _bgColor);
            dc.fillCircle(_centreOffset, _centreOffset, TICK_RADIUS_INNER);
        }
    }

    private function drawIndices(dc as Dc) as Void {
        var x1 = 0;
        var y1 = 0;
        var x2 = 0;
        var y2 = 0;
        var radius = HOUR_RING_RADIUS;

        _hourRing.draw(dc);

        dc.setColor(_bgColor, _bgColor);
        var step = PI2/24f;
        var angle = 0f;
        for (var tick = 0; tick < 12; tick += 1) {
            if (tick % 3 == 0) {
                dc.setPenWidth(THICK_INDEX_WIDTH * 2);
            } else {
                dc.setPenWidth(4);
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

        var vCardinalOffset = _centreOffset - HOUR_RING_RADIUS/2f + 15;
        var hCardinalOffset = vCardinalOffset + 3;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(_cardinalDay, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centreOffset, _centreOffset - vCardinalOffset, Graphics.FONT_TINY, "12", justify);

        dc.setColor(_cardinalDusk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centreOffset - hCardinalOffset, _centreOffset, Graphics.FONT_TINY, "06", justify);
        // dc.drawText(_centreOffset + hCardinalOffset, _centreOffset, Graphics.FONT_TINY, "18", justify);

        dc.setColor(_cardinalNight, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_centreOffset, _centreOffset + vCardinalOffset, Graphics.FONT_TINY, "24", justify);
    }

    private function drawHands(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var angleHour =   PI2 * ((clockTime.min/60f + clockTime.hour) / 24f) - PIH - Math.PI;
        var angleMinute = PI2 *  (clockTime.min/60f                 )        - PIH;

        var tr = new Graphics.AffineTransform();
        var rot = new Graphics.AffineTransform();
        var bmpCentreOffset = _hourHand.getHeight() / 2f;
        tr.setToTranslation(-bmpCentreOffset, -bmpCentreOffset);
        rot.setToRotation(angleHour);
        rot.concatenate(tr);
        dc.drawBitmap2(
            _centreOffset, _centreOffset,
            _hourHand,
            {
                :transform => rot,
                :filterMode => Graphics.FILTER_MODE_BILINEAR
            }
        );

        dc.setColor(_handColor, _bgColor);
        var radius = HOUR_HAND_LENGTH - 8;
        var cosA = Math.cos(angleHour);
        var sinA = Math.sin(angleHour);
        var x1 =  radius * cosA;
        var y1 =  radius * sinA;
        var x2 = (radius + 16f) * cosA;
        var y2 = (radius + 16f) * sinA;
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);

        tr = new Graphics.AffineTransform();
        rot = new Graphics.AffineTransform();
        bmpCentreOffset = _minuteHand.getHeight() / 2f;
        tr.setToTranslation(-bmpCentreOffset, -bmpCentreOffset);
        rot.setToRotation(angleMinute);
        rot.concatenate(tr);
        dc.drawBitmap2(
            _centreOffset, _centreOffset,
            _minuteHand,
            {
                :transform => rot,
                :filterMode => Graphics.FILTER_MODE_BILINEAR
            }
        );
        radius = MIN_HAND_LENGTH - 8;
        cosA = Math.cos(angleMinute);
        sinA = Math.sin(angleMinute);
        x1 =  radius * cosA;
        y1 =  radius * sinA;
        x2 = (radius + 16f) * cosA;
        y2 = (radius + 16f) * sinA;
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);
    }

    private function drawPinion(dc as Dc, x as Float, y as Float, size as Float) as Void {
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size);

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size - 2);
    }

    private function drawBatteryDial(dc as Dc) as Void {
        var radius = pt(BATTERY_DIAL_RADIUS);
        var x = _centreOffset;
        var y = _centreOffset;

        // Note: degrees, not radians
        var arcStart = 195f;
        var arcEnd = 255f;

        // drawArc degrees go counter-clockwise, while line coord calculations go clockwise
        // Note: these get converted to radians prior to use
        var sectorStart = 105f + 8f; // add 8 to nudge it around a bit
        var sectorEnd = sectorStart + 60f;

        // Main arc
        dc.setColor(_cardinalDay, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pt(18));
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, arcStart, arcEnd);

        // Low arcs
        var lowStart = ((arcEnd - arcStart) / 5f) * 3f + arcStart + 5;
        dc.setColor(0xCC8800, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, lowStart, arcEnd);
        lowStart = ((arcEnd - arcStart) / 5f) * 4f + arcStart + 4;
        dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, radius - pt(9), Graphics.ARC_COUNTER_CLOCKWISE, lowStart, arcEnd);

        // 'Subtractor' circle
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pt(x-3), pt(y+10), radius - pt(12));

        // Sector dividing lines
        x = pt(x-3);
        y = pt(y+10);
        var sectors = 5;
        var sectorSize = (sectorEnd - sectorStart) / (sectors as Float);
        dc.setPenWidth(3);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        for (var index = 0; index < sectors; index += 1) {
            radius += 1;
            var angle = sectorStart + index * sectorSize;
            angle = (angle / 360f) * PI2;
            var x2 = radius * Math.cos(angle);
            var y2 = radius * Math.sin(angle);
            dc.drawLine(_centreOffset, _centreOffset, x + x2, y + y2);
        }
    }

    private function drawBatteryHand(dc as Dc) as Void {
        var battery = System.getSystemStats().battery / 100f;
        var angleRange = BATTERY_DIAL_FULL_DEG - BATTERY_DIAL_EMPTY_DEG;
        var angle = BATTERY_DIAL_EMPTY_DEG + (angleRange * battery);
        var angleRad = (angle/360f) * PI2;

        var radius = BATTERY_DIAL_RADIUS - 5;
        var cosA = Math.cos(angleRad);
        var sinA = Math.sin(angleRad);

        var x1 = radius * cosA;
        var y1 = radius * sinA;
        var x2 = (radius - 20) * cosA;
        var y2 = (radius - 20) * sinA;

        dc.setPenWidth(3);
        // dc.setColor(0x00ff00, Graphics.COLOR_TRANSPARENT);
        dc.setColor(_tickColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_centreOffset + x1, _centreOffset + y1, _centreOffset + x2, _centreOffset + y2);
    }

    private function drawDate(dc as Dc) as Void {
        var width = pt(45);
        var height = pt(32);
        var x = pt(_screenSize - width - 18);
        var y = pt(_centreOffset - height/2f);

        var now = Time.now();
        var date = Time.Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dateStr = date.day;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setPenWidth(pt(4));
        dc.setColor(_tickColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, width, height);

        dc.setColor(_indexColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + width/2, y + height/2,
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
            _centreOffset, _centreOffset / 1.6,
            font, stepsStr,
            Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawHrSubdial(dc) as Void {
        var info = Activity.getActivityInfo();
        if (info == null) {
            // No point going any further
            return;
        }

        var zoneColors = [
            0xaaaaaa,
            0x0077cc,
            0x00cc00,
            0xee7700,
            0xcc0000
        ];
        if (_lowPowerMode) {
            zoneColors = [
                0x777777,
                0x0044aa,
                0x009900,
                0xbb5500,
                0x880000
            ];
        }

        var x = _centreOffset;
        var y = _centreOffset + _centreOffset / 2.8;
        var radius = pt(40);

        var startAngle = 225;
        var endAngle = -45;
        var angle = startAngle;
        var angleStep = (startAngle - endAngle) / 5;
        var gapSize = 5;

        dc.setPenWidth(2);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius+2);
        dc.setColor(_tickColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, radius);

        // Inner arc shapes
        for (var r = radius - 6; r > 25; r -= 6) {
            angle = startAngle;
            for (var i = 0; i < 10; i += 2) {
                dc.setColor(zoneColors[i/2], Graphics.COLOR_TRANSPARENT);
                dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, angle, angle - angleStep + gapSize);
                angle -= angleStep;
            }
        }
    }

    function drawHrSubdialHand(dc) {
        var info = Activity.getActivityInfo();
        if (info == null) {
            // No point going any further
            return;
        }

        var x = _centreOffset;
        var y = _centreOffset + _centreOffset / 2.8;
        var radius = pt(40);

        var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        var startAngle = 225;
        var endAngle = -45;
        var angleStep = (startAngle - endAngle) / 5;

        var zoneRanges = [
            [hrZones[0],   hrZones[1]],
            [hrZones[1]+1, hrZones[2]],
            [hrZones[2]+1, hrZones[3]],
            [hrZones[3]+1, hrZones[4]],
            [hrZones[4]+1, hrZones[5]],
        ];

        dc.setPenWidth(3);

        var hr = info.currentHeartRate;
        if (hr == null) {
            dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y, x, y + radius);
            return;
        }

        var zone = 0;
        for (var i = 0; i < 5; i += 1) {
            if (hr <= hrZones[i+1]) {
                zone = i;
                break;
            }
        }
        var zMin = zoneRanges[zone][0];
        var zMax = zoneRanges[zone][1];
        var hrNorm = (hr - zMin).toFloat() / (zMax - zMin);
        var stepRad = (angleStep/360.0) * PI2;
        var hrAngle = (hrNorm * stepRad) + (zone.toFloat() * stepRad) - stepRad + PIH;

        var hand = new Polygon(_subdialHand.points())
            .extend(-8f, $.AXIS_Y, 19f)
            .extend(-15f, $.AXIS_Y, 25f)
            .rotate(hrAngle)
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

    private function drawSecondsHand(dc as Dc) as Void {
        var time = System.getClockTime();
        var angle = (time.sec / 60f) * PI2 + Math.PI;

        var hand = new Polygon(_secondsHand.points())
            .rotate(angle)
            .translate(_centreOffset, _centreOffset);

        dc.setColor(_handColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        hand.draw(dc);
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        hand.fill(dc);

        drawPinion(dc, _centreOffset, _centreOffset, 8f);
    }
}
