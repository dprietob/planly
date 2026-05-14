namespace Planly
{
    public class ToolBar : Gtk.Box
    {
        // Primer botón del grupo: define la referencia para los demás
        private Gtk.ToggleButton group_leader = null;

        construct
        {
            orientation   = Gtk.Orientation.VERTICAL;
            spacing       = 6;
            margin_top    = 8;
            margin_bottom = 8;
            margin_start  = 8;
            margin_end    = 8;

            add_tool_button (ToolType.SELECT,    "select",    "cursor",    "Select",    true);
            add_tool_button (ToolType.WALL,      "wall",      "wall",      "Wall",      false);
            add_tool_button (ToolType.COLUMN,    "column",    "column",    "Column",    false);
            add_tool_button (ToolType.BULB,      "bulb",      "bulb",      "Bulb",      false);
            add_tool_button (ToolType.OUTLET,    "outlet",    "outlet",    "Outlet",    false);
            add_tool_button (ToolType.DOOR,      "door",      "door",      "Door",      false);
            add_tool_button (ToolType.WINDOW,    "window",    "window",    "Window",    false);
            add_tool_button (ToolType.FAUCET,    "faucet",    "faucet",    "Faucet",    false);
            add_tool_button (ToolType.FURNITURE, "furniture", "furniture", "Furniture", false);

            add_css_class ("tool-panel");
        }

        /**
         * Añade un botón de herramienta al panel.
         *
         * @param tool        Herramienta que representa el botón.
         * @param tool_key    Identificador de cadena usado como target de la acción (ej. "wall").
         * @param icon        Nombre del icono SVG (sin sufijo "-symbolic").
         * @param tooltip     Texto del tooltip localizable.
         * @param is_initial  true si este botón debe aparecer activo al arrancar.
         */
        private void add_tool_button (ToolType tool, string tool_key,
                                       string icon, string tooltip,
                                       bool is_initial)
        {
            var image = new Gtk.Image.from_resource (
                "/com/dprietob/planly/icons/symbolic/" + icon + "-symbolic.svg");
            image.set_pixel_size (20);

            var button = new Gtk.ToggleButton ();
            button.tooltip_text   = _(tooltip);
            button.width_request  = 40;
            button.height_request = 40;
            button.set_child (image);
            button.add_css_class ("flat");

            // Acción unificada de tipo radio: el target es el tool_key de esta herramienta
            button.action_name = "win." + Actions.ACTIVE_TOOL;
            button.set_action_target_value (new GLib.Variant.string (tool_key));

            if (group_leader != null) {
                button.group = group_leader;
            } else {
                group_leader = button;
            }

            append (button);
        }
    }
}
