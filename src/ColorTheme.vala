/**
 * Sistema de temas de color de Planly.
 *
 * Arquitectura:
 *   AppColor       — color RGBA individual para Cairo
 *   ThemeColorSet  — paleta completa (modo claro u oscuro)
 *   ColorTheme     — singleton que carga el fichero de configuración
 *                    y expone la paleta activa según el tema elegido
 *
 * Fichero de configuración: ~/.config/planly/colors.conf
 * Si no existe se crea automáticamente con los valores predeterminados.
 */
namespace Planly
{
    /**
     * Color RGBA con valores entre 0.0 y 1.0, listo para usar con Cairo.
     */
    public struct AppColor
    {
        public double red;
        public double green;
        public double blue;
        public double alpha;

        /**
         * Aplica este color como fuente del contexto Cairo dado.
         */
        public void apply (Cairo.Context cr)
        {
            cr.set_source_rgba (red, green, blue, alpha);
        }

        /**
         * Devuelve una copia del color con un nivel de opacidad diferente.
         *
         * @param new_alpha Nuevo valor de opacidad [0.0–1.0].
         */
        public AppColor with_alpha (double new_alpha)
        {
            return { red, green, blue, new_alpha };
        }
    }

    /**
     * Paleta de colores completa para un modo de tema (claro u oscuro).
     * Cada campo corresponde a un elemento visual de la aplicación.
     */
    public struct ThemeColorSet
    {
        // ── Muro ──────────────────────────────────────────────────────────
        public AppColor wall_stroke;           // trazo normal
        public AppColor wall_fill;             // relleno del polígono cerrado
        public AppColor wall_selected;         // trazo cuando la figura está seleccionada
        public AppColor wall_preview_blocked;  // segmento de previsualización bloqueado

        // ── Handles de vértice ────────────────────────────────────────────
        public AppColor handle_vertex;         // vértice en estado normal
        public AppColor handle_vertex_active;  // vértice seleccionado con teclado
        public AppColor handle_vertex_snap;    // indicador de cierre (primer vértice)

        // ── Handles Bézier ────────────────────────────────────────────────
        public AppColor bezier_handle_dot;     // círculo del punto de control
        public AppColor bezier_tangent_line;   // línea de tangente

        // ── Caja delimitadora (modo transform) ────────────────────────────
        public AppColor bbox_outline;          // contorno punteado
        public AppColor bbox_handle_fill;      // relleno de las esquinas de resize
        public AppColor bbox_handle_stroke;    // borde de las esquinas de resize
        public AppColor bbox_rotation_line;    // línea al handle de rotación

        // ── Cotas y etiquetas ─────────────────────────────────────────────
        public AppColor dimension_line;        // línea de cota y flechas
        public AppColor label_background;      // fondo de la etiqueta de texto
        public AppColor label_text;            // texto de la etiqueta

        // ── Ángulos ───────────────────────────────────────────────────────
        public AppColor angle_arc;             // arco indicador del ángulo en el vértice

        // ── Canvas ────────────────────────────────────────────────────────
        public AppColor canvas_background;     // fondo del área de dibujo
    }

    /**
     * Gestor del tema de colores de la aplicación (singleton).
     *
     * Uso típico:
     *   ColorTheme.instance.load()               // al arrancar
     *   ColorTheme.instance.set_dark_mode(true)  // al cambiar de tema
     *   var palette = ColorTheme.instance.active  // en cada paint()
     */
    public class ColorTheme : GLib.Object
    {
        private static ColorTheme? _instance = null;

        /** Paleta de colores para modo claro. */
        public ThemeColorSet light;

        /** Paleta de colores para modo oscuro. */
        public ThemeColorSet dark;

        /** Paleta activa según el tema actual. */
        public ThemeColorSet active;

        private bool _is_dark = false;

        // ── Acceso global ─────────────────────────────────────────────────

        /**
         * Instancia única del tema. Se inicializa con valores predeterminados
         * la primera vez que se accede.
         */
        public static ColorTheme instance {
            get {
                if (_instance == null) {
                    _instance = new ColorTheme ();
                    _instance.load_defaults ();
                }
                return _instance;
            }
        }

