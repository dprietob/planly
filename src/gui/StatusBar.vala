namespace Planly
{
    public class StatusBar : Gtk.Box
    {
        // Métricas
        private Gtk.Label lbl_size_px;
        private Gtk.Label lbl_size_m;
        private Gtk.Label lbl_area;

        // Zoom
        private Gtk.Button btn_zoom_level;
        private Gtk.Label lbl_zoom;

        // Autoguardado
        private Gtk.Label lbl_autosave;

        private GLib.DateTime? last_save_time = null;

        // Señales para comunicar acciones de zoom al Scene (desde Window)
        public signal void zoom_in_requested();
        public signal void zoom_out_requested();
        public signal void zoom_reset_requested();

        // ──────────────────────────────────────────────────────────────────
        construct {
            orientation = Gtk.Orientation.HORIZONTAL;
            spacing = 5;
            add_css_class("toolbar");

            add_metrics();
            add_units_grid();
            add_zoom_controls();
            //  add_saved();

            lbl_autosave = new Gtk.Label(_("Not saved yet"));
            lbl_autosave.add_css_class("caption");
            lbl_autosave.add_css_class("dim-label");
            lbl_autosave.valign     = Gtk.Align.CENTER;
            lbl_autosave.margin_start = 10;
            lbl_autosave.margin_end = 10;

            append(build_section_sep());
            //  append(zoom_box);
            append(build_section_sep());
            append(lbl_autosave);

            GLib.Timeout.add_seconds(60, () => {
                refresh_autosave();
                return GLib.Source.CONTINUE;
            });
        }

        /**
         * Añade el segmento de métricas del dibujo actual.
         */
        private void add_metrics()
        {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5){
                hexpand = false,
                valign = Gtk.Align.CENTER,
                margin_start = 50,
                width_request = 400
            };

            var lbl_scale = new Gtk.Label(_("Scale") + ": 1:%d".printf((int) MEASURE_IN_PIXELS));
            lbl_scale.add_css_class("caption");

            lbl_size_px = new Gtk.Label("\xe2\x80\x94");
            lbl_size_px.add_css_class("caption");

            lbl_size_m = new Gtk.Label("\xe2\x80\x94");
            lbl_size_m.add_css_class("caption");

            lbl_area = new Gtk.Label("\xe2\x80\x94");
            lbl_area.add_css_class("caption");

            box.append(lbl_scale);
            box.append(build_item_sep());
            box.append(lbl_size_px);
            box.append(build_item_sep());
            box.append(lbl_size_m);
            box.append(build_item_sep());
            box.append(lbl_area);

            append(box);
        }

        /**
         * Añade el segmento de unidades y grid.
         */
        private void add_units_grid()
        {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5){
                hexpand = true,
                valign = Gtk.Align.CENTER,
                margin_start = 10
            };

            var lbl_units = new Gtk.Label(_("Units") + ": metric");
            lbl_units.add_css_class("caption");

            var lbl_grid = new Gtk.Label(_("Grid") + ": on");
            lbl_grid.add_css_class("caption");

            box.append(lbl_units);
            box.append(build_item_sep());
            box.append(lbl_grid);

            append(box);
        }

        /**
         * Añade el segmento de control de zoom.
         */
        private void add_zoom_controls()
        {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5){
                hexpand = true,
                valign = Gtk.Align.CENTER,
                margin_start = 10
            };

            var img_zoom_out = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/zoom-out-symbolic.svg");
            img_zoom_out.set_pixel_size(16);

            // Boton zoom out (-)
            var btn_out = new Gtk.Button.with_label("-");  // signo menos tipografico
            btn_out.add_css_class("caption");
            btn_out.tooltip_text = _("Zoom out");
            btn_out.set_child(img_zoom_out);
            //  btn_out.action_name = "win." + Actions.ZOOM_OUT;
            btn_out.clicked.connect(() => zoom_out_requested());

            // Boton porcentaje / reset: usa un Gtk.Label hijo para fijar el ancho
            lbl_zoom = new Gtk.Label("100%");
            lbl_zoom.add_css_class("caption");

            btn_zoom_level = new Gtk.Button();
            btn_zoom_level.child = lbl_zoom;
            btn_zoom_level.tooltip_text = _("Reset zoom");
            //  btn_zoom_level.action_name = "win." + Actions.ZOOM_RESET;
            btn_zoom_level.clicked.connect(() => zoom_reset_requested());

            var img_zoom_in = new Gtk.Image.from_resource("/com/dprietob/planly/icons/symbolic/zoom-in-symbolic.svg");
            img_zoom_in.set_pixel_size(16);

            // Boton zoom in (+)
            var btn_in = new Gtk.Button.with_label("+");
            btn_in.add_css_class("caption");
            btn_in.tooltip_text = _("Zoom in");
            btn_in.set_child(img_zoom_in);
            btn_in.action_name = "win." + Actions.ZOOM_IN;
            //  btn_in.clicked.connect(() => zoom_in_requested());

            box.append(btn_out);
            box.append(btn_zoom_level);
            box.append(btn_in);

            append(box);
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

        private void refresh_autosave()
        {
            if (last_save_time == null) {
                lbl_autosave.label = _("Not saved yet");
                return;
            }

            var now     = new GLib.DateTime.now_local();
            int minutes = (int) (now.difference(last_save_time) / GLib.TimeSpan.MINUTE);
            string dt      = last_save_time.format("%d/%m/%Y %H:%M");

            if (minutes < 1) {
                lbl_autosave.label = _("Saved just now") + " \xc2\xb7 " + dt;
            } else if (minutes == 1) {
                lbl_autosave.label = _("Saved 1 min ago") + " \xc2\xb7 " + dt;
            } else {
                lbl_autosave.label = _("Saved %d min ago").printf(minutes) + " \xc2\xb7 " + dt;
            }
        }

        /** Separador entre elementos de una misma sección (márgenes horizontales). */
        private Gtk.Separator build_item_sep()
        {
            return new Gtk.Separator(Gtk.Orientation.VERTICAL) {
                margin_start = 6,
                margin_end   = 6,
            };
        }

        /** Separador entre secciones (márgenes verticales). */
        private Gtk.Separator build_section_sep()
        {
            return new Gtk.Separator(Gtk.Orientation.VERTICAL) {
                margin_top    = 6,
                margin_bottom = 6,
            };
        }
    }
}
