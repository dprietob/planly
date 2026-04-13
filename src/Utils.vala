namespace Planly
{
    public class Utils
    {
        /**
         * Redondea un valor a 3 decimales.
         */
        public static float round(double value)
        {
            return (float) (Math.round(value * 1000.0) / 1000.0);
        }

        /**
         * Convierte píxeles a metros usando la escala definida en Constants.
         */
        public static double convert_to_metters(double value)
        {
            return (value * MEASURE_IN_METTERS) / MEASURE_IN_PIXELS;
        }
    }
}
