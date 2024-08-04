import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

class SolargraphSettingsMenu extends WatchUi.Menu2 {
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
    }
}

//! Input handler for the app settings menu
class SolargraphSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(menuItem as MenuItem) as Void {
        if (menuItem instanceof ToggleMenuItem) {
            Application.Properties.setValue(menuItem.getId() as String, menuItem.isEnabled() as Number);
        } else {
            // Disabled all these for now as there aren't any other types of menu item
            // var id = menuItem.getId() as String;
            // var color_index = Application.Properties.getValue(id) as Number;
            // var new_index = color_index < color_values.size() - 1 ? color_index + 1 : 0;
            // var color_name = colorName(new_index);
            // menuItem.setSubLabel(color_name);
            // System.println("Changing menu item " + id + " from " + color_index + " to " + new_index + " (" + color_name + ")");
            // Application.Properties.setValue(id, new_index);
        }
    }
}


