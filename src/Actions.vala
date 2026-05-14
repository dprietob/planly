namespace Planly
{
    /**
     * Nombres de las acciones GLib de la aplicación.
     * Acceso global mediante Actions.instance o directamente como Actions.TOOL_WALL.
     */
    public class Actions : GLib.Object
    {
        private static Actions? _instance = null;

        /** Instancia única. */
        public static Actions instance {
            get {
                if (_instance == null) _instance = new Actions ();
                return _instance;
            }
        }

        // ── Documentos ────────────────────────────────────────────────────
        public const string NEW_DOC    = "new-doc";
        public const string OPEN_DOC   = "open-doc";
        public const string SAVE_DOC   = "save-doc";
        public const string EXPORT_DOC = "export-doc";
        public const string RENDER_DOC = "render-doc";

        // ── Ajustes ───────────────────────────────────────────────────────
        public const string SETTINGS  = "preferences";
        public const string SHORTCUTS = "shortcuts";
        public const string ABOUT     = "about";

        // ── Herramientas ──────────────────────────────────────────────────
        public const string ACTIVE_TOOL   = "active-tool";
        public const string TOOL_SELECT   = "tool-select";
        public const string TOOL_WALL     = "tool-wall";
        public const string TOOL_COLUMN   = "tool-column";
        public const string TOOL_BULB     = "tool-bulb";
        public const string TOOL_OUTLET   = "tool-outlet";
        public const string TOOL_FAUCET   = "tool-faucet";
        public const string TOOL_DOOR     = "tool-door";
        public const string TOOL_WINDOW   = "tool-window";
        public const string TOOL_FURNITURE = "tool-furniture";

        // ── Zoom ──────────────────────────────────────────────────────────
        public const string ZOOM_IN    = "zoom-in";
        public const string ZOOM_OUT   = "zoom-out";
        public const string ZOOM_RESET = "zoom-reset";
    }
}
