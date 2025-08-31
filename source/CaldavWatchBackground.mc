using Toybox.Background;
using Toybox.System;
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:background)
class CaldavWatchBackground extends System.ServiceDelegate {

    function initialize() {
        System.ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings has :doNotDisturb && deviceSettings.doNotDisturb) {
            return;
        }

        var startTime = Time.now();

        var dayEvents = Application.Storage.getValue("dayEvents");
        var dayEventsRetrieved = Application.Storage.getValue("dayEventsRetrieved");
        var weekEvents = Application.Storage.getValue("weekEvents");
        var weekEventsRetrieved = Application.Storage.getValue("weekEventsRetrieved");
        var yearEvents = Application.Storage.getValue("yearEvents");
        var yearEventsRetrieved = Application.Storage.getValue("yearEventsRetrieved");

        var retrieveWeekEvents = weekEventsRetrieved == null ||
                                 startTime.value() - weekEventsRetrieved > Time.Gregorian.SECONDS_PER_HOUR * 3;
        var retrieveYearEvents = yearEventsRetrieved == null ||
                                 startTime.value() - yearEventsRetrieved > Time.Gregorian.SECONDS_PER_DAY;

        var retrievalServiceUrl = Application.Properties.getValue("RetrievalServiceUrl");
        var caldavUrl = Application.Properties.getValue("CaldavUrl");
        if (retrievalServiceUrl == null || caldavUrl == null) {
            Background.exit({"type"=>"error", "responseCode"=>"100"});
        }

        var dayCalendars = Application.Properties.getValue("DayCalendars");
        var weekCalendars = Application.Properties.getValue("WeekCalendars");
        var yearCalendars = Application.Properties.getValue("YearCalendars");

        if (dayCalendars != null && (dayEventsRetrieved == null || (!retrieveWeekEvents && !retrieveYearEvents))) {
            var endTime = startTime.add(new Time.Duration(Time.Gregorian.SECONDS_PER_DAY));
            Communications.makeWebRequest(retrievalServiceUrl, {
                "calendarUrl"=>caldavUrl,
                "calendarList"=>dayCalendars,
                "startTime"=>startTime.value().toLong().toString(),
                "endTime"=>endTime.value().toLong().toString()
            }, {
                :method=>Communications.HTTP_REQUEST_METHOD_GET
            }, method(:onDayData));
        } else if (weekCalendars != null && retrieveWeekEvents) {
            var endTime = startTime.add(new Time.Duration(Time.Gregorian.SECONDS_PER_DAY * 12));
            Communications.makeWebRequest(retrievalServiceUrl, {
                "calendarUrl"=>caldavUrl,
                "calendarList"=>weekCalendars,
                "startTime"=>startTime.value().toLong().toString(),
                "endTime"=>endTime.value().toLong().toString()
            }, {
                :method=>Communications.HTTP_REQUEST_METHOD_GET
            }, method(:onWeekData));
        } else if (yearCalendars != null && retrieveYearEvents) {
            var endTime = startTime.add(new Time.Duration(Time.Gregorian.SECONDS_PER_YEAR));
            Communications.makeWebRequest(retrievalServiceUrl, {
                "calendarUrl"=>caldavUrl,
                "calendarList"=>yearCalendars,
                "startTime"=>startTime.value().toLong().toString(),
                "endTime"=>endTime.value().toLong().toString(),
                "allDayOnly"=>true
            }, {
                :method=>Communications.HTTP_REQUEST_METHOD_GET
            }, method(:onYearData));
        }
    }

    function onDayData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200) {
            Background.exit({"type"=>"dayEvents", "events"=>data});
        } else {
            Background.exit({"type"=>"error", "responseCode"=>responseCode});
        }
    }

    function onWeekData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200) {
            Background.exit({"type"=>"weekEvents", "events"=>data});
        } else {
            Background.exit({"type"=>"error", "responseCode"=>responseCode});
        }
    }

    function onYearData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200) {
            Background.exit({"type"=>"yearEvents", "events"=>data});
        } else {
            Background.exit({"type"=>"error", "responseCode"=>responseCode});
        }
    }
}
