namespace Planly
{
    /**
     * Canvas principal de dibujo.
     *
     * Zoom
     * ────
     * zoom_level (factor real, 1.0 = 100%).  En draw_func se aplica
     * cr.scale(zoom, zoom).  Los eventos de ratón se dividen por zoom_level
     * antes de pasarlos a las figuras (coordenadas lógicas del plano).
     *
     * Herramienta WALL — modelo clic-a-clic
     * ──────────────────────────────────────
     *   Clic            → colocar vértice / iniciar muro
     *   Movimiento      → previsualización del segmento
     *   Doble clic      → finalizar muro (abierto)
     *   Doble clic cerca del origen → cerrar polígono
     *   Escape          → cancelar
     *
     * Herramienta SELECT — dos modos de edición
     * ──────────────────────────────────────────
     *   MODO TRANSFORM  (clic simple sobre figura)
     *     Arrastrar cuerpo   → mover
     *     Arrastrar esquina  → redimensionar
     *     Arrastrar ⟳        → rotar
     *
     *   MODO VÉRTICES   (doble clic sobre figura)
     *     Arrastrar vértice  → mover vértice
     *     Shift vertical     → snap X al vértice más cercano
     *     Shift horizontal   → snap Y al vértice más cercano
     *     Clic en cuerpo     → volver a MODO TRANSFORM
     *     Escape             → volver a MODO TRANSFORM
     *
     *   Clic en vacío → deseleccionar
     */
    public class Scene : Gtk.DrawingArea
    {
        // ── Zoom ──────────────────────────────────────────────────────────
        private const double ZOOM_STEP = 1.25;
        private const double ZOOM_MIN  = 0.1;
        private const double ZOOM_MAX  = 8.0;
        private double zoom_level = 1.0;

        // ── Figuras y dibujo drag-based ───────────────────────────────────
        private Shape[]  shapes      = {};
        private Shape?   active      = null;
        private bool     has_dragged = false;
        private ToolType active_tool = ToolType.SELECT;

        // ── Muro en curso (clic-a-clic) ───────────────────────────────────
        private Wall? wall_active = null;

        // ── Selección ─────────────────────────────────────────────────────
        private Shape? sel_shape = null;

        /**
         * Modo de edición de la figura seleccionada:
         *   0 = ninguna selección
         *   1 = TRANSFORM (bbox + handles de esquina/rotación)
         *   2 = VÉRTICES  (handles de vértice, sin bbox)
         */
        private int sel_mode = 0;

        // Interacción activa:
        //   0=ninguna  1=mover  2=resize  3=rotar  4=vértice  5=handle Bézier
        private int    sel_interact  = 0;
        private double sel_press_x   = 0.0;
        private double sel_press_y   = 0.0;

        // Resize
        private int    resize_corner   = -1;
        private double resize_anchor_x = 0.0;
        private double resize_anchor_y = 0.0;
        private double resize_orig_w   = 0.0;
        private double resize_orig_h   = 0.0;

        // Rotación
        private double rot_cx         = 0.0;
        private double rot_cy         = 0.0;
        private double rot_orig_angle = 0.0;

        // Snapshot unificado (vértices + datos Bézier) para resize/rotate
        private double[] trans_snap_vx  = {};
        private double[] trans_snap_vy  = {};
        private bool[]   trans_snap_bez_in  = {};
        private bool[]   trans_snap_bez_out = {};
        private double[] trans_snap_cox = {};
        private double[] trans_snap_coy = {};
        private double[] trans_snap_cix = {};
        private double[] trans_snap_ciy = {};

        // Vértice arrastrado (durante drag)
        private int vert_drag_idx = -1;

        // Vértice seleccionado para control por teclado (-1 = ninguno)
        private int sel_vertex_idx = -1;

        // Bézier: handle arrastrado
        private int  bezier_vert_idx = -1;
        private bool bezier_is_out   = false;

        // Shift para snapping
        private bool shift_pressed = false;

        // ── Handles de transformación ─────────────────────────────────────
        private const double TH_SIZE  = 5.0;
        private const double ROT_DIST = 28.0;

        // ── Cache Cairo ───────────────────────────────────────────────────
        private Cairo.ImageSurface cache_surface;
        private Cairo.Context      cache_cr;

