namespace Planly
{
    /**
     * Canvas principal de dibujo.
     *
     * Zoom
     * ────
     * Se mantiene zoom_level (factor real, 1.0 = 100 %).  En draw_func se
     * aplica cr.scale(zoom, zoom) para escalar todo el contenido.  Los
     * eventos de ratón llegan en coordenadas de widget; se dividen por
     * zoom_level antes de pasarlos a las figuras, que siempre trabajan en
     * coordenadas lógicas (espacio del plano a escala 1:1).
     *
     * Entradas de zoom:
     *   • Ctrl + rueda del ratón   → zoom_in / zoom_out
     *   • Ctrl + = / +             → zoom_in
     *   • Ctrl + -                 → zoom_out
     *   • Ctrl + 0                 → zoom_reset
     *   • zoom_in() / zoom_out() / zoom_reset()  (llamados desde StatusBar)
     */
    public class Scene : Gtk.DrawingArea
    {
        // Zoom
        private const double ZOOM_STEP = 1.25;
        private const double ZOOM_MIN  = 0.1;
        private const double ZOOM_MAX  = 8.0;
        private double zoom_level = 1.0;

        // Estado de dibujo
        private Shape[]  shapes      = {};
        private Shape?   active      = null;
        private bool has_dragged = false;
        private ToolType active_tool = ToolType.SELECT;

        // Cache Cairo
        private Cairo.ImageSurface cache_surface;
        private Cairo.Context cache_cr;

        // Controlador de scroll (guardado para poder leer el estado de modificadores)
        private Gtk.EventControllerScroll scroll_ctrl;

        // Señales
        public signal void metrics_updated(string size_px, string size_m, string area_m2);
        public signal void zoom_changed(double level);
        public signal void tool_changed(ToolType tool);

        // ──────────────────────────────────────────────────────────────────
        construct {
            cache_surface = new Cairo.ImageSurface(
                Cairo.Format.ARGB32, WINDOW_WIDTH, WINDOW_HEIGHT
                );
            cache_cr = new Cairo.Context(cache_surface);
            clear_cache_to_white();

            set_focusable(true);
            update_size_request();

            set_draw_func(draw_func);
            setup_controllers();

            // Temporizador ~60 fps: repinta solo si hay una figura activa
            GLib.Timeout.add(16, () => {
                if (active != null) {
                    queue_draw();
                }
                return GLib.Source.CONTINUE;
            });
        }

        // API publica: herramienta

        public void set_tool(ToolType tool)
        {
            active_tool = tool;
            if (active != null) {
                active = null;
                queue_draw();
            }
        }

        // API publica: zoom

        public void zoom_in()
        {
            zoom_level = double.min(zoom_level * ZOOM_STEP, ZOOM_MAX);
            update_size_request();
            queue_draw();
            zoom_changed(zoom_level);
        }

        public void zoom_out()
        {
            zoom_level = double.max(zoom_level / ZOOM_STEP, ZOOM_MIN);
            update_size_request();
            queue_draw();
            zoom_changed(zoom_level);
        }

        public void zoom_reset()
        {
            zoom_level = 1.0;
            update_size_request();
            queue_draw();
            zoom_changed(zoom_level);
        }

        // Controladores de eventos

        private void setup_controllers()
        {
            var click = new Gtk.GestureClick();
            click.set_button(Gdk.BUTTON_PRIMARY);
            click.pressed.connect(on_pressed);
            click.released.connect(on_released);
            add_controller(click);

            var motion = new Gtk.EventControllerMotion();
            motion.motion.connect(on_motion);
            add_controller(motion);

            var key = new Gtk.EventControllerKey();
            key.key_pressed.connect(on_key_pressed);
            key.key_released.connect(on_key_released);
            add_controller(key);

            scroll_ctrl = new Gtk.EventControllerScroll(
                Gtk.EventControllerScrollFlags.VERTICAL
                );
            scroll_ctrl.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
            scroll_ctrl.scroll.connect(on_scroll);
            add_controller(scroll_ctrl);
        }

        // Convierte coordenada de widget a coordenada logica del plano
        private double to_canvas(double widget_coord)
        {
            return widget_coord / zoom_level;
        }

