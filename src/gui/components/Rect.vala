namespace Planly
{
    /**
     * Rectángulo dibujado en el canvas.
     *
     * Se define arrastrando desde una esquina hasta la opuesta.
     * Con Shift (modo FLATTEN) el rectángulo se fuerza a cuadrado.
     *
     * Métricas: anchura (px/m), altura (px/m).
     */
    public class Rect : Shape
    {
        // ── Coordenadas ────────────────────────────────────────────────────
        private double origin_x;
        private double origin_y;
        private double corner_x;
        private double corner_y;

        // ── Métricas cacheadas ─────────────────────────────────────────────
        private float _width_px  = 0f;
        private float _height_px = 0f;

        // ──────────────────────────────────────────────────────────────────
        public Rect ()
        {
            origin_x = 0; origin_y = 0;
            corner_x = 0; corner_y = 0;
        }

        // ── Geometría derivada ─────────────────────────────────────────────

        private double left()
        {
            return double.min(origin_x, corner_x);
        }

        private double top()
        {
            return double.min(origin_y, corner_y);
        }

        private double right()
        {
            return double.max(origin_x, corner_x);
        }

        private double bottom()
        {
            return double.max(origin_y, corner_y);
        }

        private double width()
        {
            return right() - left();
        }

        private double height()
        {
            return bottom() - top();
        }

        // ── Drawable ───────────────────────────────────────────────────────

        public override bool contains_point(double x, double y)
        {
            double l = left(); double r = right();
            double t = top();  double b = bottom();
            double tol = 8.0;

            // Cerca de alguno de los 4 bordes
            bool near_left   = Math.fabs(x - l) <= tol && y >= t - tol && y <= b + tol;
            bool near_right  = Math.fabs(x - r) <= tol && y >= t - tol && y <= b + tol;
            bool near_top    = Math.fabs(y - t) <= tol && x >= l - tol && x <= r + tol;
            bool near_bottom = Math.fabs(y - b) <= tol && x >= l - tol && x <= r + tol;

            return near_left || near_right || near_top || near_bottom;
        }

        public override MetricLine[] get_metrics()
        {
            return {
                       metric_px_m(_("Width"), _width_px),
                       metric_px_m(_("Height"), _height_px)
            };
        }

        public override bool is_valid()
        {
            return _width_px > 2.0f && _height_px > 2.0f;
        }

        public override string get_size_px()
        {
            return "%.0f x %.0f px".printf(_width_px, _height_px);
        }

        public override string get_size_m()
        {
            return "%.3f x %.3f m".printf(
                DrawingMath.convert_pixels_to_meters(_width_px),
                DrawingMath.convert_pixels_to_meters(_height_px)
                );
        }

        public override string get_area_m2()
        {
            double area = DrawingMath.convert_pixels_to_meters(_width_px)
                * DrawingMath.convert_pixels_to_meters(_height_px);
            return "%.3f m\xc2\xb2".printf(area);
        }

        public override void paint(Cairo.Context cr)
        {
            double l = left(), t = top(), w = width(), h = height();
            double r = l + w, b = t + h;

            cr.save();

            // Relleno semi-transparente
            cr.set_source_rgba(fill_color_red, fill_color_green, fill_color_blue, fill_color_alpha);
            cr.rectangle(l, t, w, h);
            cr.fill_preserve();

            // Trazo (borde) con grosor y color configurables
            cr.set_line_width(line_width);
            if (_is_selected) {
                cr.set_source_rgb(0.8, 0.1, 0.1);
            } else {
                cr.set_source_rgba(stroke_color_red, stroke_color_green,
                                   stroke_color_blue, stroke_color_alpha);
            }
            cr.stroke();

            // Handles al seleccionar
            if (_is_selected) {
                cr.set_source_rgb(0.1, 0.3, 0.9);
                paint_handle(cr, l, t);
                paint_handle(cr, r, t);
                paint_handle(cr, l, b);
                paint_handle(cr, r, b);
            }

            cr.restore();

            // Etiquetas de dimension en cada lado (solo si el lado es suficientemente grande)
            if (w >= 40.0) {
                string lbl_w = format_m(DrawingMath.convert_pixels_to_meters(_width_px));
                paint_label(cr, lbl_w, l + w / 2.0, t, 0.0);
                paint_label(cr, lbl_w, l + w / 2.0, b, 0.0);
            }
            if (h >= 40.0) {
                string lbl_h = format_m(DrawingMath.convert_pixels_to_meters(_height_px));
                paint_label(cr, lbl_h, l, t + h / 2.0, -Math.PI / 2.0);
                paint_label(cr, lbl_h, r, t + h / 2.0, -Math.PI / 2.0);
            }

            // Etiqueta de area en el centro (vertical y horizontalmente)
            if (w >= 60.0 && h >= 60.0) {
                double area = DrawingMath.convert_pixels_to_meters(_width_px)
                    * DrawingMath.convert_pixels_to_meters(_height_px);
                paint_label(cr, "%.2f m\xc2\xb2".printf(area),
                    l + w / 2.0, t + h / 2.0, 0.0);
            }
        }

        public override void on_mouse_pressed(double x, double y)
        {
            origin_x = x;
            origin_y = y;
        }

        public override void on_mouse_released(double x, double y)
        {
            _has_started = false;
        }

        public override void on_mouse_dragged(double x, double y)
        {
            _has_started = true;
            corner_x = x;
            corner_y = y;

            // FLATTEN: fuerza cuadrado usando el lado más pequeño
            if (draw_mode == DrawMode.FLATTEN) {
                double dx = x - origin_x;
                double dy = y - origin_y;
                double side = double.min(Math.fabs(dx), Math.fabs(dy));
                corner_x = origin_x + (dx >= 0 ? side : -side);
                corner_y = origin_y + (dy >= 0 ? side : -side);
            }

            _width_px  = DrawingMath.round(width());
            _height_px = DrawingMath.round(height());
        }
    }
}