        // ── Controladores de eventos ──────────────────────────────────────
        private Gtk.EventControllerScroll scroll_ctrl;
        private Gtk.EventControllerMotion motion_ctrl;

        // ── Señales ───────────────────────────────────────────────────────
        public signal void metrics_updated (string size_px, string size_m, string area_m2);
        public signal void zoom_changed    (double level);
        public signal void tool_changed    (ToolType tool);

        // ──────────────────────────────────────────────────────────────────
        construct {
            cache_surface = new Cairo.ImageSurface (
                Cairo.Format.ARGB32, WINDOW_WIDTH, WINDOW_HEIGHT
                );
            cache_cr = new Cairo.Context (cache_surface);
            clear_cache_to_white ();

            set_focusable (true);
            update_size_request ();
            set_draw_func (draw_func);
            setup_controllers ();

            GLib.Timeout.add (16, () => {
                if (active != null || wall_active != null) queue_draw ();
                return GLib.Source.CONTINUE;
            });
        }

        // ── API pública ───────────────────────────────────────────────────

        public void set_tool (ToolType tool)
        {
            active_tool  = tool;
            active       = null;
            wall_active  = null;
            sel_interact = 0;
            queue_draw ();
        }

        public void zoom_in ()
        {
            zoom_level = double.min (zoom_level * ZOOM_STEP, ZOOM_MAX);
            update_size_request (); queue_draw (); zoom_changed (zoom_level);
        }

        public void zoom_out ()
        {
            zoom_level = double.max (zoom_level / ZOOM_STEP, ZOOM_MIN);
            update_size_request (); queue_draw (); zoom_changed (zoom_level);
        }

        public void zoom_reset ()
        {
            zoom_level = 1.0;
            update_size_request (); queue_draw (); zoom_changed (zoom_level);
        }

        // ── Controladores ────────────────────────────────────────────────

        private void setup_controllers ()
        {
            var click = new Gtk.GestureClick ();
            click.set_button (Gdk.BUTTON_PRIMARY);
            click.pressed.connect  (on_pressed);
            click.released.connect (on_released);
            add_controller (click);

            motion_ctrl = new Gtk.EventControllerMotion ();
            motion_ctrl.motion.connect (on_motion);
            add_controller (motion_ctrl);

            var key = new Gtk.EventControllerKey ();
            key.key_pressed.connect  (on_key_pressed);
            key.key_released.connect (on_key_released);
            add_controller (key);

            scroll_ctrl = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.VERTICAL
                );
            scroll_ctrl.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            scroll_ctrl.scroll.connect (on_scroll);
            add_controller (scroll_ctrl);
        }

        private double to_canvas (double wc) { return wc / zoom_level; }

        // ── on_pressed ────────────────────────────────────────────────────

        private void on_pressed (int n_press, double x, double y)
        {
            grab_focus ();
            double cx = to_canvas (x);
            double cy = to_canvas (y);

            if (active_tool == ToolType.WALL) {
                handle_wall_click (n_press, cx, cy);
                return;
            }

            if (active_tool == ToolType.SELECT) {
                on_select_press (n_press, cx, cy);
                return;
            }

            has_dragged = false;
            active      = create_shape ();
            if (active != null) active.on_mouse_pressed (cx, cy);
        }

