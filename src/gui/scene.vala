namespace Planly {
    /**
     * Canvas principal de dibujo.
     *
     * Gestiona la lista de líneas completadas (con una superficie Cairo de
     * caché para rendimiento), la línea activa que se está dibujando, y los
     * controladores de eventos de ratón y teclado de GTK4.
     *
     * Diseño de renderizado:
     *  1. cache_surface  — superficie ARGB32 con todas las líneas terminadas.
     *  2. draw_func      — vuelca el cache, luego pinta encima la línea activa
     *                      y el panel de métricas.
     *  3. rebuild_cache  — se llama al terminar una línea o al cambiar la
     *                      selección; repinta todas las líneas desde cero.
     */
    public class Scene : Gtk.DrawingArea {

        // ── Estado de dibujo ───────────────────────────────────────────────
        private Line[]  completed_lines = {};
        private Line?   active_line     = null;
        private bool    has_dragged     = false;

        // ── Caché Cairo ────────────────────────────────────────────────────
        private Cairo.ImageSurface cache_surface;
        private Cairo.Context      cache_cr;

        // ──────────────────────────────────────────────────────────────────
        construct {
            // Inicializar superficie de caché con fondo blanco
            cache_surface = new Cairo.ImageSurface (
                Cairo.Format.ARGB32, WINDOW_WIDTH, WINDOW_HEIGHT
            );
            cache_cr = new Cairo.Context (cache_surface);
            clear_cache_to_white ();

            set_hexpand (true);
            set_vexpand (true);
            set_focusable (true);

            set_draw_func (draw_func);
            setup_controllers ();

            // Temporizador ~60 fps: repinta sólo si hay una línea activa
            GLib.Timeout.add (16, () => {
                if (active_line != null) {
                    queue_draw ();
                }
                return GLib.Source.CONTINUE;
            });
        }

        // ── Controladores de eventos ───────────────────────────────────────

        private void setup_controllers () {
            // Botón del ratón (clic / press / release)
            var click = new Gtk.GestureClick ();
            click.set_button (Gdk.BUTTON_PRIMARY);
            click.pressed.connect  (on_pressed);
            click.released.connect (on_released);
            add_controller (click);

            // Movimiento del ratón
            var motion = new Gtk.EventControllerMotion ();
            motion.motion.connect (on_motion);
            add_controller (motion);

            // Teclado
            var key = new Gtk.EventControllerKey ();
            key.key_pressed.connect  (on_key_pressed);
            key.key_released.connect (on_key_released);
            add_controller (key);
        }

        private void on_pressed (int n_press, double x, double y) {
            active_line = new Line ();
            active_line.on_mouse_pressed (x, y);
            has_dragged = false;
            grab_focus ();
        }

        private void on_released (int n_press, double x, double y) {
            if (active_line == null) return;

            active_line.on_mouse_released (x, y);

            if (has_dragged) {
                // Añadir la línea a completadas y hornearla en la caché
                completed_lines += active_line;
                rebuild_cache ();
            } else {
                // Fue un clic simple: detección de selección sobre líneas existentes
                foreach (unowned var line in completed_lines) {
                    line.on_mouse_clicked (x, y);
                }
                rebuild_cache ();
            }

            active_line = null;
            has_dragged = false;
            queue_draw ();
        }

        private void on_motion (double x, double y) {
            if (active_line == null) return;
            active_line.on_mouse_dragged (x, y);
            has_dragged = true;
        }

        private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (active_line != null) {
                active_line.on_key_pressed (keyval);
            }
            return false;
        }

        private void on_key_released (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (active_line != null) {
                active_line.on_key_released (keyval);
            }
        }

        // ── Renderizado ────────────────────────────────────────────────────

        private void draw_func (Gtk.DrawingArea area, Cairo.Context cr,
                                int width, int height)
        {
            // 1. Fondo blanco
            cr.set_source_rgb (1, 1, 1);
            cr.paint ();

            // 2. Volcar caché (líneas terminadas)
            cr.set_source_surface (cache_surface, 0, 0);
            cr.paint ();

            // 3. Línea activa
            if (active_line != null) {
                active_line.paint (cr);
                draw_metrics_panel (cr, active_line);
            }
        }

        /**
         * Dibuja el panel de métricas (píxeles, metros, grados) en la esquina
         * superior izquierda del canvas, sólo mientras se dibuja una línea.
         */
        private void draw_metrics_panel (Cairo.Context cr, Line line) {
            if (!line.has_dragged_once ()) return;

            cr.save ();

            // Fondo semitransparente
            cr.set_source_rgba (1, 1, 1, 0.88);
            cr.rectangle (10, 10, 200, 82);
            cr.fill ();

            // Borde sutil
            cr.set_source_rgba (0.6, 0.6, 0.6, 0.6);
            cr.set_line_width (0.8);
            cr.rectangle (10, 10, 200, 82);
            cr.stroke ();

            // Texto de métricas
            cr.set_source_rgb (0.1, 0.1, 0.1);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size (13);

            cr.move_to (20, 34);
            cr.show_text (_("Pixels: ") + "%.3f".printf (line.length_pixels));

            cr.move_to (20, 56);
            cr.show_text (_("Meters: ") + "%.3f".printf (line.length_metters));

            cr.move_to (20, 78);
            cr.show_text (_("Degrees: ") + "%.3f".printf (line.degrees));

            cr.restore ();
        }

        // ── Caché ──────────────────────────────────────────────────────────

        /** Repinta todas las líneas completadas sobre la superficie de caché. */
        private void rebuild_cache () {
            clear_cache_to_white ();
            foreach (unowned var line in completed_lines) {
                line.paint (cache_cr);
            }
        }

        private void clear_cache_to_white () {
            cache_cr.set_operator (Cairo.Operator.SOURCE);
            cache_cr.set_source_rgb (1, 1, 1);
            cache_cr.paint ();
            cache_cr.set_operator (Cairo.Operator.OVER);
        }
    }
}
