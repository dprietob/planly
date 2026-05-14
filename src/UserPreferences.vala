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

        /**
         * Tema visual: "light", "dark" o "system".
         * Predeterminado: "system" (primer arranque).
         */
        public string saved_theme { get; private set; default = "system"; }

        /**
         * Ancho de ventana guardado.
         * Predeterminado: WINDOW_WIDTH (1280 px).
         */
        public int saved_window_width { get; private set; default = WINDOW_WIDTH; }

        /**
         * Alto de ventana guardado.
         * Predeterminado: WINDOW_HEIGHT (800 px).
         */
        public int saved_window_height { get; private set; default = WINDOW_HEIGHT; }

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
                case "theme":         saved_theme         = value;          break;
                case "window_width":  saved_window_width  = int.parse (value); break;
                case "window_height": saved_window_height = int.parse (value); break;
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
         * Guarda el tamaño de la ventana principal.
         * Se llama al cerrar la ventana para restaurarlo en el siguiente arranque.
         *
         * @param width  Anchura en píxeles.
         * @param height Altura en píxeles.
         */
        public void save_window_size (int width, int height)
        {
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
                + "# Tamaño de la ventana principal (en píxeles)\n"
                + "window_width  = %d\n".printf (saved_window_width)
                + "window_height = %d\n".printf (saved_window_height);

            try {
                GLib.FileUtils.set_contents (path, content);
            } catch (GLib.FileError e) {
                warning ("UserPreferences: no se pudo guardar en '%s': %s", path, e.message);
            }
        }
    }
}
