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

        /**
         * Ajusta un ángulo (en grados) al múltiplo de 45° más cercano.
         * Centraliza la lógica FLATTEN usada por Line y Wall.
         */
        public static double snap_angle_deg(double deg)
        {
            if (deg < 0) deg += 360.0;
            if      (deg >= 23  && deg < 68)  return  45.0;
            else if (deg >= 68  && deg < 113) return  90.0;
            else if (deg >= 113 && deg < 158) return 135.0;
            else if (deg >= 158 && deg < 203) return 180.0;
            else if (deg >= 203 && deg < 248) return 225.0;
            else if (deg >= 248 && deg < 293) return 270.0;
            else if (deg >= 293 && deg < 338) return 315.0;
            else                              return   0.0;
        }

        /**
         * Devuelve el texto del título formateado.
         */
        public static string get_title_formatted()
        {
            string name = "<span size='18pt' weight='bold'>" + APP_NAME + "</span>";
            string version = "<small>" + Config.VERSION + "</small>";

            return name + " " + version;
        }
    }
}
