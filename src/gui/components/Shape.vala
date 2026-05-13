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
        // Estado compartido
        protected bool _is_selected = false;
        protected bool _has_started = false;
        protected DrawMode draw_mode    = DrawMode.NORMAL;

        /**
         * Controla si se dibujan los handles de vértice en paint().
         * true  = modo edición de vértices (doble clic en SELECT)
         * false = modo transformación (clic simple en SELECT)
         */
        public bool vertex_handles_visible = false;

        // Estilo: grosor de linea, color de trazo y color de relleno.
        // Publicos para permitir edicion externa desde un futuro panel de propiedades.
        public double stroke_r   = 0.05;
        public double stroke_g   = 0.05;
        public double stroke_b   = 0.05;
        public double stroke_a   = 1.0;
        public double fill_r     = 0.28;
        public double fill_g     = 0.58;
        public double fill_b     = 0.92;
        public double fill_a     = 0.18;
        public double line_width = 1.5;

        // Drawable: estado
        public bool is_selected { get { return _is_selected; } }

        public void set_selected(bool selected)
        {
            _is_selected = selected;
        }

        public bool has_started()
        {
            return _has_started;
        }

        // Drawable: teclado (comportamiento por defecto)
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

        // Helpers de renderizado
        /**
         * Dibuja un punto de control circular (handle) en (x, y).
         * Se usa para indicar los vértices de una figura seleccionada.
         */
        protected void paint_handle(Cairo.Context cr, double x, double y)
        {
            cr.arc(x, y, 5.0, 0, 2.0 * Math.PI);
            cr.stroke();
        }

        // Helpers de metricas (panel flotante get_metrics)
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

        // Barra de estado: metodos virtuales por figura
        /**
         * Texto de "tamaño en píxeles" para la barra de estado inferior.
         * Ej: "123.456 px"  o  "200 × 150 px"
         */
        public virtual string get_size_px()
        {
            return "";
        }

        /**
         * Texto de "tamaño en metros" para la barra de estado inferior.
         * Ej: "0.617 m"  o  "1.000 × 0.750 m"
         */
        public virtual string get_size_m()
        {
            return "";
        }

        /**
         * Texto de "área en m²" para la barra de estado inferior.
         * Vacío para figuras sin área (p. ej. líneas).
         */
        public virtual string get_area_m2()
        {
            return "";
        }

        // Helpers de etiquetas de dimension

        /**
         * Formatea un valor en metros con precision adaptativa:
         *   2.000 → "2m"    2.500 → "2.5m"    2.253 → "2.25m"
         */
        protected string format_m(double meters)
        {
            double v = Math.round(meters * 100.0) / 100.0;
            if (Math.fabs(v - Math.round(v)) < 0.005) {
                return "%.0fm".printf(v);
            }
            double v1 = Math.round(v * 10.0) / 10.0;
            if (Math.fabs(v - v1) < 0.005) {
                return "%.1fm".printf(v);
            }
            return "%.2fm".printf(v);
        }

        /**
         * Pinta un texto centrado en (cx, cy) rotado angle radianes.
         * angle = 0  → horizontal   |  angle = -π/2 → vertical ascendente
         * El ángulo se normaliza para que el texto nunca quede boca abajo.
         */
        protected void paint_label(Cairo.Context cr, string text,
            double cx, double cy, double angle = 0.0)
        {
            double font_size = 11.0;
            double pad       = 2.5;

            // Normalizar: mantener el ángulo en (-π/2, π/2] para legibilidad
            double a = angle;
            while (a >  Math.PI / 2.0) a -= Math.PI;
            while (a < -Math.PI / 2.0) a += Math.PI;

            cr.save();
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(font_size);

            Cairo.TextExtents te;
            cr.text_extents(text, out te);

            cr.translate(cx, cy);
            cr.rotate(a);

            double tx = -te.x_bearing - te.width  / 2.0;
            double ty = -te.y_bearing - te.height / 2.0;

            // Fondo blanco semitransparente
            cr.set_source_rgba(1.0, 1.0, 1.0, 0.88);
            cr.rectangle(tx + te.x_bearing - pad,
                ty + te.y_bearing - pad,
                te.width  + pad * 2.0,
                te.height + pad * 2.0);
            cr.fill();

            // Texto
            cr.set_source_rgb(0.1, 0.1, 0.1);
            cr.move_to(tx, ty);
            cr.show_text(text);

            cr.restore();
        }

        /**
         * Devuelve true si (x, y) cae sobre un handle de edición (vértice).
         * Las figuras con vértices arrastrables sobreescriben este método.
         */
        public virtual bool has_handle_at (double x, double y)
        {
            return false;
        }

        // ── Transformaciones (sobreescribir en figuras concretas) ──────────

        /** Desplaza la figura (dx, dy) en coordenadas lógicas. */
        public virtual void translate (double dx, double dy) {}

        /** Caja delimitadora alineada con los ejes en coordenadas lógicas. */
        public virtual BBoxRect get_bbox ()
        {
            return { 0.0, 0.0, 0.0, 0.0 };
        }

        /** Puntos de anclaje X para el snapping de vértices con Shift. */
        public virtual double[] get_snap_xs () { return {}; }

        /** Puntos de anclaje Y para el snapping de vértices con Shift. */
        public virtual double[] get_snap_ys () { return {}; }

        // Metodos abstractos
        public abstract void           paint(Cairo.Context cr);
        public abstract bool           contains_point(double x, double y);
        public abstract MetricLine[]   get_metrics();
        public abstract bool           is_valid();
        public abstract void           on_mouse_pressed(double x, double y);
        public abstract void           on_mouse_released(double x, double y);
        public abstract void           on_mouse_dragged(double x, double y);
    }
}
