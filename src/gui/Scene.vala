namespace Planly
{
    /**
     * Canvas principal de dibujo.
     *
     * Gestiona la lista de figuras completadas (con una superficie Cairo de
     * caché para rendimiento), la figura activa que se está dibujando, y los
     * controladores de eventos de ratón y teclado de GTK4.
     *
     * Diseño de renderizado:
     *  1. cache_surface  — superficie ARGB32 con todas las figuras terminadas.
     *  2. draw_func      — vuelca el cache, luego pinta la figura activa
     *                      y el panel de métricas.
     *  3. rebuild_cache  — se llama al terminar una figura o cambiar selección;
     *                      repinta todas las figuras desde cero.
     *
     * Herramienta activa:
     *  - SELECT : clic selecciona / deselecciona figuras existentes.
     *  - LINE / RECT / CIRCLE : press+drag+release crea la figura.
     */
    public class Scene : Gtk.DrawingArea
    {

        // ── Estado de dibujo ───────────────────────────────────────────────
        private Shape[]  shapes      = {};
        private Shape?   active      = null;
        private bool     has_dragged = false;
        private ToolType active_tool = ToolType.LINE;

        // ── Caché Cairo ────────────────────────────────────────────────────
        private Cairo.ImageSurface cache_surface;
        private Cairo.Context      cache_cr;

        // ──────────────────────────────────────────────────────────────────
        construct {
            cache_surface = new Cairo.ImageSurface(
                Cairo.Format.ARGB32, WINDOW_WIDTH, WINDOW_HEIGHT
                );
            cache_cr = new Cairo.Context(cache_surface);
            clear_cache_to_white();

            set_hexpand(true);
            set_vexpand(true);
            set_focusable(true);

            set_draw_func(draw_func);
            setup_controllers();

            // Temporizador ~60 fps: repinta sólo si hay una figura activa
            GLib.Timeout.add(16, () => {
                if (active != null) {
                    queue_draw();
                }
                return GLib.Source.CONTINUE;
            });
        }

        // ── API pública ────────────────────────────────────────────────────

        /** Cambia la herramienta activa. Llamado desde Window. */
        public void set_tool(ToolType tool)
        {
            active_tool = tool;

            // Al cambiar a SELECT, deseleccionar todo lo activo
            if (active != null) {
                active = null;
                queue_draw();
            }
        }

        // ── Controladores de eventos ───────────────────────────────────────

        private void setup_controllers()
        {
            var click = new Gtk.GestureClick();
            click.set_button(Gdk.BUTTON_PRIMARY);
            click.pressed.connect(on_pressed);
            click.released.connect(on_released);
            add_controller(click);

            var motion = new Gtk.EventControllerMotion();
            motion.motion.connect(on_motion);
            add_controller(motion);

            var key = new Gtk.EventControllerKey();
            key.key_pressed.connect(on_key_pressed);
            key.key_released.connect(on_key_released);
            add_controller(key);
        }

        private void on_pressed(int n_press, double x, double y)
        {
            grab_focus();
            has_dragged = false;

            if (active_tool == ToolType.SELECT) return;

            active = create_shape();
            if (active != null) {
                active.on_mouse_pressed(x, y);
            }
        }

        private void on_released(int n_press, double x, double y)
        {
            if (active_tool == ToolType.SELECT) {
                // Seleccionar / deseleccionar la figura bajo el cursor
                foreach (unowned var shape in shapes) {
                    shape.set_selected(shape.contains_point(x, y));
                }
                rebuild_cache();
                queue_draw();
                return;
            }

            if (active == null) return;

            active.on_mouse_released(x, y);

            if (has_dragged && active.is_valid()) {
                shapes += active;
                rebuild_cache();
            }

            active      = null;
            has_dragged = false;
            queue_draw();
        }

        private void on_motion(double x, double y)
        {
            if (active == null) return;
            active.on_mouse_dragged(x, y);
            has_dragged = true;
        }

        private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (active != null) active.on_key_pressed(keyval);
            return false;
        }

        private void on_key_released(uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (active != null) active.on_key_released(keyval);
        }

        // ── Fábrica de figuras ─────────────────────────────────────────────

        private Shape? create_shape()
        {
            switch (active_tool) {
            case ToolType.LINE:   return new Line();
            case ToolType.RECT:   return new Rect();
            case ToolType.CIRCLE: return new Circle();
            default:              return null;
            }
        }

        // ── Renderizado ────────────────────────────────────────────────────

        private void draw_func(Gtk.DrawingArea area, Cairo.Context cr,
            int width, int height)
        {
            // 1. Fondo blanco
            cr.set_source_rgb(1, 1, 1);
            cr.paint();

            // 2. Figuras terminadas (desde caché)
            cr.set_source_surface(cache_surface, 0, 0);
            cr.paint();

            // 3. Figura activa + panel de métricas
            if (active != null && active.has_started()) {
                active.paint(cr);
                draw_metrics_panel(cr, active.get_metrics());
            }
        }

        /**
         * Panel flotante con las métricas de la figura activa.
         * El número de filas es dinámico según lo que devuelva get_metrics().
         */
        private void draw_metrics_panel(Cairo.Context cr, MetricLine[] metrics)
        {
            if (metrics.length == 0) return;

            cr.save();

            // Dimensiones dinámicas del panel
            double row_h    = 22.0;
            double pad_v    = 14.0;
            double pad_h    = 10.0;
            double panel_w  = 220.0;
            double panel_h  = pad_v * 2 + metrics.length * row_h;

            // Fondo semitransparente
            cr.set_source_rgba(1, 1, 1, 0.88);
            cr.rectangle(10, 10, panel_w, panel_h);
            cr.fill();

            // Borde sutil
            cr.set_source_rgba(0.6, 0.6, 0.6, 0.6);
            cr.set_line_width(0.8);
            cr.rectangle(10, 10, panel_w, panel_h);
            cr.stroke();

            // Texto
            cr.set_source_rgb(0.1, 0.1, 0.1);
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(12);

            for (int i = 0; i < metrics.length; i++) {
                double y = 10 + pad_v + (i + 1) * row_h - 4;

                string line_text = metrics[i].label + ":  " + metrics[i].value_px;
                if (metrics[i].value_m != "") {
                    line_text += "  /  " + metrics[i].value_m;
                }

                cr.move_to(10 + pad_h, y);
                cr.show_text(line_text);
            }

            cr.restore();
        }

        // ── Caché ──────────────────────────────────────────────────────────

        private void rebuild_cache()
        {
            clear_cache_to_white();
            foreach (unowned var shape in shapes) {
                shape.paint(cache_cr);
            }
        }

        private void clear_cache_to_white()
        {
            cache_cr.set_operator(Cairo.Operator.SOURCE);
            cache_cr.set_source_rgb(1, 1, 1);
            cache_cr.paint();
            cache_cr.set_operator(Cairo.Operator.OVER);
        }
    }
}