        private void on_select_press (int n_press, double cx, double cy)
        {
            // ── Doble clic ────────────────────────────────────────────────
            if (n_press == 2) {
                // Modo vértices + doble clic
                if (sel_mode == 2 && sel_shape is Wall) {
                    var wall = (Wall) sel_shape;
                    int vi = wall.find_vertex (cx, cy);
                    if (vi >= 0) {
                        // Doble clic en vértice → activar/desactivar handles Bézier
                        sel_interact = 0;
                        wall.toggle_bezier (vi);
                        rebuild_cache ();
                        queue_draw ();
                        return;
                    }
                    // Doble clic en segmento → insertar vértice nuevo
                    if (!wall.has_handle_at (cx, cy)) {
                        double proj_x, proj_y;
                        int seg = wall.find_segment_at (cx, cy, 10.0, out proj_x, out proj_y);
                        if (seg >= 0) {
                            int new_idx   = wall.insert_vertex (seg, proj_x, proj_y);
                            vert_drag_idx = new_idx;
                            sel_interact  = 4;
                            sel_press_x   = proj_x;
                            sel_press_y   = proj_y;
                            rebuild_cache ();
                            queue_draw ();
                            return;
                        }
                    }
                }

                if (sel_shape != null &&
                    (sel_shape.contains_point (cx, cy) ||
                     sel_shape.has_handle_at (cx, cy))) {
                    // Doble clic sobre la figura seleccionada → modo vértices
                    sel_interact = 0; // cancelar el movimiento que inició n_press=1
                    enter_vertex_mode ();
                } else {
                    // Doble clic sobre otra figura → seleccionar en transform
                    Shape? hit = hit_shape (cx, cy);
                    if (hit != null && hit != sel_shape) {
                        do_select (hit);
                        enter_transform_mode ();
                    }
                }
                return;
            }

            // ── Clic simple ───────────────────────────────────────────────

            // Modo vértices activo
            if (sel_mode == 2 && sel_shape != null) {
                if (sel_shape is Wall) {
                    var wall_v = (Wall) sel_shape;

                    // 1. Comprobar handle Bézier (prioridad sobre vértice)
                    bool biz_out;
                    int biz = wall_v.find_bezier_handle (cx, cy, out biz_out);
                    if (biz >= 0) {
                        bezier_vert_idx = biz;
                        bezier_is_out   = biz_out;
                        sel_interact    = 5;
                        sel_press_x     = cx;
                        sel_press_y     = cy;
                        return;
                    }

                    // 2. Comprobar vértice
                    int vi = wall_v.find_vertex (cx, cy);
                    if (vi >= 0) {
                        sel_vertex_idx         = vi;
                        wall_v.selected_vertex = vi;
                        vert_drag_idx          = vi;
                        sel_interact           = 4;
                        sel_press_x            = cx;
                        sel_press_y            = cy;
                        rebuild_cache ();
                        queue_draw ();
                        return;
                    }
                }
                // Clic en el cuerpo (no en vértice) → no cambia de modo;
                // el doble clic sobre el segmento insertará un vértice nuevo
                if (sel_shape.contains_point (cx, cy)) {
                    return;
                }
                // Clic fuera → hit-test general
            }

            // Modo transform: comprobar handles de la figura seleccionada
            if (sel_mode == 1 && sel_shape != null) {
                var b  = sel_shape.get_bbox ();
                double rx = b.x + b.w / 2.0;
                double ry = b.y - ROT_DIST;

                // Handle de rotación
                if (dist2 (cx, cy, rx, ry) <= (TH_SIZE + 3) * (TH_SIZE + 3)) {
                    sel_interact   = 3;
                    sel_press_x    = cx;
                    sel_press_y    = cy;
                    rot_cx         = b.x + b.w / 2.0;
                    rot_cy         = b.y + b.h / 2.0;
                    rot_orig_angle = Math.atan2 (cy - rot_cy, cx - rot_cx);
                    take_transform_snapshot ();
                    return;
                }

                // Handles de redimensionado
                int h = hit_resize_handle (b, cx, cy);
                if (h >= 0) {
                    start_resize (h, b, cx, cy);
                    return;
                }
            }

            // Hit-test general → seleccionar + iniciar movimiento
            Shape? hit = hit_shape (cx, cy);
            do_select (hit);
            if (hit != null) {
                enter_transform_mode ();
                sel_interact = 1;
                sel_press_x  = cx;
                sel_press_y  = cy;
                metrics_updated (hit.get_size_px (), hit.get_size_m (), hit.get_area_m2 ());
            } else {
                sel_mode     = 0;
                sel_interact = 0;
                metrics_updated ("", "", "");
            }
        }

        // ── on_released ───────────────────────────────────────────────────

        private void on_released (int n_press, double x, double y)
        {
            double cx = to_canvas (x);
            double cy = to_canvas (y);

            if (active_tool == ToolType.SELECT) {
                sel_interact    = 0;
                resize_corner   = -1;
                vert_drag_idx   = -1;
                bezier_vert_idx = -1;
                rebuild_cache ();
                queue_draw ();
                if (sel_shape != null) {
                    metrics_updated (
                        sel_shape.get_size_px (),
                        sel_shape.get_size_m (),
                        sel_shape.get_area_m2 ()
                        );
                }
                return;
            }

            if (active == null) return;
            active.on_mouse_released (cx, cy);
            if (has_dragged && active.is_valid ()) {
                shapes += active;
                rebuild_cache ();
            }
            active      = null;
            has_dragged = false;
            queue_draw ();
            metrics_updated ("", "", "");
        }

