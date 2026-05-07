namespace Planly
{
    public class Window : Adw.ApplicationWindow
    {
        public Window (Gtk.Application app)
        {
            Object(application: app);
        }

        construct {
            var header_bar = new HeaderBar();
            var tool_bar = new ToolBar();
            var status_bar = new StatusBar();
            var scene = new Scene();

            // Canvas dentro de un ScrolledWindow para soportar pan al hacer zoom
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.set_hexpand(true);
            scrolled.set_vexpand(true);
            scrolled.child = scene;

            // Area de trabajo: paleta + canvas
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            hbox.append(tool_bar);
            hbox.append(scrolled);

            // Layout principal (Adw.ToolbarView gestiona header y footer)
            var layout = new Adw.ToolbarView();
            layout.add_top_bar(header_bar);
            layout.add_bottom_bar(status_bar);
            layout.content = hbox;

            setup_document_actions();
            setup_settings_actions();
            setup_tools_action(scene);
            setup_zoom_action(scene, status_bar);
            setup_theme_action();

            set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT);
            set_content(layout);
        }

        /**
         * Registra las acciones de control de documentos de planos.
         */
        private void setup_document_actions()
        {
            var action_new = new GLib.SimpleAction(Actions.NEW_DOC, null);
            action_new.activate.connect(() => { /* TODO: nuevo plano */ });
            add_action(action_new);

            var action_open = new GLib.SimpleAction(Actions.OPEN_DOC, null);
            action_open.activate.connect(() => { /* TODO: abrir plano */ });
            add_action(action_open);

            var action_save = new GLib.SimpleAction(Actions.SAVE_DOC, null);
            action_save.activate.connect(() => { /* TODO: guardar */ });
            add_action(action_save);

            var action_export = new GLib.SimpleAction(Actions.EXPORT_DOC, null);
            action_export.activate.connect(() => { /* TODO: exportar */ });
            add_action(action_export);

            var action_render = new GLib.SimpleAction(Actions.RENDER_DOC, null);
            action_render.activate.connect(() => { /* TODO: renderizar */ });
            add_action(action_render);
        }

        /**
         * Registra las acciones de preferencias.
         */
        private void setup_settings_actions()
        {
            var action_settings = new GLib.SimpleAction(Actions.SETTINGS, null);
            action_settings.activate.connect(() => { /* TODO: configuración */ });
            add_action(action_settings);

            var action_shortcuts = new GLib.SimpleAction(Actions.SHORTCUTS, null);
            action_shortcuts.activate.connect(() => { /* TODO: atajos de teclado */ });
            add_action(action_shortcuts);

            var action_about = new GLib.SimpleAction(Actions.ABOUT, null);
            action_about.activate.connect(() => { /* TODO: acerca de */ });
            add_action(action_about);
        }

        /**
         * Registra las acciones de cambio de herramienta para que estén
         * disponibles en la escena.
         */
        private void setup_tools_action(Scene scene)
        {
            var map = new GLib.HashTable<string, ToolType>(str_hash, str_equal);

            map.insert(Actions.TOOL_SELECT, ToolType.SELECT);
            map.insert(Actions.TOOL_WALL, ToolType.WALL);
            map.insert(Actions.TOOL_COLUMN, ToolType.COLUMN);
            map.insert(Actions.TOOL_BULB, ToolType.BULB);
            map.insert(Actions.TOOL_OUTLET, ToolType.OUTLET);
            map.insert(Actions.TOOL_FAUCET, ToolType.FAUCET);
            map.insert(Actions.TOOL_DOOR, ToolType.DOOR);
            map.insert(Actions.TOOL_WINDOW, ToolType.WINDOW);
            map.insert(Actions.TOOL_FURNITURE, ToolType.FURNITURE);

            map.for_each((action_name, tool) => {
                var action = new GLib.SimpleAction.stateful(action_name, null, new GLib.Variant.boolean(false));
                action.activate.connect(() => {
                    bool current = action.get_state().get_boolean();
                    action.set_state(new GLib.Variant.boolean(!current));
                    scene.set_tool(tool);
                });
                add_action(action);
            });
        }

        /**
         * Registra las acciones de zoom sincronizándolas con la escena.
         */
        private void setup_zoom_action(Scene scene, StatusBar status_bar)
        {
            // Scene -> StatusBar
            scene.metrics_updated.connect(status_bar.update_metrics);
            scene.zoom_changed.connect(status_bar.update_zoom);

            // StatusBar -> Scene (zoom)
            status_bar.zoom_in_requested.connect(scene.zoom_in);
            status_bar.zoom_out_requested.connect(scene.zoom_out);
            status_bar.zoom_reset_requested.connect(scene.zoom_reset);
        }

        /**
         * Registra las acciones de cambio de tema.
         */
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

        /**
         * Aplica un cambio de tema.
         */
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
