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
    var weekEvents as Lang.Dictionary;
    var yearEvents as Lang.Dictionary;
    var lastRenderedMinute;

    // bitmaps
    var yearWheel;
    var alphaWheel;
    var heartIcon;
    var stepsIcon;
    var stairsIcon;
    var caloriesIcon;
    var bluetoothIcon;
    var houseIcon;

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

    const weekDayLetters = [
        "Z",
        "M",
        "D",
        "W",
        "D",
        "V",
        "Z"
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
    const ringWidth = 5 * self.onePercentWidth;
    const yearRingRadius = self.screenRadius - self.ringWidth * 0.5;
    const weekRingRadius = self.yearRingRadius - self.ringWidth * 1 - 2;
    const eventRingRadius = self.weekRingRadius - self.ringWidth * 1.5 - 2;

    function initialize() {
        WatchFace.initialize();
        self.dayEvents = Application.Storage.getValue("dayEvents");
        if (self.dayEvents == null) {
            self.dayEvents = {
                "timeEvents" => [],
                "dateEvents" => []
            };
        }
        self.weekEvents = Application.Storage.getValue("weekEvents");
        if (self.weekEvents == null) {
            self.weekEvents = {
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

    function onLayout(dc as Graphics.Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    function onShow() as Void {
        self.lastRenderedMinute = null;

        self.yearWheel = WatchUi.loadResource(Rez.Drawables.YearWheel);
        self.alphaWheel = WatchUi.loadResource(Rez.Drawables.AlphaWheel);
        self.heartIcon = WatchUi.loadResource(Rez.Drawables.Heart);
        self.stepsIcon = WatchUi.loadResource(Rez.Drawables.Steps);
        self.stairsIcon = WatchUi.loadResource(Rez.Drawables.Stairs);
        self.caloriesIcon = WatchUi.loadResource(Rez.Drawables.Calories);
        self.bluetoothIcon = WatchUi.loadResource(Rez.Drawables.Bluetooth);
        self.houseIcon = WatchUi.loadResource(Rez.Drawables.House);

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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
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
            arcThickness = self.ringWidth * 2.0 - level * 2 * onePercentWidth;

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
        if (summary.length() > 14) {
            summary = summary.substring(0, 13) + "..";
        }

        var minute = eventGregorian.min.toString();
        if (minute.length() == 1) {
            minute = "0" + minute;
        }

        drawText(dc, self.screenRadius, self.screenRadius - onePercentWidth*22,
                 Graphics.FONT_XTINY, timeToString(eventGregorian.hour) + ":" + timeToString(eventGregorian.min));
        drawText(dc, self.screenRadius, self.screenRadius - onePercentWidth*16,
                 Graphics.FONT_XTINY, summary);
        if (event["location"] != null) {
            var location = event["location"];
            if (location.length() > 15) {
                location = location.substring(0, 14) + "..";
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

    function dateToMoment(date as Lang.Dictionary) as Time.Moment {
        return Time.Gregorian.moment({
            :year => date["year"],
            :month => date["month"] + 1,
            :day => date["day"]
        });
    }

    function drawYearRing(dc as Graphics.Dc, radius as Lang.Numeric, now as Time.Gregorian.Info) as Void {
        var yearRingWidth = self.ringWidth;

        var lastAllDayCalendarIndex = -1;
        var allDayColors = [];
        var dateEvents = self.dayEvents.get("dateEvents") as Lang.Array;

        var nowMoment = Time.now();
        for (var eventIdx = 0; eventIdx < dateEvents.size(); eventIdx++) {
            var event = dateEvents[eventIdx];
            var startMoment = dateToMoment(event["startDate"]);
            var endMoment = dateToMoment(event["endDate"]);

            var calendarIndex = event["calendarIndex"];
            if (calendarIndex != lastAllDayCalendarIndex &&
                nowMoment.compare(startMoment) >= 0 && nowMoment.compare(endMoment) <= 0) {

                allDayColors.add(event["color"]);
                lastAllDayCalendarIndex = calendarIndex;
            }
        }

        if (allDayColors.size() == 0) {
            allDayColors.add(Graphics.COLOR_DK_GRAY);
        }

        // Draw year ring
        dc.drawBitmap(0, 0, self.yearWheel);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(yearRingWidth);
        dc.drawCircle(self.screenRadius, self.screenRadius, self.screenRadius - yearRingWidth * 1.5);

        // draw month day
        var todayAngle = dateToAngle(now);

        var xValue = self.screenRadius - radius * Math.sin(todayAngle);
        var yValue = self.screenRadius - radius * Math.cos(todayAngle);

        var arcRadius = Math.round(yearRingWidth * 0.4);
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
            var eventAngle = dateToAngle(Time.Gregorian.info(dateToMoment(startDate), Time.FORMAT_SHORT));

            dc.setPenWidth(2);
            dc.setColor(event["color"], Graphics.COLOR_TRANSPARENT);
            drawRadialLine(dc, self.screenRadius - yearRingWidth, self.screenRadius, -eventAngle);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawText(dc, xValue, yValue, Graphics.FONT_XTINY, timeToString(now.day));

    }

    function startOfDay(unix as Lang.Number) as Lang.Number {
        var gregorian = Time.Gregorian.info(new Time.Moment(unix), Time.FORMAT_SHORT);
        return Time.Gregorian.moment({
            :year => gregorian.year,
            :month => gregorian.month,
            :day => gregorian.day,
            :hour => 0,
            :minute => 0,
            :second => 0
        }).value();
    }

    function weekUnixTimeToAngle(unix as Lang.Number, wakeTime as Lang.Number, awakeDuration as Lang.Number, now as Time.Gregorian.Info, todayUnix as Lang.Number) as Lang.Float {
        var dayStartUnix = startOfDay(unix);
        var daysUntil = Math.round((dayStartUnix - todayUnix) / Time.Gregorian.SECONDS_PER_DAY.toFloat());

        var secondsSinceDayStart = unix - dayStartUnix;
        var secondsAwake = clamp(secondsSinceDayStart - wakeTime, 0, awakeDuration);

        return (daysUntil - 1) * 30 + (secondsAwake.toFloat() / awakeDuration) * 30;
    }

    function julianDay(year, month, day) {
        var a = (14 - month) / 12;
        var y = (year + 4800 - a);
        var m = (month + 12 * a - 3);
        return day + ((153 * m + 2) / 5) + (365 * y) + (y / 4) - (y / 100) + (y / 400) - 32045;
    }

    function isLeapYear(year) {
        if (year % 4 != 0) {
            return false;
        } else if (year % 100 != 0) {
            return true;
        } else if (year % 400 == 0) {
            return true;
        }
        return false;
    }

    function isoWeekNumber(day, month, year) {
        var firstDayOfYear = julianDay(year, 1, 1);
        var nowDayOfYear = julianDay(year, month, day);

        var dayOfWeek = (firstDayOfYear + 3) % 7; // days past thursday
        var weekOfYear = (nowDayOfYear - firstDayOfYear + dayOfWeek + 4) / 7;

        // week is at end of this year or the beginning of next year
        if (weekOfYear == 53) {
            if (dayOfWeek == 6) {
                return weekOfYear;
            } else if (dayOfWeek == 5 && isLeapYear(year)) {
                return weekOfYear;
            } else {
                return 1;
            }
        } else if (weekOfYear == 0) { // week is in previous year, try again under that year
            firstDayOfYear = julianDay(year - 1, 1, 1);

            dayOfWeek = (firstDayOfYear + 3) % 7;

            return (nowDayOfYear - firstDayOfYear + dayOfWeek + 4) / 7;
        } else { // any old week of the year
            return weekOfYear;
        }
    }

    function nextWeekNumber(weekNumber as Lang.Number, now as Time.Gregorian.Info) {
        if (weekNumber == 53) {
            return 1;
        }

        if (weekNumber == 52) {
            var lastWeekNumber = isoWeekNumber(31, 12, now.year);
            if (lastWeekNumber == weekNumber) {
                return 1;
            }
        }

        return weekNumber + 1;
    }

    function drawWeekRing(dc as Graphics.Dc, radius as Lang.Numeric, now as Time.Gregorian.Info) as Void {
        var weekRingWidth = self.ringWidth;

        var weekNumber = isoWeekNumber(now.day, now.month, now.year);
        var weekNumberPlusOne = nextWeekNumber(weekNumber, now);
        var weekNumberPlusTwo = nextWeekNumber(weekNumberPlusOne, now);

        var weekTimeEvents = self.weekEvents.get("timeEvents") as Lang.Array;

        var profile = UserProfile.getProfile();
        var sleepTime = profile.sleepTime.value();
        var wakeTime = profile.wakeTime.value();
        var awakeSeconds = sleepTime - wakeTime;

        var todayUnix = Time.today().value();
        var tomorrowUnix = startOfDay(todayUnix + (Time.Gregorian.SECONDS_PER_DAY * 1.5).toNumber()); // 1.5, to avoid DST nonsense
        var inTwelveDaysUnix = startOfDay(todayUnix + (Time.Gregorian.SECONDS_PER_DAY * 11.5).toNumber()); // 11.5, to avoid DST nonsense

        dc.setPenWidth(weekRingWidth);
        for (var eventIdx = 0; eventIdx < weekTimeEvents.size(); eventIdx++) {
            var event = weekTimeEvents[eventIdx];
            var startUnix = clamp(event["startTime"], tomorrowUnix, inTwelveDaysUnix + sleepTime);
            var endUnix = clamp(event["endTime"], tomorrowUnix, inTwelveDaysUnix + sleepTime);

            if (startUnix >= endUnix) {
                continue;
            }

            var startAngle = weekUnixTimeToAngle(startUnix, wakeTime, awakeSeconds, now, todayUnix);
            var endAngle = weekUnixTimeToAngle(endUnix, wakeTime, awakeSeconds, now, todayUnix);

            if (startAngle >= endAngle) {
                continue;
            }

            dc.setColor(event["color"], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(self.screenRadius, self.screenRadius, radius,
                       Graphics.ARC_CLOCKWISE,
                       convertClockToArcAngle(startAngle),
                       convertClockToArcAngle(endAngle));
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var dayOffset = 0; dayOffset < 11; dayOffset++) {
            var weekDay = (now.day_of_week + dayOffset) % 7;
            var angle = (dayOffset * 30 + 4) / 180.0 * Math.PI;
            drawText(dc, self.screenRadius + Math.round(radius * Math.sin(angle)),
                         self.screenRadius - Math.round(radius * Math.cos(angle)),
                         Graphics.FONT_XTINY, weekDayLetters[weekDay]);
        }

        var daysTillMonday = 8 - now.day_of_week;
        if (daysTillMonday > 6) {
            daysTillMonday -= 7;
        }

        {
            var angle = -23 / 180.0 * Math.PI;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, self.screenRadius + Math.round(radius * Math.sin(angle)),
                        self.screenRadius - Math.round(radius * Math.cos(angle)),
                        Graphics.FONT_XTINY, weekNumber.toString());

            dc.setPenWidth(1.5);
            dc.drawArc(self.screenRadius, self.screenRadius, Math.round(radius)-1, Graphics.ARC_CLOCKWISE, 110, 95);

            angle = -5 / 180.0 * Math.PI;
            var backAngle = -8 / 180.0 * Math.PI;
            var x = self.screenRadius + Math.round(radius * Math.sin(angle));
            var y = self.screenRadius - Math.round(radius * Math.cos(angle));
            dc.drawLine(x, y,
                        self.screenRadius + Math.round((radius + 3) * Math.sin(backAngle)),
                        self.screenRadius - Math.round((radius + 3) * Math.cos(backAngle)));
            dc.drawLine(x, y,
                        self.screenRadius + Math.round((radius - 3) * Math.sin(backAngle)),
                        self.screenRadius - Math.round((radius - 3) * Math.cos(backAngle)));

        }

        {
            var angle = (daysTillMonday * 30) / 180.0 * Math.PI;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, self.screenRadius + Math.round(radius * Math.sin(angle)),
                        self.screenRadius - Math.round(radius * Math.cos(angle)),
                        Graphics.FONT_XTINY, weekNumberPlusOne.toString());
        }

        if (daysTillMonday < 4) {
            var angle = ((daysTillMonday + 7) * 30) / 180.0 * Math.PI;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, self.screenRadius + Math.round(radius * Math.sin(angle)),
                        self.screenRadius - Math.round(radius * Math.cos(angle)),
                        Graphics.FONT_XTINY, weekNumberPlusTwo.toString());
        }
    }

    function drawRings(dc as Graphics.Dc) as Void {
        var tickAngle = 30.0 / 180.0 * Math.PI;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        for (var tickIndex = 0; tickIndex < 12; ++tickIndex) {
            var angle = tickIndex * tickAngle;
            var xScaled = Math.sin(angle);
            var yScaled = Math.cos(angle);

            var radius = self.yearRingRadius - self.ringWidth * 0.5 - 1.5;
            dc.fillCircle(Math.round(self.screenRadius + xScaled * radius),
                          Math.round(self.screenRadius - yScaled * radius), 1.5);
            radius = self.weekRingRadius - self.ringWidth * 0.5 - 1;
            dc.fillCircle(Math.round(self.screenRadius + xScaled * radius),
                          Math.round(self.screenRadius - yScaled * radius), 1.5);
            if (tickIndex % 6 != 0) {
                radius = self.eventRingRadius - self.ringWidth - 1;
                dc.fillCircle(Math.round(self.screenRadius + xScaled * radius),
                              Math.round(self.screenRadius - yScaled * radius), 1.5);
            }
        }
        var radius = self.eventRingRadius - self.ringWidth;
        dc.setPenWidth(2);
        dc.drawCircle(self.screenRadius, self.screenRadius - radius, 3);
        dc.drawCircle(self.screenRadius, self.screenRadius + radius, 3);
    }

    function draw(dc as Graphics.Dc, gregorianNow as Time.Gregorian.Info, now as Time.Moment) as Void {
        View.onUpdate(dc);

        dc.setAntiAlias(true);

        drawEventRing(dc, self.eventRingRadius, now);
        drawYearRing(dc, self.yearRingRadius, gregorianNow);
        drawWeekRing(dc, self.weekRingRadius, gregorianNow);

        drawRings(dc);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawNextAlarmEvent(dc);

        var xOffsetMiddleRow = 16 * self.onePercentWidth;
        drawBattery(dc, self.screenRadius - xOffsetMiddleRow, self.screenRadius);

        var yBottomRow = self.screenRadius + 11 * self.onePercentWidth;
        var xOffsetBottomRow = 14 * self.onePercentWidth;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawBitmap(dc, self.screenRadius - xOffsetBottomRow, yBottomRow, stairsIcon);
        drawBitmap(dc, self.screenRadius,                    yBottomRow, stepsIcon);
        drawBitmap(dc, self.screenRadius + xOffsetBottomRow, yBottomRow, caloriesIcon);

        if (System.getDeviceSettings().phoneConnected) {
            drawBitmap(dc, self.screenRadius, self.screenRadius, bluetoothIcon);
        }
    }

    // Update the view
    function onUpdate(dc as Graphics.Dc) as Void {
        var now = Time.now();
        var gregorianNow = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var currentMinute = gregorianNow.min;
        if (self.lastRenderedMinute == null || (self.lastRenderedMinute != currentMinute && currentMinute % 5 == 0)) {
            draw(self.offScreenBuffer.getDc(), gregorianNow, now);
            self.lastRenderedMinute = currentMinute;
        }

        dc.drawBitmap(0, 0, self.offScreenBuffer);

        // draw minute
        {
            var minute = gregorianNow.min - gregorianNow.min % 5;
            var angle = ((gregorianNow.hour % 12) * 30 + minute * 0.5) / 180 * Math.PI;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawText(dc, self.screenRadius + self.eventRingRadius * Math.sin(angle),
                         self.screenRadius - self.eventRingRadius * Math.cos(angle),
                         Graphics.FONT_TINY, timeToString(gregorianNow.min));
        }

        var homeLatitude = Application.Properties.getValue("HomeLatitude") as Lang.Float;
        var homeLongitude = Application.Properties.getValue("HomeLongitude") as Lang.Float;
        var location = new Position.Location({
            :latitude => homeLatitude,
            :longitude => homeLongitude,
            :format => :degrees
        });
        var homeNow = Time.Gregorian.localMoment(location, now.value());
        var gregorianHomeNow = Time.Gregorian.info(homeNow, Time.FORMAT_SHORT);
        if (gregorianNow.min != gregorianHomeNow.min || gregorianNow.hour != gregorianHomeNow.hour) {
            var minute = gregorianHomeNow.min - gregorianHomeNow.min % 5;
            var angle = ((gregorianHomeNow.hour % 12) * 30 + minute * 0.5) / 180 * Math.PI;
            var xHome = self.screenRadius + self.eventRingRadius * Math.sin(angle);
            var yHome = self.screenRadius - self.eventRingRadius * Math.cos(angle);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawBitmap(dc, xHome, yHome, self.houseIcon);
            drawText(dc, xHome, yHome, Graphics.FONT_TINY, timeToString(gregorianHomeNow.min));
        }

        var xOffsetMiddleRow = 16 * self.onePercentWidth;
        drawHeartRate(dc, self.screenRadius + xOffsetMiddleRow, self.screenRadius);

        var yBottomRow = self.screenRadius + 17 * self.onePercentWidth;
        var xOffsetBottomRow = 14 * self.onePercentWidth;
        var activity = ActivityMonitor.getInfo();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        var text = activity.floorsClimbed;
        drawText(dc, self.screenRadius - xOffsetBottomRow, yBottomRow, Graphics.FONT_XTINY, text == null ? "--" : text);
        text = activity.steps;
        drawText(dc, self.screenRadius                   , yBottomRow, Graphics.FONT_XTINY, text == null ? "--" : text);
        text = activity.activeMinutesWeek.total;
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
        if (type.equals("yearEvents") || type.equals("weekEvents") || type.equals("dayEvents")) {
            var events = data["events"];
            convertColors(events["timeEvents"]);
            convertColors(events["dateEvents"]);

            var now = Time.now().value();
            if (type.equals("dayEvents")) {
                self.dayEvents = events;
                Application.Storage.setValue("dayEvents", events);
                Application.Storage.setValue("dayEventsRetrieved", now);
            } else if (type.equals("weekEvents")) {
                self.weekEvents = events;
                Application.Storage.setValue("weekEvents", events);
                Application.Storage.setValue("weekEventsRetrieved", now);
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
        self.alphaWheel = null;
        self.heartIcon = null;
        self.stepsIcon = null;
        self.stairsIcon = null;
        self.caloriesIcon = null;
        self.bluetoothIcon = null;
        self.houseIcon = null;

        self.offScreenBuffer = null;
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }
}
