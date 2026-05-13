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

        private Shape[]  shapes      = {};
        private ToolType active_tool = ToolType.SELECT;

        // ── Muro en curso (clic-a-clic) ───────────────────────────────────
        private Wall? wall_being_drawn  = null;
        // True si el último n_press=1 añadió efectivamente un vértice al muro
        private bool  wall_vertex_was_added = false;

        // ── Selección ─────────────────────────────────────────────────────
        private Shape? selected_shape = null;

        /**
         * Modo de edición de la figura seleccionada:
         *   0 = ninguna selección
         *   1 = TRANSFORM (bbox + handles de esquina/rotación)
         *   2 = VÉRTICES  (handles de vértice, sin bbox)
         */
        private int selection_mode = 0;

        // Interacción activa:
        //   0=ninguna  1=mover  2=resize  3=rotar  4=vértice  5=handle Bézier
        private int    interaction_type  = 0;
        private double interaction_start_x   = 0.0;
        private double interaction_start_y   = 0.0;

        // Resize
        private int    resize_corner   = -1;
        private double resize_anchor_x = 0.0;
        private double resize_anchor_y = 0.0;
        private double resize_original_width   = 0.0;
        private double resize_original_height  = 0.0;

        // Rotación
        private double rotation_center_x         = 0.0;
        private double rotation_center_y         = 0.0;
        private double rotation_original_angle   = 0.0;

        // Snapshot unificado (vértices + datos Bézier) para resize/rotate
        private double[] snapshot_vertices_x        = {};
        private double[] snapshot_vertices_y        = {};
        private bool[]   snapshot_bezier_incoming   = {};
        private bool[]   snapshot_bezier_outgoing   = {};
        private double[] snapshot_control_outgoing_x = {};
        private double[] snapshot_control_outgoing_y = {};
        private double[] snapshot_control_incoming_x = {};
        private double[] snapshot_control_incoming_y = {};

        // Vértice arrastrado (durante drag)
        private int vertex_drag_index = -1;

        // Vértice seleccionado para control por teclado (-1 = ninguno)
        private int selected_vertex_index = -1;

        // Bézier: handle arrastrado
        private int  bezier_vertex_index = -1;
        private bool is_outgoing_bezier_handle = false;

        // Shift para snapping
        private bool is_shift_pressed = false;

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
                if (wall_being_drawn != null) queue_draw ();
                return GLib.Source.CONTINUE;
            });
        }

        // ── API pública ───────────────────────────────────────────────────

        public void set_tool (ToolType tool)
        {
            active_tool          = tool;
            wall_being_drawn     = null;
            wall_vertex_was_added = false;
            interaction_type     = 0;

            // Deseleccionar la figura activa al cambiar de herramienta
            if (selected_shape != null) {
                do_select (null);
                selection_mode = 0;
                rebuild_cache ();
            }

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
            double canvas_x = to_canvas (x);
            double canvas_y = to_canvas (y);

            if (active_tool == ToolType.WALL) {
                handle_wall_click (n_press, canvas_x, canvas_y);
                return;
            }

            if (active_tool == ToolType.SELECT) {
                on_select_press (n_press, canvas_x, canvas_y);
            }
        }

        private void on_select_press (int n_press, double canvas_x, double canvas_y)
        {
            if (n_press == 2) {
                handle_select_double_click (canvas_x, canvas_y);
            } else {
                handle_select_single_click (canvas_x, canvas_y);
            }
        }

        private void handle_select_double_click (double canvas_x, double canvas_y)
        {
            if (selection_mode == 2 && selected_shape is Wall) {
                if (try_toggle_bezier_on_vertex (canvas_x, canvas_y)) return;
                if (try_insert_vertex_on_segment (canvas_x, canvas_y)) return;
            }

            if (selected_shape != null &&
                (selected_shape.contains_point (canvas_x, canvas_y) ||
                 selected_shape.has_handle_at (canvas_x, canvas_y))) {
                interaction_type = 0;
                enter_vertex_mode ();
            } else {
                Shape? found_shape = hit_shape (canvas_x, canvas_y);
                if (found_shape != null && found_shape != selected_shape) {
                    do_select (found_shape);
                    enter_transform_mode ();
                }
            }
        }

        private void handle_select_single_click (double canvas_x, double canvas_y)
        {
            if (selection_mode == 2 && selected_shape != null) {
                if (selected_shape is Wall) {
                    if (try_start_bezier_drag (canvas_x, canvas_y)) return;
                    if (try_start_vertex_drag (canvas_x, canvas_y)) return;
                }
                if (selected_shape.contains_point (canvas_x, canvas_y)) return;
            }

            if (selection_mode == 1 && selected_shape != null) {
                if (try_start_rotation (canvas_x, canvas_y)) return;
                var bounding_box = selected_shape.get_bbox ();
                int handle_index = hit_resize_handle (bounding_box, canvas_x, canvas_y);
                if (handle_index >= 0) {
                    start_resize (handle_index, bounding_box, canvas_x, canvas_y);
                    return;
                }
            }

            Shape? found_shape = hit_shape (canvas_x, canvas_y);
            do_select (found_shape);
            if (found_shape != null) {
                enter_transform_mode ();
                interaction_type    = 1;
                interaction_start_x = canvas_x;
                interaction_start_y = canvas_y;
                metrics_updated (found_shape.get_size_px (), found_shape.get_size_m (),
                                 found_shape.get_area_m2 ());
            } else {
                selection_mode   = 0;
                interaction_type = 0;
                metrics_updated ("", "", "");
            }
        }

        // ── Helpers de on_select_press ────────────────────────────────────

        /** Activa/desactiva Bézier en el vértice bajo (canvas_x, canvas_y). Devuelve true si actuó. */
        private bool try_toggle_bezier_on_vertex (double canvas_x, double canvas_y)
        {
            var wall = (Wall) selected_shape;
            int vertex_index = wall.find_vertex (canvas_x, canvas_y);
            if (vertex_index < 0) return false;
            interaction_type = 0;
            wall.toggle_bezier (vertex_index);
            rebuild_cache ();
            queue_draw ();
            return true;
        }

        /** Inserta un vértice en el segmento bajo (canvas_x, canvas_y). Devuelve true si actuó. */
        private bool try_insert_vertex_on_segment (double canvas_x, double canvas_y)
        {
            var wall = (Wall) selected_shape;
            if (wall.has_handle_at (canvas_x, canvas_y)) return false;
            double proj_x, proj_y;
            int seg = wall.find_segment_at (canvas_x, canvas_y, 10.0, out proj_x, out proj_y);
            if (seg < 0) return false;
            int new_idx         = wall.insert_vertex (seg, proj_x, proj_y);
            vertex_drag_index   = new_idx;
            interaction_type    = 4;
            interaction_start_x = proj_x;
            interaction_start_y = proj_y;
            rebuild_cache ();
            queue_draw ();
            return true;
        }

        /** Inicia arrastre de un handle Bézier. Devuelve true si actuó. */
        private bool try_start_bezier_drag (double canvas_x, double canvas_y)
        {
            bool is_outgoing_handle;
            int bezier_index = ((Wall) selected_shape).find_bezier_handle (
                canvas_x, canvas_y, out is_outgoing_handle);
            if (bezier_index < 0) return false;
            bezier_vertex_index        = bezier_index;
            is_outgoing_bezier_handle  = is_outgoing_handle;
            interaction_type           = 5;
            interaction_start_x        = canvas_x;
            interaction_start_y        = canvas_y;
            take_transform_snapshot ();
            return true;
        }

        /** Selecciona un vértice e inicia su arrastre. Devuelve true si actuó. */
        private bool try_start_vertex_drag (double canvas_x, double canvas_y)
        {
            var wall = (Wall) selected_shape;
            int vertex_index = wall.find_vertex (canvas_x, canvas_y);
            if (vertex_index < 0) return false;
            selected_vertex_index      = vertex_index;
            wall.selected_vertex       = vertex_index;
            vertex_drag_index          = vertex_index;
            interaction_type           = 4;
            interaction_start_x        = canvas_x;
            interaction_start_y        = canvas_y;
            take_transform_snapshot ();
            rebuild_cache ();
            queue_draw ();
            return true;
        }

        /** Inicia rotación si el cursor está sobre el handle de rotación. Devuelve true si actuó. */
        private bool try_start_rotation (double canvas_x, double canvas_y)
        {
            var bounding_box = selected_shape.get_bbox ();
            double rotation_handle_x = bounding_box.x + bounding_box.w / 2.0;
            double rotation_handle_y = bounding_box.y - ROT_DIST;
            if (dist2 (canvas_x, canvas_y, rotation_handle_x, rotation_handle_y) >
                (TH_SIZE + 3) * (TH_SIZE + 3)) return false;
            interaction_type       = 3;
            interaction_start_x    = canvas_x;
            interaction_start_y    = canvas_y;
            rotation_center_x      = bounding_box.x + bounding_box.w / 2.0;
            rotation_center_y      = bounding_box.y + bounding_box.h / 2.0;
            rotation_original_angle = Math.atan2 (canvas_y - rotation_center_y,
                                                   canvas_x - rotation_center_x);
            take_transform_snapshot ();
            return true;
        }

        // ── on_released ───────────────────────────────────────────────────

        private void on_released (int n_press, double x, double y)
        {
            double canvas_x = to_canvas (x);
            double canvas_y = to_canvas (y);

            if (active_tool == ToolType.SELECT) {
                interaction_type    = 0;
                resize_corner       = -1;
                vertex_drag_index   = -1;
                bezier_vertex_index = -1;
                rebuild_cache ();
                queue_draw ();
                if (selected_shape != null) {
                    metrics_updated (
                        selected_shape.get_size_px (),
                        selected_shape.get_size_m (),
                        selected_shape.get_area_m2 ()
                        );
                }
                return;
            }

        }

        // ── on_motion ─────────────────────────────────────────────────────

        private void on_motion (double x, double y)
        {
            double canvas_x = to_canvas (x);
            double canvas_y = to_canvas (y);

            var ev = motion_ctrl.get_current_event ();
            if (ev != null) {
                var mods  = ev.get_modifier_state ();
                is_shift_pressed = (mods & Gdk.ModifierType.SHIFT_MASK) != 0;
            }

            if (wall_being_drawn != null) {
                wall_being_drawn.update_preview (canvas_x, canvas_y);

                // Calcular si la previsualización actual está bloqueada
                int vertex_count  = wall_being_drawn.vertex_count;
                double last_x = wall_being_drawn.get_vertex_x (vertex_count - 1);
                double last_y = wall_being_drawn.get_vertex_y (vertex_count - 1);

                bool has_collision = would_block_drawing (last_x, last_y, canvas_x, canvas_y) ||
                               wall_being_drawn.new_segment_crosses_self (
                                   last_x, last_y, canvas_x, canvas_y, vertex_count - 1);

                // Cerca del primer vértice: comprobar encierro y auto-cruce del cierre
                if (!has_collision && wall_being_drawn.near_first_vertex (canvas_x, canvas_y)) {
                    double first_x = wall_being_drawn.get_vertex_x (0);
                    double first_y = wall_being_drawn.get_vertex_y (0);
                    has_collision = would_enclose_existing (wall_being_drawn) ||
                              wall_being_drawn.new_segment_crosses_self (
                                  last_x, last_y, first_x, first_y, vertex_count - 1, true);
                }
                wall_being_drawn.preview_blocked = has_collision;

                queue_draw ();
                metrics_updated (
                    wall_being_drawn.get_size_px (),
                    wall_being_drawn.get_size_m (),
                    wall_being_drawn.get_area_m2 ()
                    );
                return;
            }

            if (active_tool == ToolType.SELECT && selected_shape != null) {
                switch (interaction_type) {
                case 1: do_move   (canvas_x, canvas_y); return;
                case 2: do_resize (canvas_x, canvas_y); return;
                case 3: do_rotate (canvas_x, canvas_y); return;
                case 4: do_vertex (canvas_x, canvas_y); return;
                case 5: do_bezier (canvas_x, canvas_y); return;
                }
                return;
            }

        }

        // ── Lógica WALL ───────────────────────────────────────────────────

        private void handle_wall_click (int n_press, double canvas_x, double canvas_y)
        {
            if (n_press == 2) {
                handle_wall_double_click (canvas_x, canvas_y);
            } else {
                handle_wall_single_click (canvas_x, canvas_y);
            }
        }

        private void handle_wall_double_click (double canvas_x, double canvas_y)
        {
            if (wall_being_drawn == null) return;

            if (wall_vertex_was_added) {
                wall_being_drawn.remove_last_vertex ();
                wall_vertex_was_added = false;
            }

            if (wall_being_drawn.near_first_vertex (canvas_x, canvas_y)) {
                if (closing_segment_is_valid ()) {
                    wall_being_drawn.close ();
                    commit_wall ();
                } else {
                    cancel_wall ();
                }
            } else if (wall_being_drawn.vertex_count >= 2) {
                if (try_close_wall_via_point (canvas_x, canvas_y)) {
                    commit_wall ();
                } else {
                    queue_draw (); // el usuario debe usar el punto verde o Escape
                }
            } else {
                cancel_wall ();
            }
        }

        private void handle_wall_single_click (double canvas_x, double canvas_y)
        {
            wall_vertex_was_added = false;

            if (wall_being_drawn == null) {
                if (!would_block_drawing (canvas_x, canvas_y, canvas_x, canvas_y)) {
                    wall_being_drawn = new Wall ();
                    wall_being_drawn.start_draw (canvas_x, canvas_y);
                }
            } else if (wall_being_drawn.near_first_vertex (canvas_x, canvas_y)) {
                if (closing_segment_is_valid ()) {
                    wall_being_drawn.close ();
                    commit_wall ();
                    return;
                }
            } else {
                int    vertex_count = wall_being_drawn.vertex_count;
                double last_x = wall_being_drawn.get_vertex_x (vertex_count - 1);
                double last_y = wall_being_drawn.get_vertex_y (vertex_count - 1);
                if (!would_block_drawing (last_x, last_y, canvas_x, canvas_y) &&
                    !wall_being_drawn.new_segment_crosses_self (
                        last_x, last_y, canvas_x, canvas_y, vertex_count - 1)) {
                    wall_being_drawn.add_vertex (canvas_x, canvas_y);
                    wall_vertex_was_added = true;
                }
            }
            queue_draw ();
        }

        /** True si el tramo V(n-1)→V0 es dibujable (sin colisión ni auto-cruce). */
        private bool closing_segment_is_valid ()
        {
            int    vertex_count = wall_being_drawn.vertex_count;
            double last_x = wall_being_drawn.get_vertex_x (vertex_count - 1);
            double last_y = wall_being_drawn.get_vertex_y (vertex_count - 1);
            double first_x = wall_being_drawn.get_vertex_x (0);
            double first_y = wall_being_drawn.get_vertex_y (0);
            return !would_block_drawing (last_x, last_y, first_x, first_y) &&
                   !would_enclose_existing (wall_being_drawn) &&
                   !wall_being_drawn.new_segment_crosses_self (
                       last_x, last_y, first_x, first_y, vertex_count - 1, true);
        }

        /**
         * Intenta cerrar el muro añadiendo (canvas_x, canvas_y) antes del V0.
         * Devuelve true si el cierre es válido (y el vértice ya está añadido).
         */
        private bool try_close_wall_via_point (double canvas_x, double canvas_y)
        {
            int    vertex_count = wall_being_drawn.vertex_count;
            double last_x  = wall_being_drawn.get_vertex_x (vertex_count - 1);
            double last_y  = wall_being_drawn.get_vertex_y (vertex_count - 1);
            double first_x = wall_being_drawn.get_vertex_x (0);
            double first_y = wall_being_drawn.get_vertex_y (0);

            if (would_block_drawing (last_x, last_y, canvas_x, canvas_y) ||
                would_block_drawing (canvas_x, canvas_y, first_x, first_y) ||
                wall_being_drawn.new_segment_crosses_self (
                    last_x, last_y, canvas_x, canvas_y, vertex_count - 1)) {
                return false;
            }

            wall_being_drawn.add_vertex (canvas_x, canvas_y);
            int new_vertex_count = wall_being_drawn.vertex_count;
            if (would_enclose_existing (wall_being_drawn) ||
                wall_being_drawn.new_segment_crosses_self (
                    wall_being_drawn.get_vertex_x (new_vertex_count - 1),
                    wall_being_drawn.get_vertex_y (new_vertex_count - 1),
                    first_x, first_y, new_vertex_count - 1, true)) {
                wall_being_drawn.remove_last_vertex ();
                return false;
            }

            wall_being_drawn.close ();
            return true;
        }

        /** Guarda el muro activo en el canvas y limpia el estado de dibujo. */
        private void commit_wall ()
        {
            shapes += wall_being_drawn;
            rebuild_cache ();
            wall_being_drawn = null;
            queue_draw ();
            metrics_updated ("", "", "");
        }

        /** Descarta el muro activo sin guardarlo. */
        private void cancel_wall ()
        {
            wall_being_drawn = null;
            queue_draw ();
            metrics_updated ("", "", "");
        }

        // ── Transformaciones SELECT ───────────────────────────────────────

        private void do_move (double canvas_x, double canvas_y)
        {
            double delta_x = canvas_x - interaction_start_x;
            double delta_y = canvas_y - interaction_start_y;

            // Intentar el movimiento completo
            selected_shape.translate (delta_x, delta_y);

            if (!check_collisions (selected_shape)) {
                // Sin colisión: aceptar
                interaction_start_x = canvas_x;
                interaction_start_y = canvas_y;
            } else {
                // Revertir movimiento combinado
                selected_shape.translate (-delta_x, -delta_y);

                // Deslizamiento en X
                if (Math.fabs (delta_x) > 0.01) {
                    selected_shape.translate (delta_x, 0.0);
                    if (!check_collisions (selected_shape)) {
                        interaction_start_x = canvas_x;   // X aceptado
                    } else {
                        selected_shape.translate (-delta_x, 0.0);
                    }
                }

                // Deslizamiento en Y (sobre la posición tras el intento X)
                if (Math.fabs (delta_y) > 0.01) {
                    selected_shape.translate (0.0, delta_y);
                    if (!check_collisions (selected_shape)) {
                        interaction_start_y = canvas_y;   // Y aceptado
                    } else {
                        selected_shape.translate (0.0, -delta_y);
                    }
                }
            }

            rebuild_cache ();
            queue_draw ();
            metrics_updated (selected_shape.get_size_px (), selected_shape.get_size_m (),
                             selected_shape.get_area_m2 ());
        }

        /** True si la figura moving_wall colisiona con alguna otra del canvas. */
        private bool check_collisions (Shape moving_wall)
        {
            if (!(moving_wall is Wall)) return false;
            var wall = (Wall) moving_wall;
            foreach (unowned var shape in shapes) {
                if (shape == moving_wall) continue;
                if (shape is Wall && wall.collides_with ((Wall) shape)) return true;
            }
            return false;
        }

        /**
         * True si el segmento (x1,y1)→(x2,y2) cruza o penetra alguna figura existente.
         * Con x1==x2, y1==y2 sólo comprueba si el punto está dentro de un polígono.
         */
        private bool would_block_drawing (double x1, double y1, double x2, double y2)
        {
            foreach (unowned var shape in shapes) {
                if (shape is Wall && ((Wall) shape).blocks_new_segment (x1, y1, x2, y2)) {
                    return true;
                }
            }
            return false;
        }

        /**
         * True si wall (tratado como polígono cerrado) encerraría algún vértice de
         * alguna figura existente. Se comprueba justo antes de cerrar un polígono.
         */
        private bool would_enclose_existing (Wall wall)
        {
            foreach (unowned var shape in shapes) {
                if (!(shape is Wall)) continue;
                var xs = ((Wall) shape).get_snap_xs ();
                var ys = ((Wall) shape).get_snap_ys ();
                if (wall.encloses_any_of (xs, ys)) return true;
            }
            return false;
        }

        private void do_resize (double canvas_x, double canvas_y)
        {
            if (!(selected_shape is Wall)) return;
            var wall = (Wall) selected_shape;

            double sx_des = resize_original_width > 1.0
                ? double.max (Math.fabs (canvas_x - resize_anchor_x) / resize_original_width, 0.01)
                : 1.0;
            double sy_des = resize_original_height > 1.0
                ? double.max (Math.fabs (canvas_y - resize_anchor_y) / resize_original_height, 0.01)
                : 1.0;

            restore_transform_snapshot (wall);
            wall.scale_vertices (sx_des, sy_des, resize_anchor_x, resize_anchor_y);

            if (check_collisions (wall)) {
                // Buscar el factor máximo de escala sin colisión
                double best_factor = 0.0, lower_bound = 0.0, upper_bound = 1.0;
                for (int i = 0; i < 8; i++) {
                    double midpoint_factor = (lower_bound + upper_bound) / 2.0;
                    restore_transform_snapshot (wall);
                    wall.scale_vertices (1.0 + midpoint_factor * (sx_des - 1.0),
                                         1.0 + midpoint_factor * (sy_des - 1.0),
                                         resize_anchor_x, resize_anchor_y);
                    if (check_collisions (wall)) upper_bound = midpoint_factor;
                    else { best_factor = midpoint_factor; lower_bound = midpoint_factor; }
                }
                restore_transform_snapshot (wall);
                if (best_factor > 0.0) {
                    wall.scale_vertices (1.0 + best_factor * (sx_des - 1.0),
                                         1.0 + best_factor * (sy_des - 1.0),
                                         resize_anchor_x, resize_anchor_y);
                }
            }

            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        private void do_rotate (double canvas_x, double canvas_y)
        {
            if (!(selected_shape is Wall)) return;
            var wall  = (Wall) selected_shape;
            double delta_des = Math.atan2 (canvas_y - rotation_center_y,
                                           canvas_x - rotation_center_x)
                               - rotation_original_angle;

            restore_transform_snapshot (wall);
            wall.rotate_vertices (delta_des, rotation_center_x, rotation_center_y);

            if (check_collisions (wall)) {
                // Buscar el ángulo máximo de rotación sin colisión
                double best_factor = 0.0, lower_bound = 0.0, upper_bound = 1.0;
                for (int i = 0; i < 8; i++) {
                    double midpoint_factor = (lower_bound + upper_bound) / 2.0;
                    restore_transform_snapshot (wall);
                    wall.rotate_vertices (midpoint_factor * delta_des,
                                          rotation_center_x, rotation_center_y);
                    if (check_collisions (wall)) upper_bound = midpoint_factor;
                    else { best_factor = midpoint_factor; lower_bound = midpoint_factor; }
                }
                restore_transform_snapshot (wall);
                if (best_factor > 0.0) {
                    wall.rotate_vertices (best_factor * delta_des,
                                          rotation_center_x, rotation_center_y);
                }
            }

            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        private void do_bezier (double canvas_x, double canvas_y)
        {
            if (!(selected_shape is Wall)) return;
            var wall = (Wall) selected_shape;

            // Restaurar al estado inicial del drag, aplicar y comprobar colisión
            restore_transform_snapshot (wall);
            wall.move_bezier_cp (bezier_vertex_index, is_outgoing_bezier_handle,
                                  canvas_x, canvas_y);
            if (check_collisions (wall)) restore_transform_snapshot (wall);

            rebuild_cache ();
            queue_draw ();
            metrics_updated (wall.get_size_px (), wall.get_size_m (), wall.get_area_m2 ());
        }

        private void do_vertex (double canvas_x, double canvas_y)
        {
            if (!(selected_shape is Wall)) return;
            var wall = (Wall) selected_shape;

            double final_x = canvas_x, final_y = canvas_y;
            if (is_shift_pressed) {
                double tdx = canvas_x - interaction_start_x;
                double tdy = canvas_y - interaction_start_y;
                if (Math.fabs (tdy) >= Math.fabs (tdx)) {
                    final_x = snap_nearest_x (canvas_x, wall, vertex_drag_index);
                } else {
                    final_y = snap_nearest_y (canvas_y, wall, vertex_drag_index);
                }
            }

            // Restaurar al estado inicial del drag, aplicar y comprobar colisión/auto-cruce
            restore_transform_snapshot (wall);
            wall.move_vertex (vertex_drag_index, final_x, final_y);
            if (check_collisions (wall) || wall.has_self_intersection ()) {
                restore_transform_snapshot (wall);
            }

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
            selected_shape        = target;
            selected_vertex_index = -1;
        }

        /** Entra en modo TRANSFORM (bbox + handles de escala/rotación). */
        private void enter_transform_mode ()
        {
            selection_mode        = 1;
            selected_vertex_index = -1;
            if (selected_shape != null) {
                selected_shape.vertex_handles_visible = false;
                if (selected_shape is Wall)
                    ((Wall) selected_shape).selected_vertex = -1;
            }
            rebuild_cache ();
            queue_draw ();
        }

        /** Entra en modo VÉRTICES (handles de vértice, sin bbox). */
        private void enter_vertex_mode ()
        {
            selection_mode = 2;
            if (selected_shape != null) selected_shape.vertex_handles_visible = true;
            rebuild_cache ();
            queue_draw ();
        }

        /** Primer shape que contiene el punto (canvas_x, canvas_y), o null. */
        private Shape? hit_shape (double canvas_x, double canvas_y)
        {
            foreach (unowned var shape in shapes) {
                if (shape.contains_point (canvas_x, canvas_y)) return shape;
            }
            return null;
        }

        private int hit_resize_handle (BBoxRect bounding_box, double canvas_x, double canvas_y)
        {
            double[] hx = { bounding_box.x, bounding_box.x + bounding_box.w,
                            bounding_box.x + bounding_box.w, bounding_box.x };
            double[] hy = { bounding_box.y, bounding_box.y,
                            bounding_box.y + bounding_box.h, bounding_box.y + bounding_box.h };
            for (int i = 0; i < 4; i++) {
                if (dist2 (canvas_x, canvas_y, hx[i], hy[i]) <= TH_SIZE * TH_SIZE * 4)
                    return i;
            }
            return -1;
        }

        private void start_resize (int corner, BBoxRect bounding_box,
                                    double canvas_x, double canvas_y)
        {
            resize_corner          = corner;
            interaction_type       = 2;
            interaction_start_x    = canvas_x;
            interaction_start_y    = canvas_y;
            resize_original_width  = bounding_box.w;
            resize_original_height = bounding_box.h;
            switch (corner) {
            case 0:
                resize_anchor_x = bounding_box.x + bounding_box.w;
                resize_anchor_y = bounding_box.y + bounding_box.h;
                break;
            case 1:
                resize_anchor_x = bounding_box.x;
                resize_anchor_y = bounding_box.y + bounding_box.h;
                break;
            case 2:
                resize_anchor_x = bounding_box.x;
                resize_anchor_y = bounding_box.y;
                break;
            default:
                resize_anchor_x = bounding_box.x + bounding_box.w;
                resize_anchor_y = bounding_box.y;
                break;
            }
            take_transform_snapshot ();
        }

        private void take_transform_snapshot ()
        {
            if (selected_shape is Wall) {
                ((Wall) selected_shape).get_full_snapshot (
                    out snapshot_vertices_x, out snapshot_vertices_y,
                    out snapshot_bezier_incoming, out snapshot_bezier_outgoing,
                    out snapshot_control_outgoing_x, out snapshot_control_outgoing_y,
                    out snapshot_control_incoming_x, out snapshot_control_incoming_y);
            }
        }

        private void restore_transform_snapshot (Wall wall)
        {
            wall.restore_full_snapshot (
                snapshot_vertices_x, snapshot_vertices_y,
                snapshot_bezier_incoming, snapshot_bezier_outgoing,
                snapshot_control_outgoing_x, snapshot_control_outgoing_y,
                snapshot_control_incoming_x, snapshot_control_incoming_y);
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
                is_shift_pressed = true;
            }

            // Suprimir figura completa en modo transform
            if (keyval == Gdk.Key.Delete && selection_mode == 1 && selected_shape != null) {
                Shape[] remaining = {};
                foreach (unowned var s in shapes) {
                    if (s != selected_shape) remaining += s;
                }
                shapes           = remaining;
                selected_shape   = null;
                selection_mode   = 0;
                interaction_type = 0;
                rebuild_cache ();
                queue_draw ();
                metrics_updated ("", "", "");
                return true;
            }

            // Suprimir vértice seleccionado en modo edición de vértices
            if (keyval == Gdk.Key.Delete &&
                selection_mode == 2 && selected_shape is Wall &&
                selected_vertex_index >= 0) {
                var del_wall = (Wall) selected_shape;
                if (del_wall.delete_vertex (selected_vertex_index)) {
                    selected_vertex_index       = -1;
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
                if (wall_being_drawn != null) {
                    wall_being_drawn = null;
                    queue_draw ();
                    metrics_updated ("", "", "");
                    return true;
                }
                if (selected_shape != null) {
                    if (selection_mode == 2) {
                        // Volver a modo transform desde modo vértices
                        interaction_type = 0;
                        enter_transform_mode ();
                    } else {
                        // Deseleccionar
                        do_select (null);
                        selection_mode   = 0;
                        interaction_type = 0;
                        rebuild_cache ();
                        queue_draw ();
                        metrics_updated ("", "", "");
                    }
                    return true;
                }
            }

            // Flechas: mover el vértice seleccionado en modo edición
            if (selection_mode == 2 && selected_shape is Wall && selected_vertex_index >= 0) {
                double movement_step = (state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 10.0 : 1.0;
                var keyboard_wall    = (Wall) selected_shape;
                double old_x = keyboard_wall.get_vertex_x (selected_vertex_index);
                double old_y = keyboard_wall.get_vertex_y (selected_vertex_index);
                bool moved   = true;

                switch (keyval) {
                case Gdk.Key.Up:
                    keyboard_wall.move_vertex (selected_vertex_index, old_x, old_y - movement_step);
                    break;
                case Gdk.Key.Down:
                    keyboard_wall.move_vertex (selected_vertex_index, old_x, old_y + movement_step);
                    break;
                case Gdk.Key.Left:
                    keyboard_wall.move_vertex (selected_vertex_index, old_x - movement_step, old_y);
                    break;
                case Gdk.Key.Right:
                    keyboard_wall.move_vertex (selected_vertex_index, old_x + movement_step, old_y);
                    break;
                default:
                    moved = false;
                    break;
                }

                if (moved) {
                    // Revertir si la nueva posición genera colisión o auto-cruce
                    if (check_collisions (keyboard_wall) ||
                        keyboard_wall.has_self_intersection ()) {
                        keyboard_wall.move_vertex (selected_vertex_index, old_x, old_y);
                        moved = false;
                    }
                }

                if (moved) {
                    rebuild_cache ();
                    queue_draw ();
                    metrics_updated (keyboard_wall.get_size_px (),
                                     keyboard_wall.get_size_m (),
                                     keyboard_wall.get_area_m2 ());
                }
                return true;
            }

            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (keyval == '+' || keyval == '=') { zoom_in ();    return true; }
                if (keyval == '-')                  { zoom_out ();   return true; }
                if (keyval == '0')                  { zoom_reset (); return true; }
            }

            if (wall_being_drawn != null) wall_being_drawn.on_key_pressed (keyval);
            return false;
        }

        private void on_key_released (uint keyval, uint keycode, Gdk.ModifierType state)
        {
            if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                is_shift_pressed = false;
            }
            if (wall_being_drawn != null) wall_being_drawn.on_key_released (keyval);
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

            if (wall_being_drawn != null)                wall_being_drawn.paint (cr);

            // Overlay de transformación sólo en modo TRANSFORM
            if (selected_shape != null && selection_mode == 1) draw_selection_overlay (cr);
        }

        private void draw_selection_overlay (Cairo.Context cr)
        {
            var bounding_box = selected_shape.get_bbox ();
            if (bounding_box.w < 1.0 && bounding_box.h < 1.0) return;

            cr.save ();
            cr.set_line_width (1.0);

            // Bbox punteado
            double[] dash = { 5.0, 3.0 };
            cr.set_dash (dash, 0.0);
            cr.set_source_rgba (0.15, 0.4, 0.9, 0.7);
            cr.rectangle (bounding_box.x, bounding_box.y, bounding_box.w, bounding_box.h);
            cr.stroke ();
            cr.set_dash (new double[0], 0.0);

            // 4 esquinas de redimensionado
            double[] hx = { bounding_box.x, bounding_box.x + bounding_box.w,
                            bounding_box.x + bounding_box.w, bounding_box.x };
            double[] hy = { bounding_box.y, bounding_box.y,
                            bounding_box.y + bounding_box.h, bounding_box.y + bounding_box.h };
            for (int i = 0; i < 4; i++) {
                cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
                cr.rectangle (hx[i] - TH_SIZE, hy[i] - TH_SIZE, TH_SIZE * 2, TH_SIZE * 2);
                cr.fill ();
                cr.set_source_rgba (0.15, 0.4, 0.9, 1.0);
                cr.rectangle (hx[i] - TH_SIZE, hy[i] - TH_SIZE, TH_SIZE * 2, TH_SIZE * 2);
                cr.stroke ();
            }

            // Handle de rotación
            double rotation_handle_x = bounding_box.x + bounding_box.w / 2.0;
            double rotation_handle_y = bounding_box.y - ROT_DIST;
            cr.set_source_rgba (0.15, 0.4, 0.9, 0.5);
            cr.move_to (bounding_box.x + bounding_box.w / 2.0, bounding_box.y);
            cr.line_to (rotation_handle_x, rotation_handle_y);
            cr.stroke ();
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.arc (rotation_handle_x, rotation_handle_y, TH_SIZE + 1, 0, 2.0 * Math.PI);
            cr.fill ();
            cr.set_source_rgba (0.15, 0.4, 0.9, 1.0);
            cr.arc (rotation_handle_x, rotation_handle_y, TH_SIZE + 1, 0, 2.0 * Math.PI);
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
