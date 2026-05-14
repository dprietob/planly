namespace Planly
{
    /**
     * Registra todos los atajos de teclado de la aplicación en GTK.
     * Acceso global mediante Shortcuts.instance.
     */
    public class Shortcuts : GLib.Object
    {
        private static Shortcuts? _instance = null;

        /** Instancia única. */
        public static Shortcuts instance {
            get {
                if (_instance == null) _instance = new Shortcuts ();
                return _instance;
            }
        }

        /**
         * Asocia cada acción con su atajo de teclado en la aplicación GTK.
         *
         * @param app Instancia de la aplicación GTK.
         */
        public void setup (Application app)
        {
            app.set_accels_for_action ("win." + Actions.NEW_DOC,    {Accels.NEW_DOC});
            app.set_accels_for_action ("win." + Actions.OPEN_DOC,   {Accels.OPEN_DOC});
            app.set_accels_for_action ("win." + Actions.SAVE_DOC,   {Accels.SAVE_DOC});
            app.set_accels_for_action ("win." + Actions.EXPORT_DOC, {Accels.EXPORT_DOC});
            app.set_accels_for_action ("win." + Actions.RENDER_DOC, {Accels.RENDER_DOC});
            app.set_accels_for_action ("win." + Actions.SETTINGS,   {Accels.SETTINGS});
            app.set_accels_for_action ("win." + Actions.SHORTCUTS,  {Accels.SHORTCUTS});
            app.set_accels_for_action ("win." + Actions.ABOUT,      {Accels.ABOUT});

            // Herramientas: acción unificada con target de cadena
            string tool_action = "win." + Actions.ACTIVE_TOOL;
            app.set_accels_for_action (tool_action + "('select')",    {Accels.TOOL_SELECT});
            app.set_accels_for_action (tool_action + "('wall')",      {Accels.TOOL_WALL});
            app.set_accels_for_action (tool_action + "('column')",    {Accels.TOOL_COLUMN});
            app.set_accels_for_action (tool_action + "('bulb')",      {Accels.TOOL_BULB});
            app.set_accels_for_action (tool_action + "('outlet')",    {Accels.TOOL_OUTLET});
            app.set_accels_for_action (tool_action + "('faucet')",    {Accels.TOOL_FAUCET});
            app.set_accels_for_action (tool_action + "('door')",      {Accels.TOOL_DOOR});
            app.set_accels_for_action (tool_action + "('window')",    {Accels.TOOL_WINDOW});
            app.set_accels_for_action (tool_action + "('furniture')", {Accels.TOOL_FURNITURE});

            app.set_accels_for_action ("win." + Actions.ZOOM_IN,    {Accels.ZOOM_IN});
            app.set_accels_for_action ("win." + Actions.ZOOM_OUT,   {Accels.ZOOM_OUT});
            app.set_accels_for_action ("win." + Actions.ZOOM_RESET, {Accels.ZOOM_RESET});
        }
    }
}
