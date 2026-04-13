namespace Planly
{
    /**
     * Ventana principal de Planly.
     *
     * Layout:
     *  ┌─────────────────────────────────────────┐
     *  │  HeaderBar  (título + menú de apariencia)│
     *  ├──────────┬──────────────────────────────┤
     *  │ToolPanel │         Scene (canvas)        │
     *  │          │                               │
     *  └──────────┴──────────────────────────────┘
     *
     * La paleta de herramientas (ToolPanel) es una columna de botones de
     * tipo radio que comunican la herramienta activa al Scene.
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
            theme_menu.append(_("Dark"),   "win.theme::dark");
            theme_menu.append(_("Light"),  "win.theme::light");
            theme_menu.append(_("System"), "win.theme::system");

            var appearance_menu = new GLib.Menu();
            appearance_menu.append_submenu(_("Appearance"), theme_menu);

            var menu_button = new Gtk.MenuButton();
            menu_button.icon_name   = "open-menu-symbolic";
            menu_button.menu_model  = appearance_menu;
            menu_button.tooltip_text = _("Main menu");
            header_bar.pack_end(menu_button);

            // ── Paleta de herramientas ──────────────────────────────────────
            var tool_panel = build_tool_panel(scene);

            // ── Área de trabajo: paleta + canvas ───────────────────────────
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            hbox.append(tool_panel);
            hbox.append(scene);

            // ── Layout principal ───────────────────────────────────────────
            var toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.content = hbox;

            // ── Acciones ───────────────────────────────────────────────────
            setup_theme_action();

            // ── Ventana ────────────────────────────────────────────────────
            set_title(APP_NAME + " " + Config.VERSION);
            set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT);
            set_content(toolbar_view);
        }

        // ── Paleta de herramientas ─────────────────────────────────────────

        /**
         * Construye la barra lateral izquierda con los botones de herramienta.
         * Los botones actúan como un grupo radio: sólo uno puede estar activo.
         */
        private Gtk.Box build_tool_panel(Scene scene)
        {
            var panel = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            panel.add_css_class("tool-panel");
            panel.margin_top    = 8;
            panel.margin_bottom = 8;
            panel.margin_start  = 6;
            panel.margin_end    = 6;

            Gtk.ToggleButton? first = null;

            first = add_tool_button(panel, first, scene,
                ToolType.SELECT, "edit-select-symbolic",    _("Select (S)"),    true);
            add_tool_button(panel, first, scene,
                ToolType.LINE,   "draw-freehand-symbolic",  _("Line (L)"),      false);
            add_tool_button(panel, first, scene,
                ToolType.RECT,   "draw-rectangle-symbolic", _("Rectangle (R)"), false);
            add_tool_button(panel, first, scene,
                ToolType.CIRCLE, "draw-ellipse-symbolic",   _("Circle (C)"),    false);

            // Separador visual antes de herramientas futuras
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.margin_top    = 4;
            sep.margin_bottom = 4;
            panel.append(sep);

            return panel;
        }

        private Gtk.ToggleButton add_tool_button(Gtk.Box panel,
            Gtk.ToggleButton?  group_leader,
            Scene              scene,
            ToolType           tool,
            string             icon,
            string             tip,
            bool               is_first)
        {
            var btn = new Gtk.ToggleButton();
            btn.icon_name     = icon;
            btn.tooltip_text  = tip;
            btn.add_css_class("flat");
            btn.width_request  = 40;
            btn.height_request = 40;

            if (is_first) {
                btn.active = true;
            } else if (group_leader != null) {
                btn.group = group_leader;
            }

            btn.toggled.connect(() => {
                if (btn.active) {
                    scene.set_tool(tool);
                }
            });

            panel.append(btn);
            return btn;
        }

        // ── Acción de tema ─────────────────────────────────────────────────

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
