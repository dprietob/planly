namespace Planly
{
    /**
     * Interfaz que deben implementar todos los objetos dibujables del Scene.
     *
     * Separa la lógica de interacción (eventos de ratón y teclado)
     * de la lógica de renderizado (Cairo).
     */
    public interface Drawable : GLib.Object
    {
        /** Pinta el objeto en el contexto Cairo proporcionado. */
        public abstract void paint(Cairo.Context cr);

        /** Llamado cuando el usuario hace clic (press + release sin arrastre). */
        public abstract void on_mouse_clicked(double x, double y);

        /** Llamado al pulsar el botón del ratón. */
        public abstract void on_mouse_pressed(double x, double y);

        /** Llamado al soltar el botón del ratón. */
        public abstract void on_mouse_released(double x, double y);

        /** Llamado mientras se arrastra el ratón con botón pulsado. */
        public abstract void on_mouse_dragged(double x, double y);

        /** Llamado al pulsar una tecla. */
        public abstract void on_key_pressed(uint keyval);

        /** Llamado al soltar una tecla. */
        public abstract void on_key_released(uint keyval);
    }
}
