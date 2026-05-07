namespace Planly
{
    /**
     * Herramientas de dibujo disponibles en la paleta.
     *
     * SELECT    — selecciona y consulta figuras existentes.
     * WALL      — dibuja muros en línea recta
     * COLUMN    — dibuja columnas.
     * BULB      — dibuja puntos de luz.
     * OUTLET    — dibuja puntos de enchufes.
     * FAUCET    — dibuja puntos de toma de agua.
     * DOOR      — dibuja puertas.
     * WINDOW    — dibuja ventanas.
     * FURNITURE — dibuja mobiliario.
     */
    public enum ToolType
    {
        SELECT = 0,
        WALL = 1,
        COLUMN = 2,
        BULB = 3,
        OUTLET = 4,
        FAUCET = 5,
        DOOR = 6,
        WINDOW = 7,
        FURNITURE = 8
    }
}
