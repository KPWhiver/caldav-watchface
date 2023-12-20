using Toybox.Background;
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.System;

class CaldavWatchApp extends Application.AppBase {

    var view;
    var background;


    function initialize() {
        Application.AppBase.initialize();

        self.view = null;

        if(Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(5*60));
        }
    }

    function dayNumber() {
        return Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT).day;
    }

    // onStart() is called on application start up
    function onStart(state as Lang.Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Lang.Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        self.view = new CaldavWatchView();
        return [ self.view ] as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>;
    }

    function getServiceDelegate() as Lang.Array<System.ServiceDelegate> {
        return [ new CaldavWatchBackground() ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        Background.registerForTemporalEvent(new Time.Duration(15 * 60));

        if (view == null) {
            return;
        }

        view.onBackgroundData(data);
    }
}
