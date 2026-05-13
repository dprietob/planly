/**
 * Preferencias del usuario persistidas en disco.
 *
 * Fichero: ~/.config/planly/preferences.conf
 *
 * Si el fichero no existe (primer arranque), se mantienen los valores
 * predeterminados y se usa el tema del sistema operativo.
 * El fichero se crea en cuanto el usuario cambia alguna preferencia.
 */
namespace Planly
{
    public class UserPreferences : GLib.Object
    {
        private static UserPreferences? _instance = null;

        /**
         * Tema visual guardado por el usuario.
         * Valores válidos: "light", "dark", "system".
         * Valor predeterminado: "system" (primer arranque).
         */
        public string saved_theme { get; private set; default = "system"; }

        // ── Acceso global ─────────────────────────────────────────────────

        /**
         * Instancia única de las preferencias del usuario.
         */
        public static UserPreferences instance {
            get {
                if (_instance == null) _instance = new UserPreferences ();
                return _instance;
            }
        }

        // ── API pública ───────────────────────────────────────────────────

        /**
         * Lee las preferencias guardadas en disco.
         * Si el fichero no existe (primer arranque) no hace nada;
         * se usan los valores predeterminados.
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

                if (key == "theme") saved_theme = value;
            }
        }

        /**
         * Guarda el tema elegido por el usuario y lo persiste en disco.
         *
         * @param theme_name Nombre del tema: "light", "dark" o "system".
         */
        public void save_theme (string theme_name)
        {
            saved_theme = theme_name;
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
                + "theme = " + saved_theme + "\n";

            try {
                GLib.FileUtils.set_contents (path, content);
            } catch (GLib.FileError e) {
                warning ("UserPreferences: no se pudo guardar en '%s': %s", path, e.message);
            }
        }
    }
}
