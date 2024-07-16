import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Sensor;

class ElegantApp extends Application.AppBase {
    (:initialized) hidden var appView as ElegantView;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        appView = new $.ElegantView();
        // var delegate = new $.ElegantDelegate(appView);

        // return [appView, delegate];
        return [appView];
    }

    function onSettingsChanged() as Void {
        // appView.loadSettings();
        WatchUi.requestUpdate();
    }

    // public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
    // }
}
