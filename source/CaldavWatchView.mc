using Toybox.Application;
using Toybox.UserProfile;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Time;
using Toybox.ActivityMonitor;

class CaldavWatchView extends WatchUi.WatchFace {

    var dayEvents as Lang.Dictionary;
    var yearEvents as Lang.Dictionary;
    var lastRenderedMinute;

    // bitmaps
    var yearWheel;
    var rings;
    var alphaWheel;
    var heartIcon;
    var stepsIcon;
    var stairsIcon;
    var caloriesIcon;
    var bluetoothIcon;

    var offScreenBuffer;

    // Constants
    const heartRateColors = [
        Graphics.COLOR_BLACK,
        Graphics.COLOR_DK_GRAY,
        Graphics.COLOR_DK_BLUE,
        Graphics.COLOR_DK_GREEN,
        Graphics.COLOR_ORANGE,
        Graphics.COLOR_RED
    ];

    const twelveHours = new Time.Duration(12 * Time.Gregorian.SECONDS_PER_HOUR);
    const daysPerMonth = [
        31,
        28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31
    ];

    const screenRadius = System.getDeviceSettings().screenWidth / 2;
    const onePercentWidth = self.screenRadius * 2 / 100.0;
    const ringWidth = 10 * self.onePercentWidth;
    const yearRingRadius = self.screenRadius - self.ringWidth * 0.5;
    const eventRingRadius = self.screenRadius - self.ringWidth * 1.5;

    function initialize() {
        WatchFace.initialize();
        self.dayEvents = Application.Storage.getValue("dayEvents");
        if (self.dayEvents == null) {
            self.dayEvents = {
                "timeEvents" => [],
                "dateEvents" => []
            };
        }
        self.yearEvents = Application.Storage.getValue("yearEvents");
        if (self.yearEvents == null) {
            self.yearEvents = {
                "timeEvents" => [],
                "dateEvents" => []
            };
        }
    }

    // Load your resources here
    function onLayout(dc as Graphics.Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        self.lastRenderedMinute = null;

        self.yearWheel = WatchUi.loadResource(Rez.Drawables.YearWheel);
        self.rings = WatchUi.loadResource(Rez.Drawables.Rings);
        self.alphaWheel = WatchUi.loadResource(Rez.Drawables.AlphaWheel);
        self.heartIcon = WatchUi.loadResource(Rez.Drawables.Heart);
        self.stepsIcon = WatchUi.loadResource(Rez.Drawables.Steps);
        self.stairsIcon = WatchUi.loadResource(Rez.Drawables.Stairs);
        self.caloriesIcon = WatchUi.loadResource(Rez.Drawables.Calories);
        self.bluetoothIcon = WatchUi.loadResource(Rez.Drawables.Bluetooth);

        self.offScreenBuffer = new Graphics.BufferedBitmap({
            :width => self.screenRadius * 2,
            :height => self.screenRadius * 2
        });
    }

    function convertClockToArcAngle(clockAngle as Lang.Float) as Lang.Float {
        var counterClockAngle = 720 - clockAngle;
        return counterClockAngle + 90;
    }

    function clamp(value as Lang.Numeric, minValue as Lang.Numeric, maxValue as Lang.Numeric) as Lang.Numeric {
        var clampedValue = value;
        if (clampedValue > maxValue) {
            clampedValue = maxValue;
        } else if (clampedValue < minValue) {
            clampedValue = minValue;
        }
        return clampedValue;
    }

    function drawRadialLine(dc as Graphics.Dc, innerRadius as Lang.Numeric, outerRadius as Lang.Numeric, angle as Lang.Numeric) as Void {
        var xScaled = Math.sin(angle);
        var yScaled = Math.cos(angle);

        dc.drawLine(Math.round(self.screenRadius + innerRadius * xScaled),
                    Math.round(self.screenRadius - innerRadius * yScaled),
                    Math.round(self.screenRadius + outerRadius * xScaled),
                    Math.round(self.screenRadius - outerRadius * yScaled));
    }

    function drawBitmap(dc as Graphics.Dc, xPos as Lang.Numeric, yPos as Lang.Numeric, bitmap as WatchUi.BitmapResource) as Void {
        var bitmapWidth = bitmap.getWidth();
        var bitmapHeight = bitmap.getHeight();
        var xBitmap = xPos - bitmapWidth/2.0;
        var yBitmap = yPos - bitmapHeight/2.0;

        dc.drawBitmap(Math.round(xBitmap), Math.round(yBitmap), bitmap);
    }

