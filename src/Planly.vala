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
            // Tema del sistema por defecto al arrancar y asignación de shortcuts
            //  Adw.StyleManager.get_default().color_scheme = Adw.ColorScheme.DEFAULT;
            Adw.StyleManager.get_default().color_scheme = Adw.ColorScheme.FORCE_LIGHT; // DEBUG:
            AccelsManager.setup(this);

            var window = new Window(this);
            window.present();
        }
    }
}