        // ── on_motion ─────────────────────────────────────────────────────

        private void on_motion (double x, double y)
        {
            double cx = to_canvas (x);
            double cy = to_canvas (y);

            var ev = motion_ctrl.get_current_event ();
            if (ev != null) {
                var mods  = ev.get_modifier_state ();
                shift_pressed = (mods & Gdk.ModifierType.SHIFT_MASK) != 0;
            }

            if (wall_active != null) {
                wall_active.update_preview (cx, cy);
                queue_draw ();
                metrics_updated (
                    wall_active.get_size_px (),
                    wall_active.get_size_m (),
                    wall_active.get_area_m2 ()
                    );
                return;
            }

            if (active_tool == ToolType.SELECT && sel_shape != null) {
                switch (sel_interact) {
                case 1: do_move   (cx, cy); return;
                case 2: do_resize (cx, cy); return;
                case 3: do_rotate (cx, cy); return;
                case 4: do_vertex (cx, cy); return;
                case 5: do_bezier (cx, cy); return;
                }
                return;
            }

            if (active == null) return;
            active.on_mouse_dragged (cx, cy);
            has_dragged = true;
            if (active.has_started ()) {
                metrics_updated (
                    active.get_size_px (),
                    active.get_size_m (),
                    active.get_area_m2 ()
                    );
            }
        }

        // ── Lógica WALL ───────────────────────────────────────────────────

        private void handle_wall_click (int n_press, double cx, double cy)
        {
            if (n_press == 2) {
                if (wall_active == null) return;
                wall_active.remove_last_vertex ();

                if (wall_active.near_first_vertex (cx, cy)) {
                    wall_active.close ();
                } else if (wall_active.vertex_count >= 2) {
                    wall_active.finish ();
                } else {
                    wall_active = null;
                    queue_draw ();
                    metrics_updated ("", "", "");
                    return;
                }

                shapes += wall_active;
                rebuild_cache ();
                wall_active = null;
                queue_draw ();
                metrics_updated ("", "", "");
                return;
            }

            if (wall_active == null) {
                wall_active = new Wall ();
                wall_active.start_draw (cx, cy);
            } else if (wall_active.near_first_vertex (cx, cy)) {
                // Clic sobre el círculo verde → cerrar polígono
                wall_active.close ();
                shapes += wall_active;
                rebuild_cache ();
                wall_active = null;
                metrics_updated ("", "", "");
            } else {
                wall_active.add_vertex (cx, cy);
            }
            queue_draw ();
        }

        // ── Transformaciones SELECT ───────────────────────────────────────

        private void do_move (double cx, double cy)
        {
            double dx = cx - sel_press_x;
            double dy = cy - sel_press_y;
            sel_shape.translate (dx, dy);
            sel_press_x = cx;
            sel_press_y = cy;
            rebuild_cache ();
            queue_draw ();
            metrics_updated (sel_shape.get_size_px (), sel_shape.get_size_m (), sel_shape.get_area_m2 ());
        }

