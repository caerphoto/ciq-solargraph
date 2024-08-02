import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.ActivityMonitor;
import Toybox.Position;
import Toybox.Timer;
import Toybox.Time;
import Toybox.Math;

const PI2 = $.Toybox.Math.PI * 2;
const PIH = PI2 / 4;

const HOUR_HAND_LENGTH = 104f;
const MIN_HAND_LENGTH = 178f;

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

const BATTERY_DIAL_FULL_DEG = 180f;
const BATTERY_DIAL_EMPTY_DEG = 105f;
const BATTERY_DIAL_RADIUS = 90f;

const CONSTRAINED_COLOR = 0xAA0000;

const COLOR_NIGHT = 0x1A2957;
const COLOR_PREDAWN = 0x57426A; // or dusk
const COLOR_SUNRISE = 0xF5661B; // or sunset
const COLOR_MORNING = 0xADA077; // or evening
const COLOR_DAY = 0x58B8FF;

class SolargraphView extends WatchUi.WatchFace {
    private var _fakeHr as Number;
    private var _lastSunriseTime as Float?;

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

    private var _lowPowerMode as Boolean;

    private var _offscreenBuffer as BufferedBitmap?;

    private var _dialBright as BitmapResource;
    private var _dialDim as BitmapResource;
    (:initialized) private var _dial as BitmapResource;

    private var _minuteHand as BufferedBitmap;
    private var _hourHand as BufferedBitmap;

    private var _secondsHand as Polygon;

    (:initialized) private var _screenSize as Lang.Float;
    (:initialized) private var _centreOffset as Lang.Float;
    (:initialized) private var _pt as Lang.Float;

    private function pt(val as Lang.Numeric) as Float {
        return (val as Float) * _pt;
    }
    private function toRad(deg as Float) as Float {
        return (deg / 360.0) * PI2;
    }

    private function toDeg(rad as Float) as Float {
        return (rad / PI2) * 360.0;
    }

    public function initialize() {
        WatchFace.initialize();
        _fakeHr = 70;

        _bgColor = 0x000000;
        _tickColor = INDEX_DIM;

        _indexColorBright = INDEX_BRIGHT;
        _indexColorDim = INDEX_DIM;
        _indexColor = _indexColorBright;

        _handColorBright = HAND_BRIGHT;
        _handColorDim = HAND_DIM;
        _handColor = _handColorBright;

        _cardinalDay = DAY_BRIGHT;

        _pinionColor = PINION;
        _lowPowerMode = false;

        _dialBright = WatchUi.loadResource($.Rez.Drawables.DialBright) as WatchUi.BitmapResource;
        _dialDim = WatchUi.loadResource($.Rez.Drawables.DialDim) as WatchUi.BitmapResource;
        _dial = _dialBright;

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

        var points = getSecondsHandPoints();
        _secondsHand = new Polygon(points);
    }

