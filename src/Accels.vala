namespace Planly
{
    /**
     * Cadenas de atajos de teclado en formato GLib/GTK.
     * Acceso global mediante Accels.instance o directamente como Accels.ZOOM_IN.
     */
    public class Accels : GLib.Object
    {
        private static Accels? _instance = null;

        /** Instancia única. */
        public static Accels instance {
            get {
                if (_instance == null) _instance = new Accels ();
                return _instance;
            }
        }

        // ── Documentos ────────────────────────────────────────────────────
        public const string NEW_DOC    = "<Ctrl>N";
        public const string OPEN_DOC   = "<Ctrl>O";
        public const string SAVE_DOC   = "<Ctrl>S";
        public const string EXPORT_DOC = "F12";
        public const string RENDER_DOC = "<Ctrl>R";

        // ── Ajustes ───────────────────────────────────────────────────────
        public const string SETTINGS  = "<Ctrl>K";
        public const string SHORTCUTS = "<Ctrl>question";
        public const string ABOUT     = "<Ctrl>comma";

        // ── Herramientas ──────────────────────────────────────────────────
        public const string TOOL_SELECT    = "<Alt>1";
        public const string TOOL_WALL      = "<Alt>2";
        public const string TOOL_COLUMN    = "<Alt>3";
        public const string TOOL_BULB      = "<Alt>4";
        public const string TOOL_OUTLET    = "<Alt>5";
        public const string TOOL_FAUCET    = "<Alt>6";
        public const string TOOL_DOOR      = "<Alt>7";
        public const string TOOL_WINDOW    = "<Alt>8";
        public const string TOOL_FURNITURE = "<Alt>9";

        // ── Zoom ──────────────────────────────────────────────────────────
        public const string ZOOM_IN    = "<Ctrl>plus";
        public const string ZOOM_OUT   = "<Ctrl>minus";
        public const string ZOOM_RESET = "<Ctrl>0";
    }
}