        // ── API pública ───────────────────────────────────────────────────

        /**
         * Carga el fichero de colores del directorio de configuración del usuario.
         * Si no existe, lo crea con los valores predeterminados.
         *
         * @param file_path Ruta alternativa (null = ~/.config/planly/colors.conf).
         */
        public void load (string? file_path = null)
        {
            string path = file_path ?? build_config_path ();

            ensure_directory_exists (GLib.Path.get_dirname (path));

            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) {
                write_default_file (path);
            }

            load_defaults ();
            parse_file (path);

            // Sincronizar la paleta activa con el tema real del sistema en este momento
            set_dark_mode (Adw.StyleManager.get_default ().dark);
        }

        /**
         * Cambia la paleta activa en función del modo de tema.
         *
         * @param is_dark true para activar la paleta de modo oscuro.
         */
        public void set_dark_mode (bool is_dark)
        {
            _is_dark = is_dark;
            active   = is_dark ? dark : light;
        }

        // ── Ruta del fichero ──────────────────────────────────────────────

        private string build_config_path ()
        {
            return GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (),
                "planly", "colors.conf"
            );
        }

        private void ensure_directory_exists (string directory_path)
        {
            try {
                GLib.File.new_for_path (directory_path)
                         .make_directory_with_parents (null);
            } catch (GLib.Error e) {
                // El directorio ya existe: no es un error
            }
        }

        // ── Valores predeterminados ───────────────────────────────────────

        private void load_defaults ()
        {
            // ── Modo claro ─────────────────────────────────────────────────
            light.wall_stroke           = { 0.05, 0.05, 0.05, 1.00 };
            light.wall_fill             = { 0.28, 0.58, 0.92, 0.18 };
            light.wall_selected         = { 0.80, 0.10, 0.10, 1.00 };
            light.wall_preview_blocked  = { 0.85, 0.10, 0.10, 0.85 };
            light.handle_vertex         = { 0.05, 0.05, 0.05, 1.00 };
            light.handle_vertex_active  = { 0.10, 0.30, 0.90, 1.00 };
            light.handle_vertex_snap    = { 0.20, 0.78, 0.20, 0.90 };
            light.bezier_handle_dot     = { 0.15, 0.40, 0.90, 1.00 };
            light.bezier_tangent_line   = { 0.40, 0.40, 0.40, 0.70 };
            light.bbox_outline          = { 0.15, 0.40, 0.90, 0.70 };
            light.bbox_handle_fill      = { 1.00, 1.00, 1.00, 1.00 };
            light.bbox_handle_stroke    = { 0.15, 0.40, 0.90, 1.00 };
            light.bbox_rotation_line    = { 0.15, 0.40, 0.90, 0.50 };
            light.dimension_line        = { 0.05, 0.05, 0.05, 0.85 };
            light.label_background      = { 1.00, 1.00, 1.00, 0.88 };
            light.label_text            = { 0.10, 0.10, 0.10, 1.00 };
            light.angle_arc             = { 0.05, 0.05, 0.05, 0.75 };
            light.canvas_background     = { 1.00, 1.00, 1.00, 1.00 };

            // ── Modo oscuro ────────────────────────────────────────────────
            dark.wall_stroke            = { 0.87, 0.87, 0.87, 1.00 };
            dark.wall_fill              = { 0.28, 0.58, 0.92, 0.18 };
            dark.wall_selected          = { 1.00, 0.35, 0.35, 1.00 };
            dark.wall_preview_blocked   = { 1.00, 0.30, 0.30, 0.90 };
            dark.handle_vertex          = { 0.87, 0.87, 0.87, 1.00 };
            dark.handle_vertex_active   = { 0.40, 0.65, 1.00, 1.00 };
            dark.handle_vertex_snap     = { 0.20, 0.90, 0.20, 0.90 };
            dark.bezier_handle_dot      = { 0.25, 0.55, 1.00, 1.00 };
            dark.bezier_tangent_line    = { 0.65, 0.65, 0.65, 0.70 };
            dark.bbox_outline           = { 0.25, 0.55, 1.00, 0.70 };
            dark.bbox_handle_fill       = { 0.22, 0.22, 0.22, 1.00 };
            dark.bbox_handle_stroke     = { 0.25, 0.55, 1.00, 1.00 };
            dark.bbox_rotation_line     = { 0.25, 0.55, 1.00, 0.50 };
            dark.dimension_line         = { 0.87, 0.87, 0.87, 0.85 };
            dark.label_background       = { 0.12, 0.12, 0.12, 0.88 };
            dark.label_text             = { 0.90, 0.90, 0.90, 1.00 };
            dark.angle_arc              = { 0.87, 0.87, 0.87, 0.75 };
            dark.canvas_background      = { 0.13, 0.13, 0.13, 1.00 };

            active = light;
        }

        // ── Lectura del fichero ───────────────────────────────────────────

        /**
         * Parsea el fichero línea a línea e interpreta cada entrada de color.
         * Las líneas vacías o que empiecen por # se ignoran.
         */
        private void parse_file (string path)
        {
            string content;
            try {
                GLib.FileUtils.get_contents (path, out content);
            } catch (GLib.FileError e) {
                warning ("ColorTheme: error leyendo '%s': %s", path, e.message);
                return;
            }

            foreach (string raw_line in content.split ("\n")) {
                string line = raw_line.strip ();
                if (line.length == 0 || line.has_prefix ("#")) continue;

                string[] tokens = split_tokens (line);
                if (tokens.length < 9) continue;

                string  key          = tokens[0];
                AppColor light_color = parse_color (tokens, 1);
                AppColor dark_color  = parse_color (tokens, 5);

                apply_color_entry (key, light_color, dark_color);
            }
        }

        private string[] split_tokens (string line)
        {
            string[] result = {};
            foreach (string token in line.split_set (" \t", -1)) {
                if (token.length > 0) result += token;
            }
            return result;
        }

        private AppColor parse_color (string[] tokens, int offset)
        {
            AppColor color = { 0.0, 0.0, 0.0, 1.0 };
            color.red   = double.parse (tokens[offset]);
            color.green = double.parse (tokens[offset + 1]);
            color.blue  = double.parse (tokens[offset + 2]);
            color.alpha = double.parse (tokens[offset + 3]);
            return color;
        }

        /**
         * Asigna un par de colores (claro/oscuro) a la clave indicada.
         */
        private void apply_color_entry (string key, AppColor light_color, AppColor dark_color)
        {
            switch (key) {
            case "wall_stroke":           light.wall_stroke          = light_color; dark.wall_stroke          = dark_color; break;
            case "wall_fill":             light.wall_fill            = light_color; dark.wall_fill            = dark_color; break;
            case "wall_selected":         light.wall_selected        = light_color; dark.wall_selected        = dark_color; break;
            case "wall_preview_blocked":  light.wall_preview_blocked = light_color; dark.wall_preview_blocked = dark_color; break;
            case "handle_vertex":         light.handle_vertex        = light_color; dark.handle_vertex        = dark_color; break;
            case "handle_vertex_active":  light.handle_vertex_active = light_color; dark.handle_vertex_active = dark_color; break;
            case "handle_vertex_snap":    light.handle_vertex_snap   = light_color; dark.handle_vertex_snap   = dark_color; break;
            case "bezier_handle_dot":     light.bezier_handle_dot    = light_color; dark.bezier_handle_dot    = dark_color; break;
            case "bezier_tangent_line":   light.bezier_tangent_line  = light_color; dark.bezier_tangent_line  = dark_color; break;
            case "bbox_outline":          light.bbox_outline         = light_color; dark.bbox_outline         = dark_color; break;
            case "bbox_handle_fill":      light.bbox_handle_fill     = light_color; dark.bbox_handle_fill     = dark_color; break;
            case "bbox_handle_stroke":    light.bbox_handle_stroke   = light_color; dark.bbox_handle_stroke   = dark_color; break;
            case "bbox_rotation_line":    light.bbox_rotation_line   = light_color; dark.bbox_rotation_line   = dark_color; break;
            case "dimension_line":        light.dimension_line       = light_color; dark.dimension_line       = dark_color; break;
            case "label_background":      light.label_background     = light_color; dark.label_background     = dark_color; break;
            case "label_text":            light.label_text           = light_color; dark.label_text           = dark_color; break;
            case "angle_arc":             light.angle_arc            = light_color; dark.angle_arc            = dark_color; break;
            case "canvas_background":    light.canvas_background    = light_color; dark.canvas_background    = dark_color; break;
            default:
                warning ("ColorTheme: clave desconocida '%s'", key);
                break;
            }
        }

        // ── Fichero predeterminado ────────────────────────────────────────

        /**
         * Escribe el fichero de colores con los valores predeterminados
         * y comentarios explicativos para el usuario.
         */
        private void write_default_file (string path)
        {
            string content =
                "# Planly — Configuración de colores\n"
                + "# Formato: clave  R_claro G_claro B_claro A_claro  R_oscuro G_oscuro B_oscuro A_oscuro\n"
                + "# Valores entre 0.0 (mínimo) y 1.0 (máximo)\n"
                + "\n"
                + "# ── Muro ──────────────────────────────────────────────────────────────\n"
                + "wall_stroke          0.05 0.05 0.05 1.00   0.87 0.87 0.87 1.00\n"
                + "wall_fill            0.28 0.58 0.92 0.18   0.28 0.58 0.92 0.18\n"
                + "wall_selected        0.80 0.10 0.10 1.00   1.00 0.35 0.35 1.00\n"
                + "wall_preview_blocked 0.85 0.10 0.10 0.85   1.00 0.30 0.30 0.90\n"
                + "\n"
                + "# ── Vértices ──────────────────────────────────────────────────────────\n"
                + "handle_vertex        0.05 0.05 0.05 1.00   0.87 0.87 0.87 1.00\n"
                + "handle_vertex_active 0.10 0.30 0.90 1.00   0.40 0.65 1.00 1.00\n"
                + "handle_vertex_snap   0.20 0.78 0.20 0.90   0.20 0.90 0.20 0.90\n"
                + "\n"
                + "# ── Handles Bézier ────────────────────────────────────────────────────\n"
                + "bezier_handle_dot    0.15 0.40 0.90 1.00   0.25 0.55 1.00 1.00\n"
                + "bezier_tangent_line  0.40 0.40 0.40 0.70   0.65 0.65 0.65 0.70\n"
                + "\n"
                + "# ── Caja delimitadora (modo transform) ────────────────────────────────\n"
                + "bbox_outline         0.15 0.40 0.90 0.70   0.25 0.55 1.00 0.70\n"
                + "bbox_handle_fill     1.00 1.00 1.00 1.00   0.22 0.22 0.22 1.00\n"
                + "bbox_handle_stroke   0.15 0.40 0.90 1.00   0.25 0.55 1.00 1.00\n"
                + "bbox_rotation_line   0.15 0.40 0.90 0.50   0.25 0.55 1.00 0.50\n"
                + "\n"
                + "# ── Cotas y etiquetas ─────────────────────────────────────────────────\n"
                + "dimension_line       0.05 0.05 0.05 0.85   0.87 0.87 0.87 0.85\n"
                + "label_background     1.00 1.00 1.00 0.88   0.12 0.12 0.12 0.88\n"
                + "label_text           0.10 0.10 0.10 1.00   0.90 0.90 0.90 1.00\n"
                + "\n"
                + "# ── Ángulos ───────────────────────────────────────────────────────────\n"
                + "angle_arc            0.05 0.05 0.05 0.75   0.87 0.87 0.87 0.75\n"
                + "\n"
                + "# ── Canvas ────────────────────────────────────────────────────────────\n"
                + "canvas_background    1.00 1.00 1.00 1.00   0.13 0.13 0.13 1.00\n";

            try {
                GLib.FileUtils.set_contents (path, content);
            } catch (GLib.FileError e) {
                warning ("ColorTheme: no se pudo crear el fichero en '%s': %s", path, e.message);
            }
        }
    }
}
