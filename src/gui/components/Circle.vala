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
                       metric_px_m(_("Radius"),   _radius_px),
                       metric_px_m(_("Diameter"), _diameter_px)
            };
        }

        public override bool is_valid()
        {
            return _radius_px > 2.0f;
        }

        public override void paint(Cairo.Context cr)
        {
            cr.save();
            cr.set_line_width(1.5);

            if (_is_selected) {
                cr.set_source_rgb(0.8, 0.1, 0.1);
            } else {
                cr.set_source_rgb(0.05, 0.05, 0.05);
            }

            cr.arc(center_x, center_y, radius, 0, 2.0 * Math.PI);
            cr.stroke();

            if (_is_selected) {
                // Handle en el centro y en el extremo derecho del radio
                cr.set_source_rgb(0.1, 0.3, 0.9);
                paint_handle(cr, center_x, center_y);
                paint_handle(cr, center_x + radius, center_y);
            }

            cr.restore();
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

            _radius_px   = Utils.round(radius);
            _diameter_px = Utils.round(radius * 2.0);
        }
    }
}
