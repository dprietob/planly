namespace Planly
{
    public class Shortcuts
    {
        public static void setup(Application app)
        {
            app.set_accels_for_action("win." + Actions.NEW_DOC, {Accels.NEW_DOC});
            app.set_accels_for_action("win." + Actions.OPEN_DOC, {Accels.OPEN_DOC});
            app.set_accels_for_action("win." + Actions.SAVE_DOC, {Accels.SAVE_DOC});
            app.set_accels_for_action("win." + Actions.EXPORT_DOC, {Accels.EXPORT_DOC});
            app.set_accels_for_action("win." + Actions.RENDER_DOC, {Accels.RENDER_DOC});
            app.set_accels_for_action("win." + Actions.SETTINGS, {Accels.SETTINGS});
            app.set_accels_for_action("win." + Actions.SHORTCUTS, {Accels.SHORTCUTS});
            app.set_accels_for_action("win." + Actions.ABOUT, {Accels.ABOUT});

            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('select')", {Accels.TOOL_SELECT});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('wall')", {Accels.TOOL_WALL});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('column')", {Accels.TOOL_COLUMN});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('bulb')", {Accels.TOOL_BULB});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('outlet')", {Accels.TOOL_OUTLET});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('faucet')", {Accels.TOOL_FAUCET});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('door')", {Accels.TOOL_DOOR});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('window')", {Accels.TOOL_WINDOW});
            app.set_accels_for_action("win." + Actions.ACTIVE_TOOL + "('furniture')", {Accels.TOOL_FURNITURE});

            app.set_accels_for_action("win." + Actions.ZOOM_IN, {Accels.ZOOM_IN});
            app.set_accels_for_action("win." + Actions.ZOOM_OUT, {Accels.ZOOM_OUT});
            app.set_accels_for_action("win." + Actions.ZOOM_RESET, {Accels.ZOOM_RESET});
        }
    }
}