namespace Planly
{
    public class HeaderBar : Gtk.Box
    {
        construct
        {
            var header = new Adw.HeaderBar(){
                hexpand = true,
                margin_top = 5,
                margin_bottom = 5,
                margin_start = 50,
            };

            add_title(header);

            add_separator(header);
            add_settings_dropdown(header);
            add_export_dropdown(header);
            add_button(header, Actions.SAVE_DOC, "save", "Save plan");
            add_button(header, Actions.OPEN_DOC, "open", "Open plan");
            add_button(header, Actions.NEW_DOC, "new", "New plan");

            append(header);
        }

        /**
         * Añade un título personalizado al HeaderBar.
         */
        private void add_title(Adw.HeaderBar header)
        {
            // Eliminación del título por defecto
            header.set_title_widget(new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0));

            var planly = new Gtk.Label(format_title()){
                use_markup = true,
            };

            var project = new Gtk.Label(_("Project: Planos 2D"));

            var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL) {
                margin_start = 15,
                margin_end = 15,
                margin_top = 10,
                margin_bottom = 8,
            };

            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            box.append(planly);
            box.append(separator);
            box.append(project);
            header.pack_start(box);
        }

        /**
         * Añade un botón al HeaderBar.
         */
        private void add_button(Adw.HeaderBar header, string action, string icon, string tip)
        {
            var img = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/" + icon + "-symbolic.svg");
            img.set_pixel_size(20);

            var btn = new Gtk.Button();
            btn.tooltip_text = _(tip);
            btn.action_name = "win." + action;
            btn.set_child(img);
            btn.add_css_class("flat");

            header.pack_end(btn);
        }

        /**
         * Añade el menu de exportar al HeaderBar.
         */
        private void add_export_dropdown(Adw.HeaderBar header)
        {
            var menu = new GLib.Menu();
            menu.append_item(new GLib.MenuItem(_("Export"), "win." + Actions.EXPORT_DOC));
            menu.append_item(new GLib.MenuItem(_("Render"), "win." + Actions.RENDER_DOC));

            var img = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/export-symbolic.svg");
            img.set_pixel_size(20);

            var menu_button = new Gtk.MenuButton();
            menu_button.menu_model = menu;
            menu_button.tooltip_text = _("Export");
            menu_button.set_child(img);
            menu_button.add_css_class("flat");
            header.pack_end(menu_button);
        }

        /**
         * Añade el menu de configuración al HeaderBar.
         */
        private void add_settings_dropdown(Adw.HeaderBar header)
        {
            var theme_menu = new GLib.Menu();
            theme_menu.append(_("Dark"), "win.theme::dark");
            theme_menu.append(_("Light"), "win.theme::light");
            theme_menu.append(_("System"), "win.theme::system");

            var menu = new GLib.Menu();
            menu.append_submenu(_("Appearance"), theme_menu);
            menu.append_item(new GLib.MenuItem(_("Settings"), "win." + Actions.SETTINGS));
            menu.append_item(new GLib.MenuItem(_("Shortcuts"), "win." + Actions.SHORTCUTS));
            menu.append_item(new GLib.MenuItem(_("About"), "win." + Actions.ABOUT));

            var img = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/settings-symbolic.svg");
            img.set_pixel_size(20);

            var menu_button = new Gtk.MenuButton();
            menu_button.menu_model = menu;
            menu_button.tooltip_text = _("Main menu");
            menu_button.set_child(img);
            menu_button.add_css_class("flat");
            header.pack_end(menu_button);
        }

        /**
         * Devuelve el texto del título formateado con nombre y versión.
         */
        private static string format_title()
        {
            string name    = "<span size='18pt' weight='bold'>" + APP_NAME + "</span>";
            string version = "<small>" + Config.VERSION + "</small>";
            return name + " " + version;
        }

        private void add_separator(Adw.HeaderBar header)
        {
            var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL) {
                margin_start = 15,
                margin_end = 15,
                margin_top = 10,
                margin_bottom = 8,
            };
            header.pack_end(separator);
        }
    }
}