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
        var startTime = Time.now();

        var dayEvents = Application.Storage.getValue("dayEvents");
        var dayEventsRetrieved = Application.Storage.getValue("dayEventsRetrieved");
        var yearEvents = Application.Storage.getValue("yearEvents");
        var yearEventsRetrieved = Application.Storage.getValue("yearEventsRetrieved");

        var retrieveYearEvents = yearEventsRetrieved == null ||
                                 startTime.value() - yearEventsRetrieved > Time.Gregorian.SECONDS_PER_DAY;

        var retrievalServiceUrl = Application.Properties.getValue("RetrievalServiceUrl");
        var caldavUrl = Application.Properties.getValue("CaldavUrl");
        var dayCalendars = Application.Properties.getValue("WeekCalendars");
        var weekCalendars = Application.Properties.getValue("WeekCalendars");
        var yearCalendars = Application.Properties.getValue("WeekCalendars");

        if (dayEventsRetrieved == null || !retrieveYearEvents) {
            var endTime = startTime.add(new Time.Duration(Time.Gregorian.SECONDS_PER_DAY));
            Communications.makeWebRequest(retrievalServiceUrl, {
                "calendarUrl"=>caldavUrl,
                "calendarList"=>dayCalendars,
                "startTime"=>startTime.value().toLong().toString(),
                "endTime"=>endTime.value().toLong().toString()
            }, {
                :method=>Communications.HTTP_REQUEST_METHOD_GET
            }, method(:onDayData));
        } else {
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

    function onYearData(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200) {
            Background.exit({"type"=>"yearEvents", "events"=>data});
        } else {
            Background.exit({"type"=>"error", "responseCode"=>responseCode});
        }
    }
}
