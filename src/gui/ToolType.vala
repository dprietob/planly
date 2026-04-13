namespace Planly
{
    /**
     * Herramientas de dibujo disponibles en la paleta.
     *
     * SELECT   — selecciona y consulta figuras existentes.
     * LINE     — dibuja segmentos de línea.
     * RECT     — dibuja rectángulos (Shift: cuadrado perfecto).
     * CIRCLE   — dibuja círculos / elipses.
     * POLYGON  — dibuja polígonos de N lados (pendiente de implementar).
     */
    public enum ToolType
    {
        SELECT,
        LINE,
        RECT,
        CIRCLE,
        POLYGON
    }
}
