namespace Planly
{
    public class ToolBar : Gtk.Box
    {
        // Boton que define el grupo de tools
        private Gtk.ToggleButton group_leader = null;

        // Señal para comunicar acciones de cambio de herramienta al Scene
        public signal void tool_requested(ToolType tool);

        construct
        {
            orientation = Gtk.Orientation.VERTICAL;
            spacing = 6;
            margin_top = 8;
            margin_bottom = 8;
            margin_start = 8;
            margin_end = 8;

            add_button(ToolType.SELECT, Actions.TOOL_SELECT, "cursor", "Select", true);
            add_button(ToolType.WALL, Actions.TOOL_WALL, "wall", "Wall", false);
            add_button(ToolType.COLUMN, Actions.TOOL_COLUMN, "column", "Column", false);
            add_button(ToolType.BULB, Actions.TOOL_BULB, "bulb", "Bulb", false);
            add_button(ToolType.OUTLET, Actions.TOOL_OUTLET, "outlet", "Outlet", false);
            add_button(ToolType.DOOR, Actions.TOOL_DOOR, "door", "Door", false);
            add_button(ToolType.WINDOW, Actions.TOOL_WINDOW, "window", "Window", false);
            add_button(ToolType.FAUCET, Actions.TOOL_FAUCET, "faucet", "Faucet", false);
            add_button(ToolType.FURNITURE, Actions.TOOL_FURNITURE, "furniture", "Furniture", false);

            add_css_class("tool-panel");
        }

        /**
         * Añade un botón al ToolBar.
         */
        private void add_button(ToolType tool, string action, string icon, string tip, bool is_active)
        {
            var img = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/" + icon + "-symbolic.svg");
            img.set_pixel_size(20);

            var btn = new Gtk.ToggleButton();
            btn.tooltip_text  = _(tip);
            btn.width_request  = 40;
            btn.height_request = 40;
            btn.action_name = "win." + action;
            btn.set_child(img);
            btn.add_css_class("flat");

            if (is_active) {
                btn.active = true;
            }

            if (group_leader != null) {
                btn.group = group_leader;
            } else {
                group_leader = btn;
            }

            append(btn);
        }
    }
}