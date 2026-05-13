namespace Planly
{
    /**
     * Círculo dibujado en el canvas.
     *
     * Se define arrastrando desde el centro hasta cualquier punto del borde.
     * El modo FLATTEN no aplica: un círculo es siempre perfecto.
     *
     * Métricas: radio (px/m) y diámetro (px/m).
     */
    public class Circle : Shape
    {
        // ── Coordenadas ────────────────────────────────────────────────────
        private double center_x;
        private double center_y;
        private double radius;

        // ── Métricas cacheadas ─────────────────────────────────────────────
        private float _radius_px   = 0f;
        private float _diameter_px = 0f;

        // ──────────────────────────────────────────────────────────────────
        public Circle ()
        {
            center_x = 0; center_y = 0; radius = 0;
        }

        // ── Drawable ───────────────────────────────────────────────────────

        public override bool contains_point(double x, double y)
        {
            double dx   = x - center_x;
            double dy   = y - center_y;
            double dist = Math.sqrt(dx * dx + dy * dy);
            return Math.fabs(dist - radius) <= 10.0;
        }

        public override MetricLine[] get_metrics()
        {
            return {
                       metric_px_m(_("Radius"), _radius_px),
                       metric_px_m(_("Diameter"), _diameter_px)
            };
        }

        public override bool is_valid()
        {
            return _radius_px > 2.0f;
        }

        public override string get_size_px()
        {
            return "r: %.3f px".printf(_radius_px);
        }

        public override string get_size_m()
        {
            return "r: %.3f m".printf(DrawingMath.convert_pixels_to_meters(_radius_px));
        }

        public override string get_area_m2()
        {
            double r_m = DrawingMath.convert_pixels_to_meters(_radius_px);
            return "%.3f m\xc2\xb2".printf(Math.PI * r_m * r_m);
        }

        public override void paint(Cairo.Context cr)
        {
            cr.save();

            // Relleno semi-transparente
            cr.set_source_rgba(fill_color_red, fill_color_green, fill_color_blue, fill_color_alpha);
            cr.arc(center_x, center_y, radius, 0, 2.0 * Math.PI);
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

            if (_is_selected) {
                // Handle en el centro y en el extremo derecho del radio
                cr.set_source_rgb(0.1, 0.3, 0.9);
                paint_handle(cr, center_x, center_y);
                paint_handle(cr, center_x + radius, center_y);
            }

            cr.restore();

            // Etiqueta de diametro en la parte superior del circulo
            // "\xe2\x8c\x80" = caracter de diametro (⌀)
            if (radius >= 20.0) {
                double d_m = DrawingMath.convert_pixels_to_meters(_diameter_px);
                paint_label(cr, "\xe2\x8c\x80 " + format_m(d_m),
                    center_x, center_y - radius, 0.0);
            }

            // Etiqueta de area en el centro
            if (radius >= 30.0) {
                double r_m  = DrawingMath.convert_pixels_to_meters(_radius_px);
                double area = Math.PI * r_m * r_m;
                paint_label(cr, "%.2f m\xc2\xb2".printf(area),
                    center_x, center_y, 0.0);
            }
        }

        public override void on_mouse_pressed(double x, double y)
        {
            center_x = x;
            center_y = y;
            radius   = 0;
        }

        public override void on_mouse_released(double x, double y)
        {
            _has_started = false;
        }

        public override void on_mouse_dragged(double x, double y)
        {
            _has_started = true;
            double dx = x - center_x;
            double dy = y - center_y;
            radius = Math.sqrt(dx * dx + dy * dy);

            _radius_px   = DrawingMath.round(radius);
            _diameter_px = DrawingMath.round(radius * 2.0);
        }
    }
}
