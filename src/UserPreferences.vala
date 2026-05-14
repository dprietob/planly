/**
 * Preferencias del usuario persistidas en disco.
 *
 * Fichero: ~/.config/planly/preferences.conf
 *
 * Si el fichero no existe (primer arranque), se usan los valores
 * predeterminados. El fichero se crea en cuanto el usuario modifica
 * cualquier preferencia.
 */
namespace Planly
{
    public class UserPreferences : GLib.Object
    {
        private static UserPreferences? _instance = null;

        /** Tema visual: "light", "dark" o "system". Predeterminado: "system". */
        public string saved_theme { get; private set; default = "system"; }

        /** Anchura de ventana guardada. Predeterminado: WINDOW_WIDTH (1280 px). */
        public int saved_window_width { get; private set; default = WINDOW_WIDTH; }

        /** Altura de ventana guardada. Predeterminado: WINDOW_HEIGHT (800 px). */
        public int saved_window_height { get; private set; default = WINDOW_HEIGHT; }

        /** Si la ventana estaba maximizada al cerrar. Predeterminado: false. */
        public bool saved_is_maximized { get; private set; default = false; }

        // ── Acceso global ─────────────────────────────────────────────────

        /** Instancia única de las preferencias del usuario. */
        public static UserPreferences instance {
            get {
                if (_instance == null) _instance = new UserPreferences ();
                return _instance;
            }
        }

        // ── API pública ───────────────────────────────────────────────────

        /**
         * Lee las preferencias guardadas en disco.
         * Si el fichero no existe (primer arranque) no hace nada.
         */
        public void load ()
        {
            string path = preferences_file_path ();
            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) return;

            string content;
            try {
                GLib.FileUtils.get_contents (path, out content);
            } catch (GLib.FileError e) {
                warning ("UserPreferences: no se pudo leer '%s': %s", path, e.message);
                return;
            }

            foreach (string raw_line in content.split ("\n")) {
                string line = raw_line.strip ();
                if (line.length == 0 || line.has_prefix ("#")) continue;

                int separator_index = line.index_of ("=");
                if (separator_index < 0) continue;

                string key   = line.substring (0, separator_index).strip ();
                string value = line.substring (separator_index + 1).strip ();

                switch (key) {
                case "theme":            saved_theme         = value;                    break;
                case "window_width":     saved_window_width  = int.parse (value);        break;
                case "window_height":    saved_window_height = int.parse (value);        break;
                case "window_maximized": saved_is_maximized  = (value == "true");        break;
                }
            }
        }

        /**
         * Guarda el tema elegido por el usuario.
         *
         * @param theme_name "light", "dark" o "system".
         */
        public void save_theme (string theme_name)
        {
            saved_theme = theme_name;
            write_to_disk ();
        }

        /**
         * Guarda el estado completo de la ventana principal.
         * Se llama al maximizar, restaurar o cerrar la ventana.
         *
         * @param is_maximized  Si la ventana está maximizada.
         * @param width         Anchura "natural" (pre-maximización) en píxeles.
         * @param height        Altura "natural" (pre-maximización) en píxeles.
         */
        public void save_window_state (bool is_maximized, int width, int height)
        {
            saved_is_maximized  = is_maximized;
            saved_window_width  = width;
            saved_window_height = height;
            write_to_disk ();
        }

        // ── Persistencia ──────────────────────────────────────────────────

        private string preferences_file_path ()
        {
            return GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (),
                "planly", "preferences.conf"
            );
        }

        private void write_to_disk ()
        {
            string path      = preferences_file_path ();
            string directory = GLib.Path.get_dirname (path);

            try {
                GLib.File.new_for_path (directory).make_directory_with_parents (null);
            } catch (GLib.Error e) {
                // El directorio ya existe
            }

            string content =
                "# Planly — Preferencias del usuario\n"
                + "# tema: light (claro), dark (oscuro), system (según el sistema)\n"
                + "theme = " + saved_theme + "\n"
                + "\n"
                + "# Estado de la ventana principal\n"
                + "window_width     = %d\n".printf (saved_window_width)
                + "window_height    = %d\n".printf (saved_window_height)
                + "window_maximized = %s\n".printf (saved_is_maximized ? "true" : "false");

            try {
                GLib.FileUtils.set_contents (path, content);
            } catch (GLib.FileError e) {
                warning ("UserPreferences: no se pudo guardar en '%s': %s", path, e.message);
            }
        }
    }
}
