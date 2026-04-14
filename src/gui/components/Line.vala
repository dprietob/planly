namespace Planly
{
    /**
     * Segmento de línea dibujado en el canvas.
     *
     * Hereda de Shape el estado de selección y el modo FLATTEN (Shift).
     * En modo FLATTEN el punto final se ajusta al múltiplo de 45° más cercano.
     *
     * Métricas expuestas: longitud (px / m) y ángulo (°).
     */
    public class Line : Shape
    {
        // ── Coordenadas ────────────────────────────────────────────────────
        private double tmp_start_x;
        private double tmp_start_y;
        private double start_x;
        private double start_y;
        private double end_x;
        private double end_y;

        // ── Métricas cacheadas (actualizadas en cada drag) ─────────────────
        private float _length_pixels  = 0f;
        private float _length_metters = 0f;
        private float _degrees        = 0f;

        // ──────────────────────────────────────────────────────────────────
        public Line ()
        {
            tmp_start_x = 0; tmp_start_y = 0;
            start_x     = 0; start_y     = 0;
            end_x       = 0; end_y       = 0;
        }

        // ── Cálculos geométricos ───────────────────────────────────────────

        private double compute_length_in_pixels()
        {
            double dx = end_x - start_x;
            double dy = end_y - start_y;
            return Math.sqrt(dx * dx + dy * dy);
        }

        private double compute_degrees()
        {
            double dx  = end_x - start_x;
            double dy  = end_y - start_y;
            double deg = Math.atan2(dy, dx) * 180.0 / Math.PI;
            if (deg < 0) deg += 360.0;
            return deg;
        }

        /**
         * Ajusta el punto final al múltiplo de 45° más cercano,
         * conservando la longitud del segmento.
         */
        private void apply_flatten()
        {
            double deg = compute_degrees();
            double len = compute_length_in_pixels();

            if (deg >= 23 && deg < 68) {
                end_x = start_x + len * Math.cos(45.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin(45.0 * Math.PI / 180.0);
            } else if (deg >= 68 && deg < 113) {
                end_x = start_x;
            } else if (deg >= 113 && deg < 158) {
                end_x = start_x + len * Math.cos(135.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin(135.0 * Math.PI / 180.0);
            } else if (deg >= 158 && deg < 203) {
                end_y = start_y;
            } else if (deg >= 203 && deg < 248) {
                end_x = start_x + len * Math.cos(225.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin(225.0 * Math.PI / 180.0);
            } else if (deg >= 248 && deg < 293) {
                end_x = start_x;
            } else if (deg >= 293 && deg < 335) {
                end_x = start_x + len * Math.cos(315.0 * Math.PI / 180.0);
                end_y = start_y + len * Math.sin(315.0 * Math.PI / 180.0);
            } else {
                end_y = start_y;
            }
        }

        // ── Drawable ───────────────────────────────────────────────────────

        public override bool contains_point(double x, double y)
        {
            double dx = end_x - start_x;
            double dy = end_y - start_y;

            double denominator = Math.sqrt(dx * dx + dy * dy);
            if (denominator == 0) return false;

            double numerator = Math.fabs(dy * x - dx * y + end_x * start_y - end_y * start_x);
            if (numerator / denominator > 10.0) return false;

            double dot    = (x - start_x) * dx + (y - start_y) * dy;
            double len_sq = dx * dx + dy * dy;
            return dot >= 0 && dot <= len_sq;
        }

        public override MetricLine[] get_metrics()
        {
            return {
                       metric_px_m(_("Length"), _length_pixels),
                       metric_value(_("Angle"), "%.1f°".printf(_degrees))
            };
        }

        public override bool is_valid()
        {
            return _length_pixels > 2.0f;
        }

        public override string get_size_px()
        {
            return "%.3f px".printf(_length_pixels);
        }

        public override string get_size_m()
        {
            return "%.3f m".printf(_length_metters);
        }

        public override string get_area_m2()
        {
            return "";
        }

        public override void paint(Cairo.Context cr)
        {
            cr.save();
            cr.set_line_width(line_width);

            if (_is_selected) {
                cr.set_source_rgb(0.8, 0.1, 0.1);
            } else {
                cr.set_source_rgba(stroke_r, stroke_g, stroke_b, stroke_a);
            }

            cr.move_to(start_x, start_y);
            cr.line_to(end_x, end_y);
            cr.stroke();

            if (_is_selected) {
                cr.set_source_rgb(0.1, 0.3, 0.9);
                paint_handle(cr, start_x, start_y);
                paint_handle(cr, end_x, end_y);
            }

            cr.restore();

            // Etiqueta de longitud en el punto medio, desplazada perpendicular al segmento
            if (_length_pixels >= 30.0f) {
                double mx    = (start_x + end_x) / 2.0;
                double my    = (start_y + end_y) / 2.0;
                double angle = Math.atan2(end_y - start_y, end_x - start_x);
                double perp  = angle - Math.PI / 2.0;
                double lx    = mx + Math.cos(perp) * 14.0;
                double ly    = my + Math.sin(perp) * 14.0;
                paint_label(cr, format_m(_length_metters), lx, ly, false);
            }
        }

        public override void on_mouse_pressed(double x, double y)
        {
            tmp_start_x = x;
            tmp_start_y = y;
        }

        public override void on_mouse_released(double x, double y)
        {
            _has_started = false;
        }

        public override void on_mouse_dragged(double x, double y)
        {
            end_x = x;
            end_y = y;

            if (!_has_started) {
                start_x      = tmp_start_x;
                start_y      = tmp_start_y;
                _has_started = true;
            }

            if (draw_mode == DrawMode.FLATTEN) {
                apply_flatten();
            }

            _length_pixels  = Utils.round(compute_length_in_pixels());
            _length_metters = Utils.round(Utils.convert_to_metters(compute_length_in_pixels()));
            _degrees        = Utils.round(compute_degrees());
        }
    }
}
