import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Sensor;

class GeoHunterApp extends Application.AppBase {
    (:initialized) hidden var appView as GeoHunterView;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        appView = new $.GeoHunterView();
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