        private void on_pressed(int n_press, double x, double y)
        {
            grab_focus();
            has_dragged = false;

            if (active_tool == ToolType.SELECT) return;

            active = create_shape();
            if (active != null) {
                active.on_mouse_pressed(to_canvas(x), to_canvas(y));
            }
        }

        private void on_released(int n_press, double x, double y)
        {
            double cx = to_canvas(x);
            double cy = to_canvas(y);

            if (active_tool == ToolType.SELECT) {
                Shape? selected = null;
                foreach (unowned var shape in shapes) {
                    bool hit = shape.contains_point(cx, cy);
                    shape.set_selected(hit);
                    if (hit) selected = shape;
                }
                rebuild_cache();
                queue_draw();

                if (selected != null) {
                    metrics_updated(
                        selected.get_size_px(),
                        selected.get_size_m(),
                        selected.get_area_m2()
                        );
                } else {
                    metrics_updated("", "", "");
                }
                return;
            }

            if (active == null) return;

            active.on_mouse_released(cx, cy);

            if (has_dragged && active.is_valid()) {
                shapes += active;
                rebuild_cache();
            }

            active      = null;
            has_dragged = false;
            queue_draw();
            metrics_updated("", "", "");
        }

        private void on_motion(double x, double y)
        {
            if (active == null) return;
            active.on_mouse_dragged(to_canvas(x), to_canvas(y));
            has_dragged = true;

            if (active.has_started()) {
                metrics_updated(
                    active.get_size_px(),
                    active.get_size_m(),
                    active.get_area_m2()
                    );
            }
        }

        private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state)
        {
            // Atajos de zoom con Ctrl
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (keyval == '+' || keyval == '=') {
                    zoom_in();    return true;
                }
                if (keyval == '-') {
                    zoom_out();   return true;
                }
                if (keyval == '0') {
                    zoom_reset(); return true;
                }
            }

            if (active != null) active.on_key_pressed(keyval);
            return false;
        }

        private void on_key_released(uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (active != null) active.on_key_released(keyval);
        }

        private bool on_scroll(double dx, double dy)
        {
            var ev = scroll_ctrl.get_current_event();
            if (ev == null) return false;

            var mods = ev.get_modifier_state();
            if ((mods & Gdk.ModifierType.CONTROL_MASK) == 0) return false;

            if (dy < 0) zoom_in();
            else if (dy > 0) zoom_out();
            return true;
        }

        // Fabrica de figuras

        private Shape? create_shape()
        {
            switch (active_tool) {
            case ToolType.WALL: return new Line();
            case ToolType.COLUMN: return new Rect();
            case ToolType.BULB: return new Circle();
            case ToolType.OUTLET: return new Circle();
            case ToolType.DOOR: return new Circle();
            case ToolType.WINDOW: return new Circle();
            case ToolType.FAUCET: return new Circle();
            case ToolType.FURNITURE: return new Circle();
            default: return null;
            }
        }

        // Helpers internos

        private void update_size_request()
        {
            set_size_request(
                (int)(WINDOW_WIDTH  * zoom_level),
                (int)(WINDOW_HEIGHT * zoom_level)
                );
        }

        // Renderizado

        private void draw_func(Gtk.DrawingArea area, Cairo.Context cr,
            int width, int height)
        {
            // 1. Fondo blanco (sin escalar para cubrir todo el widget)
            cr.set_source_rgb(1, 1, 1);
            cr.paint();

            // 2. Aplicar transformacion de zoom al contenido del plano
            cr.scale(zoom_level, zoom_level);

            // 3. Figuras terminadas (desde cache)
            cr.set_source_surface(cache_surface, 0, 0);
            cr.paint();

            // 4. Figura activa
            if (active != null && active.has_started()) {
                active.paint(cr);
            }
        }

        // Cache

        private void rebuild_cache()
        {
            clear_cache_to_white();
            foreach (unowned var shape in shapes) {
                shape.paint(cache_cr);
            }
        }

        private void clear_cache_to_white()
        {
            cache_cr.set_operator(Cairo.Operator.SOURCE);
            cache_cr.set_source_rgb(1, 1, 1);
            cache_cr.paint();
            cache_cr.set_operator(Cairo.Operator.OVER);
        }
    }
}
