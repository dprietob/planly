namespace Planly
{
    /**
     * Clase base abstracta para todas las figuras del canvas.
     *
     * Centraliza el estado compartido (selección, modo de dibujo FLATTEN) y
     * ofrece helpers de renderizado reutilizables. Cada figura concreta hereda
     * de Shape e implementa los métodos abstractos que describen su geometría.
     */
    public abstract class Shape : GLib.Object, Drawable
    {

        // ── Estado compartido ──────────────────────────────────────────────
        protected bool     _is_selected = false;
        protected bool     _has_started = false;
        protected DrawMode draw_mode    = DrawMode.NORMAL;

        // ── Drawable: estado ──────────────────────────────────────────────
        public bool is_selected { get { return _is_selected; } }

        public void set_selected(bool selected)
        {
            _is_selected = selected;
        }

        public bool has_started()
        {
            return _has_started;
        }

        // ── Drawable: teclado (comportamiento por defecto) ─────────────────
        /**
         * Activa el modo FLATTEN al pulsar Shift.
         * Las subclases pueden sobreescribir para comportamientos adicionales.
         */
        public virtual void on_key_pressed(uint keyval)
        {
            if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                draw_mode = DrawMode.FLATTEN;
            }
        }

        public virtual void on_key_released(uint keyval)
        {
            draw_mode = DrawMode.NORMAL;
        }

        // ── Helpers de renderizado ─────────────────────────────────────────
        /**
         * Dibuja un punto de control circular (handle) en (x, y).
         * Se usa para indicar los vértices de una figura seleccionada.
         */
        protected void paint_handle(Cairo.Context cr, double x, double y)
        {
            cr.arc(x, y, 5.0, 0, 2.0 * Math.PI);
            cr.stroke();
        }

        // ── Helpers de métricas ────────────────────────────────────────────
        /**
         * Formatea un valor de píxeles y su equivalente en metros en un MetricLine.
         */
        protected MetricLine metric_px_m(string label, double px)
        {
            return {
                       label,
                       "%.3f px".printf(px),
                       "%.3f m".printf(Utils.convert_to_metters(px))
            };
        }

        /**
         * Formatea una magnitud sin equivalencia métrica (ej. ángulo en grados).
         */
        protected MetricLine metric_value(string label, string formatted)
        {
            return { label, formatted, "" };
        }

        // ── Métodos abstractos ────────────────────────────────────────────
        public abstract void           paint(Cairo.Context cr);
        public abstract bool           contains_point(double x, double y);
        public abstract MetricLine[]   get_metrics();
        public abstract bool           is_valid();
        public abstract void           on_mouse_pressed(double x, double y);
        public abstract void           on_mouse_released(double x, double y);
        public abstract void           on_mouse_dragged(double x, double y);
    }
}