        private void do_resize (double cx, double cy)
        {
            if (!(sel_shape is Wall)) return;
            var wall = (Wall) sel_shape;
            wall.restore_full_snapshot (trans_snap_vx, trans_snap_vy,
                                        trans_snap_bez_in, trans_snap_bez_out,
                                        trans_snap_cox, trans_snap_coy,
                                        trans_snap_cix, trans_snap_ciy);
            double sx = resize_orig_w > 1.0
                ? double.max (Math.fabs (cx - resize_anchor_x) / resize_orig_w, 0.01) : 1.0;
            double sy = resize_orig_h > 1.0
                ? double.max (Math.fabs (cy - resize_anchor_y) / resize_orig_h, 0.01) : 1.0;
            wall.scale_vertices (sx, sy, resize_anchor_x, resize_anchor_y);
            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        private void do_rotate (double cx, double cy)
        {
            if (!(sel_shape is Wall)) return;
            var wall = (Wall) sel_shape;
            wall.restore_full_snapshot (trans_snap_vx, trans_snap_vy,
                                        trans_snap_bez_in, trans_snap_bez_out,
                                        trans_snap_cox, trans_snap_coy,
                                        trans_snap_cix, trans_snap_ciy);
            double delta = Math.atan2 (cy - rot_cy, cx - rot_cx) - rot_orig_angle;
            wall.rotate_vertices (delta, rot_cx, rot_cy);
            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        private void do_bezier (double cx, double cy)
        {
            if (!(sel_shape is Wall)) return;
            ((Wall) sel_shape).move_bezier_cp (bezier_vert_idx, bezier_is_out, cx, cy);
            rebuild_cache ();
            queue_draw ();
        }

        private void do_vertex (double cx, double cy)
        {
            if (!(sel_shape is Wall)) return;
            var wall = (Wall) sel_shape;

            double fx = cx, fy = cy;
            if (shift_pressed) {
                double tdx = cx - sel_press_x;
                double tdy = cy - sel_press_y;
                if (Math.fabs (tdy) >= Math.fabs (tdx)) {
                    fx = snap_nearest_x (cx, wall, vert_drag_idx);
                } else {
                    fy = snap_nearest_y (cy, wall, vert_drag_idx);
                }
            }

            wall.move_vertex (vert_drag_idx, fx, fy);
            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        // ── Snapping ──────────────────────────────────────────────────────

        private double snap_nearest_x (double x, Wall excl_wall, int excl_idx)
        {
            double best = x, min_d = 1e18;
            foreach (unowned var shape in shapes) {
                var xs = shape.get_snap_xs ();
                for (int i = 0; i < xs.length; i++) {
                    if (shape == excl_wall && i == excl_idx) continue;
                    double d = Math.fabs (x - xs[i]);
                    if (d < min_d) { min_d = d; best = xs[i]; }
                }
            }
            return best;
        }

        private double snap_nearest_y (double y, Wall excl_wall, int excl_idx)
        {
            double best = y, min_d = 1e18;
            foreach (unowned var shape in shapes) {
                var ys = shape.get_snap_ys ();
                for (int i = 0; i < ys.length; i++) {
                    if (shape == excl_wall && i == excl_idx) continue;
                    double d = Math.fabs (y - ys[i]);
                    if (d < min_d) { min_d = d; best = ys[i]; }
                }
            }
            return best;
        }

        // ── Helpers de selección y modo ───────────────────────────────────

        /**
         * Aplica la selección sin cambiar el modo.
         * Siempre resetea vertex_handles_visible de la figura anterior.
         */
        private void do_select (Shape? target)
        {
            foreach (unowned var s in shapes) {
                s.set_selected (s == target);
                if (s != target) {
                    s.vertex_handles_visible = false;
                    if (s is Wall) ((Wall) s).selected_vertex = -1;
                }
            }
            sel_shape      = target;
            sel_vertex_idx = -1;
        }

        /** Entra en modo TRANSFORM (bbox + handles de escala/rotación). */
        private void enter_transform_mode ()
        {
            sel_mode       = 1;
            sel_vertex_idx = -1;
            if (sel_shape != null) {
                sel_shape.vertex_handles_visible = false;
                if (sel_shape is Wall) ((Wall) sel_shape).selected_vertex = -1;
            }
            rebuild_cache ();
            queue_draw ();
        }

        /** Entra en modo VÉRTICES (handles de vértice, sin bbox). */
        private void enter_vertex_mode ()
        {
            sel_mode = 2;
            if (sel_shape != null) sel_shape.vertex_handles_visible = true;
            rebuild_cache ();
            queue_draw ();
        }

        /** Primer shape que contiene el punto (cx, cy), o null. */
        private Shape? hit_shape (double cx, double cy)
        {
            foreach (unowned var shape in shapes) {
                if (shape.contains_point (cx, cy)) return shape;
            }
            return null;
        }

        private int hit_resize_handle (BBoxRect b, double cx, double cy)
        {
            double[] hx = { b.x, b.x + b.w, b.x + b.w, b.x         };
            double[] hy = { b.y, b.y,        b.y + b.h, b.y + b.h  };
            for (int i = 0; i < 4; i++) {
                if (dist2 (cx, cy, hx[i], hy[i]) <= TH_SIZE * TH_SIZE * 4) return i;
            }
            return -1;
        }

        private void start_resize (int corner, BBoxRect b, double cx, double cy)
        {
            resize_corner = corner;
            sel_interact  = 2;
            sel_press_x   = cx;
            sel_press_y   = cy;
            resize_orig_w = b.w;
            resize_orig_h = b.h;
            switch (corner) {
            case 0: resize_anchor_x = b.x + b.w; resize_anchor_y = b.y + b.h; break;
            case 1: resize_anchor_x = b.x;        resize_anchor_y = b.y + b.h; break;
            case 2: resize_anchor_x = b.x;        resize_anchor_y = b.y;        break;
            default: resize_anchor_x = b.x + b.w; resize_anchor_y = b.y;       break;
            }
            take_transform_snapshot ();
        }

        private void take_transform_snapshot ()
        {
            if (sel_shape is Wall) {
                ((Wall) sel_shape).get_full_snapshot (
                    out trans_snap_vx, out trans_snap_vy,
                    out trans_snap_bez_in, out trans_snap_bez_out,
                    out trans_snap_cox, out trans_snap_coy,
                    out trans_snap_cix, out trans_snap_ciy);
            }
        }

        private double dist2 (double ax, double ay, double bx, double by)
        {
            double dx = ax - bx, dy = ay - by;
            return dx * dx + dy * dy;
        }

        // ── Teclado ───────────────────────────────────────────────────────

        private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                shift_pressed = true;
            }

            // Suprimir vértice seleccionado en modo edición de vértices
            if (keyval == Gdk.Key.Delete &&
                sel_mode == 2 && sel_shape is Wall && sel_vertex_idx >= 0) {
                var del_wall = (Wall) sel_shape;
                if (del_wall.delete_vertex (sel_vertex_idx)) {
                    sel_vertex_idx              = -1;
                    del_wall.selected_vertex    = -1;
                    rebuild_cache ();
                    queue_draw ();
                    metrics_updated (del_wall.get_size_px (),
                                     del_wall.get_size_m (),
                                     del_wall.get_area_m2 ());
                }
                return true;
            }

            if (keyval == Gdk.Key.Escape) {
                if (wall_active != null) {
                    wall_active = null;
                    queue_draw ();
                    metrics_updated ("", "", "");
                    return true;
                }
                if (sel_shape != null) {
                    if (sel_mode == 2) {
                        // Volver a modo transform desde modo vértices
                        sel_interact = 0;
                        enter_transform_mode ();
                    } else {
                        // Deseleccionar
                        do_select (null);
                        sel_mode     = 0;
                        sel_interact = 0;
                        rebuild_cache ();
                        queue_draw ();
                        metrics_updated ("", "", "");
                    }
                    return true;
                }
            }

            // Flechas: mover el vértice seleccionado en modo edición
            if (sel_mode == 2 && sel_shape is Wall && sel_vertex_idx >= 0) {
                double step = (state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 10.0 : 1.0;
                var kwall   = (Wall) sel_shape;
                double vx   = kwall.get_vertex_x (sel_vertex_idx);
                double vy   = kwall.get_vertex_y (sel_vertex_idx);
                bool moved  = true;

                switch (keyval) {
                case Gdk.Key.Up:    kwall.move_vertex (sel_vertex_idx, vx,        vy - step); break;
                case Gdk.Key.Down:  kwall.move_vertex (sel_vertex_idx, vx,        vy + step); break;
                case Gdk.Key.Left:  kwall.move_vertex (sel_vertex_idx, vx - step, vy);        break;
                case Gdk.Key.Right: kwall.move_vertex (sel_vertex_idx, vx + step, vy);        break;
                default:            moved = false; break;
                }

                if (moved) {
                    rebuild_cache ();
                    queue_draw ();
                    metrics_updated (kwall.get_size_px (), kwall.get_size_m (), kwall.get_area_m2 ());
                    return true;
                }
            }

            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (keyval == '+' || keyval == '=') { zoom_in ();    return true; }
                if (keyval == '-')                  { zoom_out ();   return true; }
                if (keyval == '0')                  { zoom_reset (); return true; }
            }

            if (active != null)      active.on_key_pressed (keyval);
            if (wall_active != null) wall_active.on_key_pressed (keyval);
            return false;
        }

        private void on_key_released (uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                shift_pressed = false;
            }
            if (active != null)      active.on_key_released (keyval);
            if (wall_active != null) wall_active.on_key_released (keyval);
        }

