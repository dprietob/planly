namespace Planly
{
    /**
     * Ventana principal de Planly.
     *
     * Construye un Adw.ToolbarView con un Adw.HeaderBar (que incluye un botón
     * de menú para cambiar el tema) y el Scene como contenido.
     *
     * El tema por defecto es oscuro; el usuario puede cambiarlo a claro o
     * seguir el del sistema desde el menú de apariencia.
     */
    public class Window : Adw.ApplicationWindow
    {
        public Window (Gtk.Application app)
        {
            Object(application: app);
        }

        construct {
            var scene = new Scene();

            // ── Header bar ─────────────────────────────────────────────────
            var header_bar = new Adw.HeaderBar();

            var theme_menu = new GLib.Menu();
            theme_menu.append(_("Dark"), "win.theme::dark");
            theme_menu.append(_("Light"), "win.theme::light");
            theme_menu.append(_("System"), "win.theme::system");

            var appearance_menu = new GLib.Menu();
            appearance_menu.append_submenu(_("Appearance"), theme_menu);

            var menu_button = new Gtk.MenuButton();
            menu_button.icon_name  = "open-menu-symbolic";
            menu_button.menu_model = appearance_menu;
            menu_button.tooltip_text = _("Main menu");
            header_bar.pack_end(menu_button);

            // ── Layout ─────────────────────────────────────────────────────
            var toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.content = scene;

            // ── Acción de tema ─────────────────────────────────────────────
            setup_theme_action();

            // ── Ventana ────────────────────────────────────────────────────
            set_title(APP_NAME + " " + Config.VERSION);
            set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT);
            set_content(toolbar_view);
        }

        private void setup_theme_action()
        {
            var action = new GLib.SimpleAction.stateful(
                "theme",
                GLib.VariantType.STRING,
                new GLib.Variant.string("dark")
                );
            action.change_state.connect((act, new_state) => {
                if (new_state == null) return;
                act.set_state(new_state);
                apply_theme(new_state.get_string());
            });
            add_action(action);
        }

        private void apply_theme(string theme)
        {
            var sm = Adw.StyleManager.get_default();
            switch (theme) {
            case "light":
                sm.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                break;
            case "system":
                sm.color_scheme = Adw.ColorScheme.DEFAULT;
                break;
            default:     // "dark"
                sm.color_scheme = Adw.ColorScheme.FORCE_DARK;
                break;
            }
        }
    }
}
