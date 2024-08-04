import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Sensor;

class SolargraphApp extends Application.AppBase {
    (:initialized) hidden var appView as SolargraphView;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        appView = new $.SolargraphView();
        // the delegate doesn't actually do anything at present, but it's now here if I need it
        var delegate = new $.SolargraphDelegate(appView);

        return [appView, delegate];
    }

    public function onSettingsChanged() as Void {
        appView.loadSettings();
        WatchUi.requestUpdate();
    }

    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu;
        menu = new $.SolargraphSettingsMenu();

        var val = Application.Properties.getValue("ShowDate") ? true : false;
        var resId = Rez.Strings.MenuItemShowDate;
        menu.addItem(new WatchUi.ToggleMenuItem(resId, null, "ShowDate", val, null));

        val = Application.Properties.getValue("ShowBattery") ? true : false;
        resId = Rez.Strings.MenuItemShowBattery;
        menu.addItem(new WatchUi.ToggleMenuItem(resId, null, "ShowBattery", val, null));

        val = Application.Properties.getValue("ShowHrSubdial") ? true : false;
        resId = Rez.Strings.MenuItemShowHrSubdial;
        menu.addItem(new WatchUi.ToggleMenuItem(resId, null, "ShowHrSubdial", val, null));

        val = Application.Properties.getValue("ShowSteps") ? true : false;
        resId = Rez.Strings.MenuItemShowSteps;
        menu.addItem(new WatchUi.ToggleMenuItem(resId, null, "ShowSteps", val, null));

        val = Application.Properties.getValue("ShowSunLines") ? true : false;
        resId = Rez.Strings.MenuItemShowSunLines;
        menu.addItem(new WatchUi.ToggleMenuItem(resId, null, "ShowSunLines", val, null));

        return [menu, new $.SolargraphSettingsMenuDelegate()];
    }
}
