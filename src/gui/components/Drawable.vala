namespace Planly
{
    /**
     * Una fila del panel de métricas.
     *
     *  label     — nombre de la magnitud ("Length", "Width", "Radius"…)
     *  value_px  — valor formateado en píxeles  ("123.456 px")
     *  value_m   — valor formateado en metros   ("0.617 m")
     *              Vacío si la magnitud no tiene equivalencia métrica (ej. ángulos).
     */
    public struct MetricLine
    {
        public string label;
        public string value_px;
        public string value_m;
    }

    /**
     * Contrato que deben cumplir todos los objetos dibujables del Scene.
     *
     * Separa renderizado (Cairo), hit-testing, métricas e interacción
     * (ratón y teclado) en métodos abstractos independientes.
     */
    public interface Drawable : GLib.Object
    {
        // ── Renderizado ────────────────────────────────────────────────────
        /** Pinta la figura en el contexto Cairo proporcionado. */
        public abstract void paint(Cairo.Context cr);

        // ── Hit-testing ───────────────────────────────────────────────────
        /** Devuelve true si el punto (x, y) pertenece a la figura (con tolerancia). */
        public abstract bool contains_point(double x, double y);

        // ── Métricas ──────────────────────────────────────────────────────
        /** Magnitudes de la figura listas para mostrar en el panel de métricas. */
        public abstract MetricLine[] get_metrics();

        // ── Estado ────────────────────────────────────────────────────────
        public abstract bool is_selected { get; }
        public abstract void set_selected(bool selected);

        /** True cuando el primer evento de arrastre ya se ha producido. */
        public abstract bool has_started();

        /**
         * True si la figura tiene dimensiones suficientes para añadirse al canvas.
         * (Evita guardar puntos o figuras degeneradas.)
         */
        public abstract bool is_valid();

        // ── Eventos de ratón ──────────────────────────────────────────────
        public abstract void on_mouse_pressed(double x, double y);
        public abstract void on_mouse_released(double x, double y);
        public abstract void on_mouse_dragged(double x, double y);

        // ── Eventos de teclado ────────────────────────────────────────────
        public abstract void on_key_pressed(uint keyval);
        public abstract void on_key_released(uint keyval);
    }
}
