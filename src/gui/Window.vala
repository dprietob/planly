namespace Planly
{
    /**
     * Ventana principal de Planly.
     *
     * Layout:
     *  ┌─────────────────────────────────────────────────────┐
     *  │  HeaderBar: [new][open]  titulo  [save][export][menu]│
     *  ├──────────┬──────────────────────────────────────────┤
     *  │ToolPanel │         Scene (canvas)                    │
     *  │          │                                           │
     *  ├──────────┴──────────────────────────────────────────┤
     *  │  StatusBar: escala · px · m · area · unidades | auto │
     *  └─────────────────────────────────────────────────────┘
     */
    public class Window : Adw.ApplicationWindow
    {
        public Window (Gtk.Application app)
        {
            Object(application: app);
        }

        construct {
            var scene      = new Scene();
            var status_bar = new StatusBar();

            // Scene -> StatusBar
            scene.metrics_updated.connect(status_bar.update_metrics);
            scene.zoom_changed.connect(status_bar.update_zoom);

            // StatusBar -> Scene (zoom)
            status_bar.zoom_in_requested.connect(scene.zoom_in);
            status_bar.zoom_out_requested.connect(scene.zoom_out);
            status_bar.zoom_reset_requested.connect(scene.zoom_reset);

            // Header bar
            var header_bar = build_header_bar();

            // Paleta de herramientas
            var tool_panel = build_tool_panel(scene);

            // Canvas dentro de un ScrolledWindow para soportar pan al hacer zoom
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.set_hexpand(true);
            scrolled.set_vexpand(true);
            scrolled.child = scene;

            // Area de trabajo: paleta + canvas
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            hbox.append(tool_panel);
            hbox.append(scrolled);

            // Layout principal (Adw.ToolbarView gestiona header y footer)
            var toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.add_bottom_bar(status_bar);
            toolbar_view.content = hbox;

            // Acciones
            setup_theme_action();
            setup_document_actions();

            set_title(APP_NAME + " " + Config.VERSION);
            set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT);
            set_content(toolbar_view);
        }

        // Header bar

        private Adw.HeaderBar build_header_bar()
        {
            var header_bar = new Adw.HeaderBar();

            // Inicio: icono Nuevo + icono Abrir
            var btn_new = new Gtk.Button();
            btn_new.icon_name    = "document-new-symbolic";
            btn_new.tooltip_text = _("New plan");
            btn_new.action_name  = "win.new-plan";
            header_bar.pack_start(btn_new);

            var btn_open = new Gtk.Button();
            btn_open.icon_name    = "document-open-symbolic";
            btn_open.tooltip_text = _("Open plan");
            btn_open.action_name  = "win.open-plan";
            header_bar.pack_start(btn_open);

            // Fin: menu (mas a la derecha), luego Export, luego Save
            // pack_end apila de derecha a izquierda: el primero queda mas a la derecha
            var theme_menu = new GLib.Menu();
            theme_menu.append(_("Dark"), "win.theme::dark");
            theme_menu.append(_("Light"), "win.theme::light");
            theme_menu.append(_("System"), "win.theme::system");

            var appearance_menu = new GLib.Menu();
            appearance_menu.append_submenu(_("Appearance"), theme_menu);

            var menu_button = new Gtk.MenuButton();
            menu_button.icon_name    = "open-menu-symbolic";
            menu_button.menu_model   = appearance_menu;
            menu_button.tooltip_text = _("Main menu");
            header_bar.pack_end(menu_button);

            var btn_export = new Gtk.Button.with_label(_("Export"));
            btn_export.action_name = "win.export";
            header_bar.pack_end(btn_export);

            var btn_save = new Gtk.Button.with_label(_("Save"));
            btn_save.action_name = "win.save";
            btn_save.add_css_class("suggested-action");
            header_bar.pack_end(btn_save);

            return header_bar;
        }

        // Paleta de herramientas

        /**
         * Construye la barra lateral izquierda con los botones de herramienta.
         * Los botones actuan como un grupo radio: solo uno puede estar activo.
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
                    ToolType.SELECT, "org.gnome.Settings-accessibility-pointing-symbolic", _("Select (S)"), false);
            add_tool_button(panel, first, scene,
                ToolType.LINE, "function-linear-symbolic", _("Line (L)"), true);
            add_tool_button(panel, first, scene,
                ToolType.RECT, "checkbox-symbolic", _("Rectangle (R)"), false);
            add_tool_button(panel, first, scene,
                ToolType.CIRCLE, "radio-symbolic", _("Circle (C)"), false);
            add_tool_button(panel, first, scene,
                ToolType.POLYGON, "input-tablet-symbolic", _("Polygon (P)"), false);

            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.margin_top    = 4;
            sep.margin_bottom = 4;
            panel.append(sep);

            return panel;
        }

        private Gtk.ToggleButton add_tool_button(
            Gtk.Box panel,
            Gtk.ToggleButton?  group_leader,
            Scene scene,
            ToolType tool,
            string icon,
            string tip,
            bool is_active)
        {
            var btn = new Gtk.ToggleButton();
            btn.icon_name     = icon;
            btn.tooltip_text  = tip;
            btn.add_css_class("flat");
            btn.width_request  = 40;
            btn.height_request = 40;

            if (is_active) {
                btn.active = true;
            }

            if (group_leader != null) {
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

        // Acciones de documento

        /**
         * Registra las acciones win.new-plan, win.open-plan, win.save, win.export.
         * La logica real se implementara cuando se añada la capa de persistencia
         * (Project). Por ahora las acciones existen para que los botones funcionen.
         */
        private void setup_document_actions()
        {
            var act_new = new GLib.SimpleAction("new-plan", null);
            act_new.activate.connect(() => { /* TODO: nuevo plano */ });
            add_action(act_new);

            var act_open = new GLib.SimpleAction("open-plan", null);
            act_open.activate.connect(() => { /* TODO: abrir plano */ });
            add_action(act_open);

            var act_save = new GLib.SimpleAction("save", null);
            act_save.activate.connect(() => { /* TODO: guardar */ });
            add_action(act_save);

            var act_export = new GLib.SimpleAction("export", null);
            act_export.activate.connect(() => { /* TODO: exportar */ });
            add_action(act_export);
        }

        // Accion de tema

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