    function drawText(dc as Graphics.Dc, xPos as Lang.Numeric, yPos as Lang.Numeric, font, text as Lang.String) as Void {
        dc.drawText(Math.round(xPos), Math.round(yPos), font, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawActivity(dc as Graphics.Dc, xPos as Lang.Numeric, yPos as Lang.Numeric, bitmap as WatchUi.BitmapResource, text) as Void {
        drawBitmap(dc, xPos, yPos - 3 * self.onePercentWidth, bitmap);
        drawText(dc, xPos, yPos + 3 * self.onePercentWidth, Graphics.FONT_XTINY, text == null ? "--" : text);
    }

    function drawBattery(dc as Graphics.Dc, xPos as Lang.Numeric, yPos as Lang.Numeric) as Void {
        var penWidth = Math.round(self.onePercentWidth);

        var width = 14 * self.onePercentWidth;
        var height = 8.5 * self.onePercentWidth;
        var roundWidth = Math.round(width);
        var roundHeight = Math.round(height);
        var xOrigin = Math.round(xPos - width/2);
        var yOrigin = Math.round(yPos - height/2);

        var batteryPercentage = System.getSystemStats().battery.toNumber();
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xOrigin, yOrigin, Math.round(width * (batteryPercentage/100.0)) + 1, roundHeight + 1);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        dc.drawRoundedRectangle(xOrigin, yOrigin, roundWidth + 1, roundHeight + 1, penWidth);
        dc.drawLine(xOrigin + roundWidth + penWidth, yOrigin + Math.round(height * 0.25),
                    xOrigin + roundWidth + penWidth, yOrigin + Math.round(height * 0.75));

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawText(dc, xPos, yPos, Graphics.FONT_XTINY, timeToString(batteryPercentage) + "%");
    }

    function drawHeartRate(dc as Graphics.Dc, xPos as Lang.Numeric, yPos as Lang.Numeric) as Void {
        var heartRate = Activity.getActivityInfo().currentHeartRate;
        if (heartRate == null) {
            var heartRateItem = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (heartRateItem != null && heartRateItem.heartRate != ActivityMonitor.INVALID_HR_SAMPLE && Time.now().compare(heartRateItem.when) < 60) {
                heartRate = heartRateItem.heartRate;
            }
        }

        var text = null;
        var color = Graphics.COLOR_DK_RED;
        if (heartRate != null) {
            var heartRateZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            for (var heartRateZoneIdx = 0; heartRateZoneIdx < heartRateZones.size(); heartRateZoneIdx++) {
                if (heartRate < heartRateZones[heartRateZoneIdx]) {
                    color = heartRateColors[heartRateZoneIdx];
                    break;
                }
            }
            text = heartRate.toString();
        }

        var bitmapWidth = self.heartIcon.getWidth();
        var bitmapHeight = self.heartIcon.getHeight();
        var xBitmap = Math.round(xPos - bitmapWidth/2);
        var yBitmap = Math.round(yPos + 0.5*onePercentWidth - bitmapHeight/2);

        if (text != null) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xBitmap, yBitmap, bitmapWidth, bitmapHeight);
        }

        dc.drawBitmap(xBitmap, yBitmap, self.heartIcon);

