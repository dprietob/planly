namespace Planly {
    /**
     * Representa una línea dibujada en el canvas.
     *
     * Almacena sus coordenadas de inicio y fin, el modo de dibujo activo
     * (NORMAL / FLATTEN), el estado de selección y las métricas calculadas
     * (longitud en píxeles y metros, ángulo en grados).
     */
    public class Line : GLib.Object, Drawable {

        // ── Coordenadas ────────────────────────────────────────────────────
        private double tmp_start_x;
        private double tmp_start_y;
        private double start_x;
        private double start_y;
        private double end_x;
        private double end_y;
        private bool   start_cloned;

        // ── Estado ─────────────────────────────────────────────────────────
        private DrawMode draw_mode;
        public  bool     is_selected { get; private set; default = false; }

        // ── Métricas cacheadas (actualizadas en cada drag) ─────────────────
        public float length_pixels  { get; private set; default = 0f; }
        public float length_metters { get; private set; default = 0f; }
        public float degrees        { get; private set; default = 0f; }

        // ──────────────────────────────────────────────────────────────────
        public Line () {
            tmp_start_x  = 0;
            tmp_start_y  = 0;
            start_x      = 0;
            start_y      = 0;
            end_x        = 0;
            end_y        = 0;
            start_cloned = false;
            draw_mode    = DrawMode.NORMAL;
        }

        // ── Cálculos geométricos ───────────────────────────────────────────

        private double compute_length_in_pixels () {
            double dx = end_x - start_x;
            double dy = end_y - start_y;
            return Math.sqrt (dx * dx + dy * dy);
        }

        private double compute_degrees () {
            double dx  = end_x - start_x;
            double dy  = end_y - start_y;
            double deg = Math.atan2 (dy, dx) * 180.0 / Math.PI;
            if (deg < 0) deg += 360.0;
            return deg;
        }

        /**
         * Ajusta el punto final para que la línea quede en uno de los
         * 8 ángulos canónicos (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°).
         */
        private void flatten () {
            double deg = compute_degrees ();
            double len = compute_length_in_pixels ();

            if (deg >= 23 && deg < 68) {
                end_x = start_x + len * Math.cos (45.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin (45.0 * Math.PI / 180.0);
            } else if (deg >= 68 && deg < 113) {
                end_x = start_x;
            } else if (deg >= 113 && deg < 158) {
                end_x = start_x + len * Math.cos (135.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin (135.0 * Math.PI / 180.0);
            } else if (deg >= 158 && deg < 203) {
                end_y = start_y;
            } else if (deg >= 203 && deg < 248) {
                end_x = start_x + len * Math.cos (225.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin (225.0 * Math.PI / 180.0);
            } else if (deg >= 248 && deg < 293) {
                end_x = start_x;
            } else if (deg >= 293 && deg < 335) {
                end_x = start_x + len * Math.cos (315.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin (315.0 * Math.PI / 180.0);
            } else {
                end_y = start_y;
            }
        }

        /**
         * Devuelve true si el punto (x, y) está sobre el segmento,
         * con una tolerancia de 10 px.
         */
        /** Devuelve true si el arrastre ya comenzó (el punto de inicio está fijado). */
        public bool has_dragged_once () {
            return start_cloned;
        }

        public bool is_point_on_line (double x, double y) {
            double dx = end_x - start_x;
            double dy = end_y - start_y;

            double denominator = Math.sqrt (dx * dx + dy * dy);
            if (denominator == 0) return false;

            double numerator = Math.fabs (dy * x - dx * y + end_x * start_y - end_y * start_x);
            if (numerator / denominator > 10.0) return false;

            // Comprobar que el punto proyectado cae dentro del segmento
            double dot    = (x - start_x) * dx + (y - start_y) * dy;
            double len_sq = dx * dx + dy * dy;
            return dot >= 0 && dot <= len_sq;
        }

        // ── Drawable ───────────────────────────────────────────────────────

        /**
         * Pinta la línea (y los indicadores de selección si está seleccionada).
         * Las métricas (píxeles, metros, grados) las gestiona el Scene.
         */
        public void paint (Cairo.Context cr) {
            cr.save ();
            cr.set_line_width (1.5);

            if (is_selected) {
                cr.set_source_rgb (0.8, 0.1, 0.1);
            } else {
                cr.set_source_rgb (0.05, 0.05, 0.05);
            }

            cr.move_to (start_x, start_y);
            cr.line_to (end_x, end_y);
            cr.stroke ();

            if (is_selected) {
                cr.set_source_rgb (0.1, 0.3, 0.9);
                cr.arc (start_x, start_y, 5.0, 0, 2.0 * Math.PI);
                cr.stroke ();
                cr.arc (end_x, end_y, 5.0, 0, 2.0 * Math.PI);
                cr.stroke ();
            }

            cr.restore ();
        }

        public void on_mouse_clicked (double x, double y) {
            is_selected = is_point_on_line (x, y);
        }

        public void on_mouse_pressed (double x, double y) {
            tmp_start_x = x;
            tmp_start_y = y;
        }

        public void on_mouse_released (double x, double y) {
            start_cloned = false;
        }

        public void on_mouse_dragged (double x, double y) {
            end_x = x;
            end_y = y;

            if (!start_cloned) {
                start_x      = tmp_start_x;
                start_y      = tmp_start_y;
                start_cloned = true;
            }

            if (draw_mode == DrawMode.FLATTEN) {
                flatten ();
            }

            length_pixels  = Utils.round (compute_length_in_pixels ());
            length_metters = Utils.round (Utils.convert_to_metters (compute_length_in_pixels ()));
            degrees        = Utils.round (compute_degrees ());
        }

        public void on_key_pressed (uint keyval) {
            if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                draw_mode = DrawMode.FLATTEN;
            }
        }

        public void on_key_released (uint keyval) {
            draw_mode = DrawMode.NORMAL;
        }
    }
}