        private bool on_scroll (double dx, double dy)
        {
            var ev = scroll_ctrl.get_current_event ();
            if (ev == null) return false;
            var mods = ev.get_modifier_state ();
            if ((mods & Gdk.ModifierType.CONTROL_MASK) == 0) return false;
            if (dy < 0) zoom_in ();
            else if (dy > 0) zoom_out ();
            return true;
        }

        // ── Fábrica de figuras (drag-based) ───────────────────────────────

        private Shape? create_shape ()
        {
            switch (active_tool) {
            case ToolType.COLUMN:    return new Rect ();
            case ToolType.BULB:      return new Circle ();
            case ToolType.OUTLET:    return new Circle ();
            case ToolType.DOOR:      return new Circle ();
            case ToolType.WINDOW:    return new Circle ();
            case ToolType.FAUCET:    return new Circle ();
            case ToolType.FURNITURE: return new Circle ();
            default:                 return null;
            }
        }

        // ── Helpers internos ──────────────────────────────────────────────

        private void update_size_request ()
        {
            set_size_request (
                (int)(WINDOW_WIDTH  * zoom_level),
                (int)(WINDOW_HEIGHT * zoom_level)
                );
        }

        // ── Renderizado ───────────────────────────────────────────────────

        private void draw_func (Gtk.DrawingArea area, Cairo.Context cr,
                                int width, int height)
        {
            cr.set_source_rgb (1, 1, 1);
            cr.paint ();

            cr.scale (zoom_level, zoom_level);

            cr.set_source_surface (cache_surface, 0, 0);
            cr.paint ();

            if (wall_active != null)                     wall_active.paint (cr);
            if (active != null && active.has_started ()) active.paint (cr);

            // Overlay de transformación sólo en modo TRANSFORM
            if (sel_shape != null && sel_mode == 1) draw_selection_overlay (cr);
        }

