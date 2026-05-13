/**
 * Planly — Editor de planos escalado
 *
 * Punto de entrada y clase Application principal.
 * Configura la internacionalización, aplica el tema oscuro por defecto
 * y crea la ventana principal.
 */
namespace Planly
{
    public static int main(string[] args)
    {
        Intl.setlocale();
        Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain(Config.GETTEXT_PACKAGE);

        var app = new Application();
        return app.run(args);
    }

    public class Application : Adw.Application
    {
        public Application ()
        {
            Object(
                application_id: Config.APP_ID,
                flags: GLib.ApplicationFlags.DEFAULT_FLAGS
                );
        }

        protected override void activate()
        {
            // 1. Leer preferencias guardadas (tema, etc.)
            UserPreferences.instance.load ();

            // 2. Aplicar el esquema de Adwaita según la preferencia guardada
            apply_color_scheme (UserPreferences.instance.saved_theme);

            // 3. Cargar la paleta de colores del canvas (se ajusta al tema activo)
            ColorTheme.instance.load ();

            Shortcuts.setup (this);

            var window = new Window (this);
            window.present ();
        }

        /**
         * Aplica el esquema de color de Adwaita según el nombre del tema.
         * Con "system" (primer arranque o preferencia del usuario) sigue el SO.
         *
         * @param theme_name "light", "dark" o "system".
         */
        private void apply_color_scheme (string theme_name)
        {
            var style_manager = Adw.StyleManager.get_default ();
            switch (theme_name) {
            case "light":  style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT; break;
            case "dark":   style_manager.color_scheme = Adw.ColorScheme.FORCE_DARK;  break;
            default:       style_manager.color_scheme = Adw.ColorScheme.DEFAULT;     break;
            }
        }
    }
}