        if (text != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, xPos, yPos, Graphics.FONT_XTINY, text);
        }
    }

    function drawArc(dc as Graphics.Dc,
                     radius as Lang.Float, thickness as Lang.Float,
                     startAngle as Lang.Float, renderStart as Lang.Boolean,
                     endAngle as Lang.Float, renderEnd as Lang.Boolean,
                     color as Lang.Number) as Void {

        var innerRadius = radius - thickness / 2;
        var outerRadius = innerRadius + thickness;

        var drawArcs = endAngle - startAngle > 1;
        var startArcAngle = convertClockToArcAngle(startAngle);
        var endArcAngle = convertClockToArcAngle(endAngle);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(thickness);
        if (drawArcs) {
            dc.drawArc(self.screenRadius, self.screenRadius, radius, Graphics.ARC_CLOCKWISE,
                       startArcAngle,
                       endArcAngle);

        }

        // draw lines
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (renderStart) {
            drawRadialLine(dc, innerRadius + 1, outerRadius - 1, startAngle / 180 * Math.PI);
        }
        if (renderEnd) {
            drawRadialLine(dc, innerRadius + 1, outerRadius - 1, endAngle / 180 * Math.PI);
        }
        if (drawArcs) {
            dc.drawArc(self.screenRadius, self.screenRadius, outerRadius, Graphics.ARC_CLOCKWISE,
                       startArcAngle,
                       endArcAngle);
        }
    }

    function unixTimeToAngle(unixTime as Lang.Numeric, twelveOClock as Time.Moment) as Lang.Float {
        return ((unixTime - twelveOClock.value()).toFloat() / self.twelveHours.value()) * 360;
    }

    function drawEventRing(dc as Graphics.Dc, radius as Lang.Numeric, now as Time.Moment) as Void {
        var twelveOClock = Time.today();
        var timeSinceMidnight = now.subtract(twelveOClock) as Time.Duration;
        if (timeSinceMidnight.greaterThan(self.twelveHours)) {
            twelveOClock = twelveOClock.add(twelveHours);
        }

        var minUnix = now.value();
        var maxUnix = minUnix + self.twelveHours.value() - Time.Gregorian.SECONDS_PER_MINUTE * 30;

        var minAngle = unixTimeToAngle(minUnix, twelveOClock);

        // Draw events
        var arcsToRender = [];

        var allDayEventCount = 0;
        var lastAllDayCalendarIndex = -1;
        var timeEvents = self.dayEvents.get("timeEvents") as Lang.Array;

        for (var eventIdx = 0; eventIdx < timeEvents.size(); eventIdx++) {
            var event = timeEvents[eventIdx];

            var startTime = clamp(event["startTime"], minUnix, maxUnix);
            var endTime = clamp(event["endTime"], minUnix, maxUnix);
            if (startTime == endTime) {
                continue;
            }
            var startAngle = unixTimeToAngle(startTime, twelveOClock);
            var endAngle = unixTimeToAngle(endTime, twelveOClock);

            var arcRadius;
            var arcThickness;
            var level = event["level"];
            if (level > 4) {
                level = 4;
            }
            arcRadius = radius - level * 1 * onePercentWidth;
            arcThickness = self.ringWidth - level * 2 * onePercentWidth;

            var renderEnd = endTime != maxUnix;
            if (startAngle - minAngle > 300) {
                drawArc(dc, arcRadius, arcThickness,
                        startAngle, true, endAngle, renderEnd,
                        event["color"]);
            } else {
                if (endAngle - minAngle > 300) {
                    drawArc(dc, arcRadius, arcThickness,
                            minAngle + 300.0f, false, endAngle, renderEnd,
                            event["color"]);
                }

                arcsToRender.add({
                    "startDegree" => startAngle,
                    "endDegree" => endAngle,
                    "event" => event,
                    "radius" => arcRadius,
                    "thickness" => arcThickness
                });
            }
        }

        var alphaAngle = (minAngle - 15) / 180 * Math.PI;

        var xAlpha = self.screenRadius + radius * Math.sin(alphaAngle);
        var yAlpha = self.screenRadius - radius * Math.cos(alphaAngle);
        drawBitmap(dc, xAlpha, yAlpha, self.alphaWheel);

        for (var arcIdx = 0; arcIdx < arcsToRender.size(); arcIdx++) {
            var arc = arcsToRender[arcIdx];

            var startAngle = arc["startDegree"];
            var endAngle = arc["endDegree"];
            var event = arc["event"];
            var arcRadius = arc["radius"];
            var arcThickness = arc["thickness"];

            if (endAngle - minAngle > 300) {
                drawArc(dc, arcRadius, arcThickness,
                        startAngle, true, minAngle + 300.0f, false,
                        event["color"]);
            } else {
                drawArc(dc, arcRadius, arcThickness,
                        startAngle, true, endAngle, true,
                        event["color"]);
            }
        }
    }


    function timeToString(time as Lang.Number) as Lang.String {
        var string = time.toString();
        if (string.length() == 1) {
            string = "0" + string;
        }
        return string;
    }

    function drawNextAlarmEvent(dc as Graphics.Dc) as Void {
        var timeEvents = self.dayEvents.get("timeEvents") as Lang.Array;

        var earliestAlarmEventIdx = -1;
        for (var eventIdx = 0; eventIdx < timeEvents.size(); eventIdx++) {
            var event = timeEvents[eventIdx];
            if (event["hasAlarm"] && event["startTime"] > Time.now().value() - 60*10) {
                if (earliestAlarmEventIdx == -1) {
                    earliestAlarmEventIdx = eventIdx;
                } else if (event["startTime"] < timeEvents[earliestAlarmEventIdx]["startTime"]) {
                    earliestAlarmEventIdx = eventIdx;
                }
            }
        }

        if (earliestAlarmEventIdx == -1) {
            return;
        }

        var event = timeEvents[earliestAlarmEventIdx];
        var eventGregorian = Time.Gregorian.info(new Time.Moment(event["startTime"]), Time.FORMAT_SHORT);

        var summary = event["summary"];
        if (summary.length() > 15) {
            summary = summary.substring(0, 14) + "..";
        }

        var minute = eventGregorian.min.toString();
        if (minute.length() == 1) {
            minute = "0" + minute;
        }

        drawText(dc, self.screenRadius, self.screenRadius - onePercentWidth*23,
                 Graphics.FONT_XTINY, timeToString(eventGregorian.hour) + ":" + timeToString(eventGregorian.min));
        drawText(dc, self.screenRadius, self.screenRadius - onePercentWidth*16.5,
                 Graphics.FONT_XTINY, summary);
        if (event["location"] != null) {
            var location = event["location"];
            if (location.length() > 17) {
                location = location.substring(0, 16) + "..";
            }
            drawText(dc, self.screenRadius, self.screenRadius - onePercentWidth*10,
                     Graphics.FONT_XTINY, location);
        }
    }

    function dateToAngle(date as Time.Gregorian.Info) as Lang.Float {
        var zeroBasedMonth = (date.month as Lang.Number) - 1;
        var zeroBasedDate = zeroBasedMonth + (date.day - 1.0f) / self.daysPerMonth[zeroBasedMonth];
        return (zeroBasedDate/12) * (2*Math.PI);
    }

    function drawYearRing(dc as Graphics.Dc, now as Time.Gregorian.Info) as Void {
        var lastAllDayCalendarIndex = -1;
        var allDayColors = [];
        var dateEvents = self.dayEvents.get("dateEvents") as Lang.Array;

        for (var eventIdx = 0; eventIdx < dateEvents.size(); eventIdx++) {
            var event = dateEvents[eventIdx];
            var calendarIndex = event["calendarIndex"];
            if (event["allDay"] && calendarIndex != lastAllDayCalendarIndex) {
                allDayColors.add(event["color"]);
                lastAllDayCalendarIndex = calendarIndex;
            }
        }

        if (allDayColors.size() == 0) {
            allDayColors.add(0);
        }

        // Draw year ring
        dc.drawBitmap(0, 0, self.yearWheel);

        // draw month day
        var todayAngle = dateToAngle(now);

        var xValue = self.screenRadius - yearRingRadius * Math.sin(todayAngle);
        var yValue = self.screenRadius - yearRingRadius * Math.cos(todayAngle);

        var arcRadius = Math.round(self.ringWidth * 0.22);
        var arcThickness = arcRadius * 2;
        dc.setPenWidth(Math.round(arcThickness));
        var arcAngle = Math.round(360 / allDayColors.size());
        for (var colorIdx = 0; colorIdx < allDayColors.size(); colorIdx++) {
            var startDegree = colorIdx * arcAngle;
            var endDegree = startDegree + arcAngle;
            dc.setColor(allDayColors[colorIdx], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(Math.round(xValue), Math.round(yValue), arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, startDegree, endDegree);
        }

        var yearDateEvents = self.yearEvents.get("dateEvents") as Lang.Array;
        for (var eventIdx = 0; eventIdx < yearDateEvents.size(); eventIdx++) {
            var event = yearDateEvents[eventIdx];
            var startDate = event["startDate"];
            var eventMoment = Time.Gregorian.moment({
                :year => startDate["year"],
                :month => startDate["month"] + 1,
                :day => startDate["day"]
            });
            var eventAngle = dateToAngle(Time.Gregorian.info(eventMoment, Time.FORMAT_SHORT));

            dc.setPenWidth(2);
            dc.setColor(event["color"], Graphics.COLOR_TRANSPARENT);
            drawRadialLine(dc, self.screenRadius - self.ringWidth * 0.5, self.screenRadius, -eventAngle);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawText(dc, xValue, yValue, Graphics.FONT_TINY, timeToString(now.day));
    }

    function draw(dc as Graphics.Dc, now as Time.Gregorian.Info, roundedNow as Time.Moment) as Void {
        View.onUpdate(dc);

        dc.setAntiAlias(true);

        drawEventRing(dc, self.eventRingRadius, roundedNow);
        drawYearRing(dc, now);


        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawNextAlarmEvent(dc);

        var xOffsetMiddleRow = 16 * self.onePercentWidth;
        drawBattery(dc, self.screenRadius - xOffsetMiddleRow, self.screenRadius);

        var yBottomRow = self.screenRadius + 13 * self.onePercentWidth;
        var xOffsetBottomRow = 13 * self.onePercentWidth;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawBitmap(dc, self.screenRadius - xOffsetBottomRow, yBottomRow, stepsIcon);
        drawBitmap(dc, self.screenRadius,                    yBottomRow, stairsIcon);
        drawBitmap(dc, self.screenRadius + xOffsetBottomRow, yBottomRow, caloriesIcon);

        if (System.getDeviceSettings().phoneConnected) {
            drawBitmap(dc, self.screenRadius, self.screenRadius, bluetoothIcon);
        }
    }

    // Update the view
    function onUpdate(dc as Graphics.Dc) as Void {
        var now = Time.now();
        var gregorianNow = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeSinceLast5Minutes = new Time.Duration((gregorianNow.min % 5) * 60 + gregorianNow.sec);
        var roundedNow = now.subtract(timeSinceLast5Minutes as Time.Duration) as Time.Moment;

        var currentMinute = gregorianNow.min;
        if (self.lastRenderedMinute == null || (self.lastRenderedMinute != currentMinute && currentMinute % 5 == 0)) {
            draw(self.offScreenBuffer.getDc(), gregorianNow, roundedNow);
            self.lastRenderedMinute = currentMinute;
        }

        dc.drawBitmap(0, 0, self.offScreenBuffer);

        // draw minute
        {
            var angle = (roundedNow.subtract(Time.today()).value().toFloat() / self.twelveHours.value()) * (2*Math.PI);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, self.screenRadius + self.eventRingRadius * Math.sin(angle),
                         self.screenRadius - self.eventRingRadius * Math.cos(angle),
                         Graphics.FONT_TINY, timeToString(gregorianNow.min));
        }
        dc.drawBitmap(0, 0, self.rings);

        var xOffsetMiddleRow = 16 * self.onePercentWidth;
        drawHeartRate(dc, self.screenRadius + xOffsetMiddleRow, self.screenRadius);

        var yBottomRow = self.screenRadius + 19 * self.onePercentWidth;
        var xOffsetBottomRow = 13 * self.onePercentWidth;
        var activity = ActivityMonitor.getInfo();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        var text = activity.steps;
        drawText(dc, self.screenRadius - xOffsetBottomRow, yBottomRow, Graphics.FONT_XTINY, text == null ? "--" : text);
        text = activity.floorsClimbed;
        drawText(dc, self.screenRadius                   , yBottomRow, Graphics.FONT_XTINY, text == null ? "--" : text);
        text = activity.calories;
        drawText(dc, self.screenRadius + xOffsetBottomRow, yBottomRow, Graphics.FONT_XTINY, text == null ? "--" : text);

    }

    function convertColors(events) {
        for (var eventIdx = 0; eventIdx < events.size(); eventIdx++) {
            var event = events[eventIdx];
            var color = event["color"];
            event["color"] = ((color["blue"]*0.8).toNumber() +
                             ((color["green"]*0.8).toNumber() << 8) +
                             ((color["red"]*0.8).toNumber() << 16));
        }
    }

    function onBackgroundData(data) {
        var type = data["type"];
        if (type.equals("yearEvents") || type.equals("dayEvents")) {
            var events = data["events"];
            convertColors(events["timeEvents"]);
            convertColors(events["dateEvents"]);

            var now = Time.now().value();
            if (type.equals("dayEvents")) {
                self.dayEvents = events;
                Application.Storage.setValue("dayEvents", events);
                Application.Storage.setValue("dayEventsRetrieved", now);
            } else {
                self.yearEvents = events;
                Application.Storage.setValue("yearEvents", events);
                Application.Storage.setValue("yearEventsRetrieved", now);
            }
        } else {
            System.println(data["responseCode"] + ": " + data);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        self.yearWheel = null;
        self.rings = null;
        self.alphaWheel = null;
        self.heartIcon = null;
        self.stepsIcon = null;
        self.stairsIcon = null;
        self.caloriesIcon = null;
        self.bluetoothIcon = null;

        self.offScreenBuffer = null;
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }
}