    private function getSecondsHandPoints() as Array<Point> {
        return [
            [-1, 0],
            [0, 185],
            [1, 0],
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
        _dial = _dialDim;
        _cardinalDay = DAY_DIM;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _lowPowerMode = false;
        _handColor = _handColorBright;
        _indexColor = _indexColorBright;
        _dial = _dialBright;
        _cardinalDay = DAY_BRIGHT;
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

        if (_lastSunriseTime == null) {
            _lastSunriseTime = getSunriseTime();
        } else {
            // Only update sunrise time once an hour
            var time = System.getClockTime();
            if (time.min == 0) {
                _lastSunriseTime = getSunriseTime();
            }
        }

        drawTicks(offscreenDc);
        drawIndices(offscreenDc);
        drawBatteryDial(offscreenDc);
        drawDate(offscreenDc);
        drawSteps(offscreenDc);
        drawHrSubdial(offscreenDc);

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

    public function getSunriseTime() as Float {
        var posInfo = Position.getInfo();
        if (posInfo.accuracy == Position.QUALITY_NOT_AVAILABLE) {
            // No idea where we are, so just return 06:00
            System.println("No position info available :(");
            return 6.0;
        }

        var now = Time.now();
        var dateTime = Time.Gregorian.info(now, Time.FORMAT_SHORT);
        var startOfYear = Time.Gregorian.moment({
            :year => dateTime.year,
            :month => 1,
            :day => 1,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
        var sinceStartOfYear = now.subtract(startOfYear);
        var dayOfYear = sinceStartOfYear.value() / Time.Gregorian.SECONDS_PER_DAY;

        // Calculations are from this very informative document by NOAA
        // https://gml.noaa.gov/grad/solcalc/solareqns.PDF
        // No idea how they calculate the magic multiplier numbers.

        // 1 year = full circle; fractional year = fraction of full circle, in radians
        var fracYear = (PI2/365) * (dayOfYear + (dateTime.hour - 12)/24.0);

        // Equation of time, in minutes
        var eqTime = 229.18 * (
            0.000075 +
            0.001868 * Math.cos(fracYear) -
            0.032077 * Math.sin(fracYear) -
            0.014615 * Math.cos(2.0*fracYear) -
            0.040849 * Math.sin(2.0*fracYear)
        );

        var y  = fracYear;
        var y2 = fracYear * 2.0;
        var y3 = fracYear * 3.0;

        // Solar declination angle, in radians
        var declination = 0.006918 -
            0.399912 * Math.cos(y) +
            0.070257 * Math.sin(y) -
            0.006758 * Math.cos(y2) +
            0.000907 * Math.sin(y2) -
            0.002697 * Math.cos(y3) +
            0.00148  * Math.sin(y3);

        var utcOffset = System.getClockTime().timeZoneOffset.toFloat() / Time.Gregorian.SECONDS_PER_HOUR.toFloat();
        var latLong = posInfo.position.toDegrees();
        var latitude = latLong[0];
        var longitude = latLong[1];

        // Test values, because the simulator doesn't return correct values
        latitude = 52.5;
        longitude = 1.7;

        var zenith = 90.833; // slightly above horizon
        var zenRad = toRad(zenith);
        var latRad = toRad(latitude);
        // declination is already in radians

        var cosZen = Math.cos(zenRad);
        var coscos = Math.cos(latRad) * Math.cos(declination);
        var tantan = Math.tan(latRad) * Math.tan(declination);
        var inner = cosZen/coscos - tantan;

        var haRad = Math.acos(inner);
        var hourAngle = toDeg(haRad);
        var sunrise = 720 - 4*(longitude + hourAngle) - eqTime;

        return sunrise/60.0 + utcOffset;
    }

    // Get the appropriate colour for the fractional hour
    private function getHourColor(hour as Float) as Number {
        if (hour > 12f) {
            hour = 12f - (hour - 12f);
        }

        var hourDiff = hour - _lastSunriseTime;

        if (hourDiff < -1.5) {
            return COLOR_NIGHT;
        } else if (hourDiff < -0.5) {
            return COLOR_PREDAWN;
        } else if (hourDiff >= -0.5 && hourDiff < 0.5) {
            return COLOR_SUNRISE;
        } else if (hourDiff >= 0.5 && hourDiff < 1.5) {
            return COLOR_MORNING;
        } else {
            return COLOR_DAY;
        }
    }

    private function drawTicks(dc as Dc) as Void {
        var x1 = 0;
        var y1 = 0;
        var x2 = 0;
        var y2 = 0;
        var radius = _screenSize / 2f;

        var time = System.getClockTime();
        var hour = time.hour + time.min/60f;
        var color = getHourColor(hour);

        dc.setColor(color, _bgColor);
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
        dc.drawBitmap(0, 0, _dial);
    }

    private function drawHands(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var angleHour =   PI2 * ((clockTime.min/60f + clockTime.hour) / 24f) - PIH - Math.PI;
        var angleMinute = PI2 *  (clockTime.min/60f                 )        - PIH;

        // Hand bitmap
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

        // Hand tip
        var radius = HOUR_HAND_LENGTH - 8;
        var cosA = Math.cos(angleHour);
        var sinA = Math.sin(angleHour);
        var x1 =  radius * cosA;
        var y1 =  radius * sinA;
        var x2 = (radius + 16f) * cosA;
        var y2 = (radius + 16f) * sinA;
        dc.setColor(_bgColor, _bgColor);
        dc.setPenWidth(5);
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);

        dc.setColor(_handColor, _bgColor);
        dc.setPenWidth(3);
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);

        // Hand bitmap
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

        // Hand tip
        radius = MIN_HAND_LENGTH - 8;
        cosA = Math.cos(angleMinute);
        sinA = Math.sin(angleMinute);
        x1 =  radius * cosA;
        y1 =  radius * sinA;
        x2 = (radius + 16f) * cosA;
        y2 = (radius + 16f) * sinA;
        dc.setColor(_bgColor, _bgColor);
        dc.setPenWidth(5);
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);

        dc.setColor(_handColor, _bgColor);
        dc.setPenWidth(3);
        dc.drawLine(x1 + _centreOffset, y1 + _centreOffset, x2 + _centreOffset, y2 + _centreOffset);
    }

    private function drawPinion(dc as Dc, x as Float, y as Float, size as Float) as Void {
        dc.setColor(_pinionColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size);

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size - 2);
    }

    private function drawSubdial(
        dc as Dc,
        sectors as Number,
        colors as Array<Number>,
        arcStart as Float, arcEnd as Float, // NOTE: these values are in degrees
        reverse as Boolean,
        radius as Float
    ) as Void {
        var x = _centreOffset;
        var y = _centreOffset;

        // NOTE: arc angles are negated because drawArc assumes angles are positive in
        // counter-clockwise direction, whereas line coordinate angles assume positive is in
        // a clockwise direction.

        // Arc sectors
        dc.setPenWidth(5);
        var direction = reverse ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE;
        for (var index = 0; index < sectors; index += 1) {
            var mul = index as Float;
            var start = ((arcEnd - arcStart) / sectors as Float) * mul + arcStart;
            var end = ((arcEnd - arcStart) / sectors as Float) * (mul+1f) + arcStart;
            dc.setColor(colors[index], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, radius, direction, -start, -end);
        }

        // Sector dividers
        var sectorSize = (arcEnd - arcStart) / (sectors as Float);
        dc.setPenWidth(2);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        radius += 5; // to account for arc thickness
        for (var index = 0; index < sectors; index += 1) {
            var angle = arcStart + index * sectorSize;
            angle = (angle / 360f) * PI2;
            var x2 = radius * Math.cos(angle);
            var y2 = radius * Math.sin(angle);
            dc.drawLine(_centreOffset, _centreOffset, x + x2, y + y2);
        }
    }