        private void draw_selection_overlay (Cairo.Context cr)
        {
            var b = sel_shape.get_bbox ();
            if (b.w < 1.0 && b.h < 1.0) return;

            cr.save ();
            cr.set_line_width (1.0);

            // Bbox punteado
            double[] dash = { 5.0, 3.0 };
            cr.set_dash (dash, 0.0);
            cr.set_source_rgba (0.15, 0.4, 0.9, 0.7);
            cr.rectangle (b.x, b.y, b.w, b.h);
            cr.stroke ();
            cr.set_dash (new double[0], 0.0);

            // 4 esquinas de redimensionado
            double[] hx = { b.x, b.x + b.w, b.x + b.w, b.x         };
            double[] hy = { b.y, b.y,        b.y + b.h, b.y + b.h  };
            for (int i = 0; i < 4; i++) {
                cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
                cr.rectangle (hx[i] - TH_SIZE, hy[i] - TH_SIZE, TH_SIZE * 2, TH_SIZE * 2);
                cr.fill ();
                cr.set_source_rgba (0.15, 0.4, 0.9, 1.0);
                cr.rectangle (hx[i] - TH_SIZE, hy[i] - TH_SIZE, TH_SIZE * 2, TH_SIZE * 2);
                cr.stroke ();
            }

            // Handle de rotación
            double rx = b.x + b.w / 2.0;
            double ry = b.y - ROT_DIST;
            cr.set_source_rgba (0.15, 0.4, 0.9, 0.5);
            cr.move_to (b.x + b.w / 2.0, b.y);
            cr.line_to (rx, ry);
            cr.stroke ();
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.arc (rx, ry, TH_SIZE + 1, 0, 2.0 * Math.PI);
            cr.fill ();
            cr.set_source_rgba (0.15, 0.4, 0.9, 1.0);
            cr.arc (rx, ry, TH_SIZE + 1, 0, 2.0 * Math.PI);
            cr.stroke ();

            cr.restore ();
        }

        // ── Cache ─────────────────────────────────────────────────────────

        private void rebuild_cache ()
        {
            clear_cache_to_white ();
            foreach (unowned var shape in shapes) {
                shape.paint (cache_cr);
            }
        }

        private void clear_cache_to_white ()
        {
            cache_cr.set_operator (Cairo.Operator.SOURCE);
            cache_cr.set_source_rgb (1, 1, 1);
            cache_cr.paint ();
            cache_cr.set_operator (Cairo.Operator.OVER);
        }
    }
}
