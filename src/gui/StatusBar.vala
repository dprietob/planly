namespace Planly
{
    /**
     * Barra de estado inferior de Planly.
     *
     * Formato visual:
     *   Scale: 1:200 | — | — | —    Units: metric  |  [-][100%][+]  ·  Not saved yet
     *
     * Las etiquetas de métricas y el botón de porcentaje de zoom tienen
     * ancho fijo (width_chars) para evitar desplazamientos al actualizarse.
     *
     * Anchos reservados (caracteres):
     *   PX_CHARS   = 16  →  cubre "1280 x 800 px"   (13 chars)
     *   M_CHARS    = 18  →  cubre "6.400 x 4.000 m" (15 chars)
     *   AREA_CHARS = 12  →  cubre "25.600 m²"       ( 9 chars)
     *   ZOOM_CHARS =  5  →  cubre "800%"             ( 4 chars)
     */
    public class StatusBar : Gtk.Box
    {
        private const int PX_CHARS   = 16;
        private const int M_CHARS    = 18;
        private const int AREA_CHARS = 12;
        private const int ZOOM_CHARS =  5;

        // Métricas
        private Gtk.Label lbl_size_px;
        private Gtk.Label lbl_size_m;
        private Gtk.Label lbl_area;

        // Zoom
        private Gtk.Button btn_zoom_level;
        private Gtk.Label  lbl_zoom;

        // Autoguardado
        private Gtk.Label lbl_autosave;

        private GLib.DateTime? last_save_time = null;

        // Senales para comunicar acciones de zoom al Scene (desde Window)
        public signal void zoom_in_requested();
        public signal void zoom_out_requested();
        public signal void zoom_reset_requested();

        // ──────────────────────────────────────────────────────────────────
        construct {
            orientation = Gtk.Orientation.HORIZONTAL;
            spacing     = 0;
            add_css_class("toolbar");

            // ── Bloque izquierdo: metricas con ancho fijo ──────────────────
            var left = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            left.hexpand = true;
            left.valign  = Gtk.Align.CENTER;

            var lbl_scale = new Gtk.Label("Scale: 1:%d".printf((int) MEASURE_IN_PIXELS));
            add_left_item(left, lbl_scale, true);

            lbl_size_px             = new Gtk.Label("\xe2\x80\x94");
            lbl_size_px.width_chars = PX_CHARS;
            lbl_size_px.xalign      = 0.0f;
            add_left_item(left, lbl_size_px, false);

            lbl_size_m             = new Gtk.Label("\xe2\x80\x94");
            lbl_size_m.width_chars = M_CHARS;
            lbl_size_m.xalign      = 0.0f;
            add_left_item(left, lbl_size_m, false);

            lbl_area             = new Gtk.Label("\xe2\x80\x94");
            lbl_area.width_chars = AREA_CHARS;
            lbl_area.xalign      = 0.0f;
            add_left_item(left, lbl_area, false);

            // ── Bloque derecho: unidades · zoom · autoguardado ─────────────
            var lbl_units = new Gtk.Label(_("Units: metric"));
            lbl_units.add_css_class("caption");
            lbl_units.valign       = Gtk.Align.CENTER;
            lbl_units.margin_start = 16;
            lbl_units.margin_end   = 10;

            var zoom_box = build_zoom_controls();

            lbl_autosave = new Gtk.Label(_("Not saved yet"));
            lbl_autosave.add_css_class("caption");
            lbl_autosave.add_css_class("dim-label");
            lbl_autosave.valign     = Gtk.Align.CENTER;
            lbl_autosave.margin_start = 10;
            lbl_autosave.margin_end = 10;

            append(left);
            append(lbl_units);
            append(make_vsep());
            append(zoom_box);
            append(make_vsep());
            append(lbl_autosave);

            GLib.Timeout.add_seconds(60, () => {
                refresh_autosave();
                return GLib.Source.CONTINUE;
            });
        }

        // ── API publica ────────────────────────────────────────────────────

        public void update_metrics(string size_px, string size_m, string area_m2)
        {
            lbl_size_px.label = size_px.length > 0 ? size_px : "\xe2\x80\x94";
            lbl_size_m.label  = size_m.length  > 0 ? size_m  : "\xe2\x80\x94";
            lbl_area.label    = area_m2.length  > 0 ? area_m2 : "\xe2\x80\x94";
        }

        /** Actualiza el porcentaje de zoom. Llamado por Scene.zoom_changed. */
        public void update_zoom(double level)
        {
            lbl_zoom.label = "%.0f%%".printf(level * 100.0);
        }

        public void register_save()
        {
            last_save_time = new GLib.DateTime.now_local();
            refresh_autosave();
        }

        // ── Internos ──────────────────────────────────────────────────────

        private Gtk.Box build_zoom_controls()
        {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            box.valign = Gtk.Align.CENTER;

            // Boton zoom out (-)
            var btn_out = new Gtk.Button.with_label("\xe2\x88\x92");  // signo menos tipografico
            btn_out.add_css_class("flat");
            btn_out.add_css_class("caption");
            btn_out.tooltip_text   = _("Zoom out (Ctrl+-)");
            btn_out.width_request  = 28;
            btn_out.height_request = 24;
            btn_out.clicked.connect(() => zoom_out_requested());

            // Boton porcentaje / reset: usa un Gtk.Label hijo para fijar el ancho
            lbl_zoom             = new Gtk.Label("100%");
            lbl_zoom.add_css_class("caption");
            lbl_zoom.width_chars = ZOOM_CHARS;
            lbl_zoom.xalign      = 0.5f;

            btn_zoom_level = new Gtk.Button();
            btn_zoom_level.child          = lbl_zoom;
            btn_zoom_level.add_css_class("flat");
            btn_zoom_level.tooltip_text   = _("Reset zoom (Ctrl+0)");
            btn_zoom_level.height_request = 24;
            btn_zoom_level.clicked.connect(() => zoom_reset_requested());

            // Boton zoom in (+)
            var btn_in = new Gtk.Button.with_label("+");
            btn_in.add_css_class("flat");
            btn_in.add_css_class("caption");
            btn_in.tooltip_text   = _("Zoom in (Ctrl+=)");
            btn_in.width_request  = 28;
            btn_in.height_request = 24;
            btn_in.clicked.connect(() => zoom_in_requested());

            box.append(btn_out);
            box.append(btn_zoom_level);
            box.append(btn_in);
            return box;
        }

        private void refresh_autosave()
        {
            if (last_save_time == null) {
                lbl_autosave.label = _("Not saved yet");
                return;
            }

            var    now     = new GLib.DateTime.now_local();
            int    minutes = (int) (now.difference(last_save_time) / GLib.TimeSpan.MINUTE);
            string dt      = last_save_time.format("%d/%m/%Y %H:%M");

            if (minutes < 1) {
                lbl_autosave.label = _("Saved just now") + " \xc2\xb7 " + dt;
            } else if (minutes == 1) {
                lbl_autosave.label = _("Saved 1 min ago") + " \xc2\xb7 " + dt;
            } else {
                lbl_autosave.label = _("Saved %d min ago").printf(minutes) + " \xc2\xb7 " + dt;
            }
        }

        private void add_left_item(Gtk.Box box, Gtk.Label lbl, bool is_first)
        {
            if (!is_first) {
                box.append(make_vsep());
            }
            lbl.add_css_class("caption");
            lbl.valign       = Gtk.Align.CENTER;
            lbl.margin_start = 10;
            lbl.margin_end   = 10;
            box.append(lbl);
        }

        private Gtk.Separator make_vsep()
        {
            var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
            sep.margin_top    = 6;
            sep.margin_bottom = 6;
            return sep;
        }
    }
}