    private function drawSubdialHand(
        dc as Dc,
        value as Float, // range should be 0..=1
        constrain as Boolean,
        arcStart as Float, arcEnd as Float,
        reverse as Boolean,
        radius as Float
    ) as Void {
        if (reverse) {
            value = 1.0 - value;
        }
        var constrained = false;
        if (constrain && value > 1.1) {
            constrained = true;
            value = 1.1;
        }
        if (constrain && value < -0.1) {
            constrained = true;
            value = -0.1;
        }

        var angleRange = arcEnd - arcStart;
        var angle = arcStart + (angleRange * value);
        var angleRad = (angle/360f) * PI2;

        var cosA = Math.cos(angleRad);
        var sinA = Math.sin(angleRad);

        var x1 = radius * cosA;
        var y1 = radius * sinA;
        var x2 = (radius - 20) * cosA;
        var y2 = (radius - 20) * sinA;

        var handColor = constrained ? CONSTRAINED_COLOR : _handColor;

        dc.setPenWidth(5);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_centreOffset + x1, _centreOffset + y1, _centreOffset + x2, _centreOffset + y2);
        dc.setPenWidth(3);
        dc.setColor(handColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_centreOffset + x1, _centreOffset + y1, _centreOffset + x2, _centreOffset + y2);
    }

    // Returns time in hours, in 0..24 range
    private function drawDate(dc as Dc) as Void {
        var width = pt(45);
        var height = pt(32);
        var x = pt(_screenSize - width - 13);
        var y = pt(_centreOffset - height/2f);

        var now = Time.now();
        var date = Time.Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dateStr = date.day;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, width, height);
        dc.setPenWidth(pt(3));
        dc.setColor(_tickColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, width, height, pt(6));

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
        var steps = ActivityMonitor.getInfo().steps;
        var stepsStr = "----";
        if (steps != null) {
            stepsStr = thousandsSep(steps);
        }
        dc.setColor(_cardinalDay, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centreOffset, _centreOffset - pt(80),
            Graphics.FONT_XTINY, stepsStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawBatteryDial(dc as Dc) {
        var battery = System.getSystemStats().battery / 100f;

        drawSubdial(
            dc,
            5,
            [0xAA0000, _tickColor, _cardinalDay, _cardinalDay, _cardinalDay],
            BATTERY_DIAL_EMPTY_DEG, BATTERY_DIAL_FULL_DEG, false,
            BATTERY_DIAL_RADIUS
        );

        drawSubdialHand(
            dc,
            battery,
            false, // no need to constrain since it can't be outside of bounds anyway
            BATTERY_DIAL_EMPTY_DEG, BATTERY_DIAL_FULL_DEG, false,
            BATTERY_DIAL_RADIUS
        );
    }

    private function drawHrSubdial(dc) as Void {
        var info = Activity.getActivityInfo();
        if (info == null) {
            // No point going any further
            return;
        }

        var hr = info.currentHeartRate;

        var zoneColors = [
            0xaaaaaa,
            0x0077cc,
            0x00cc00,
            0xee7700,
            0xcc0000
        ];
        if (hr == null) {
            zoneColors = [
                0x76758B,
                0x38374D,
                0x8E8DA3,
                0x5D5C72,
                0x2A293F
            ];
        } else if (_lowPowerMode) {
            zoneColors = [
                0x777777,
                0x0044aa,
                0x009900,
                0xbb5500,
                0x880000
            ];
        }

        drawSubdial(
            dc,
            5,
            zoneColors,
            75f, 0f, true,
            BATTERY_DIAL_RADIUS
        );

        if (hr == null) {
            // hr = _fakeHr;
            // _fakeHr += 1;
            return;
        }

        // DEBUG OUTPUT
        // dc.setColor(0x00ff00, Graphics.COLOR_TRANSPARENT);
        // dc.drawText(30, _centreOffset, Graphics.FONT_XTINY, hr, Graphics.TEXT_JUSTIFY_CENTER);

        var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        var zMin = hrZones[0];
        var zMax = hrZones[5];
        var hrNorm = (hr - zMin).toFloat() / (zMax - zMin);

        drawSubdialHand(
            dc,
            hrNorm,
            true,
            0f, 75f, true,
            BATTERY_DIAL_RADIUS
        );
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

        drawPinion(dc, _centreOffset, _centreOffset, 6f);
    }
}
