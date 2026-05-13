namespace Planly
{
    /**
     * Muro: polilínea de segmentos conectados, opcionalmente cerrada en
     * polígono.
     *
     * ── Dibujo (gestionado desde Scene, modelo clic-a-clic) ───────────────
     *   start_draw()         → coloca el primer vértice
     *   update_preview()     → cursor de previsualización (antes del clic)
     *   add_vertex()         → confirma el siguiente vértice
     *   remove_last_vertex() → deshace el último (para gestionar doble clic)
     *   close()              → cierra el polígono
     *   finish()             → termina la polilínea abierta
     *
     * ── Transformaciones (gestionadas desde Scene, modo SELECT) ──────────
     *   translate()          → desplaza todos los vértices
     *   scale_vertices()     → escala desde un punto ancla
     *   rotate_vertices()    → rota alrededor de un centro
     *   get_bbox()           → caja delimitadora AABB
     *   get_vertex_snapshot()→ copia de los vértices actuales
     *   restore_snapshot()   → restaura vértices desde una copia
     *
     * ── Edición de vértices (gestionada desde Scene) ─────────────────────
     *   find_vertex()        → índice del vértice bajo el cursor (-1 si ninguno)
     *   move_vertex()        → desplaza un vértice concreto
     *   has_handle_at()      → hay un vértice bajo el cursor
     */
    public class Wall : Shape
    {
        private const double SNAP_RADIUS   = 15.0;
        private const double HANDLE_RADIUS =  5.0;
        private const double WALL_LINE_W   =  3.0;
        private const double MIN_SEG_LEN   =  4.0;

        // Vértices en coordenadas lógicas del plano
        private double[] _vx = {};
        private double[] _vy = {};

        // Extremo de previsualización (último vértice → cursor)
        private double _cx = 0.0;
        private double _cy = 0.0;

        public bool is_drawing { get; private set; default = true; }
        public bool is_closed  { get; private set; default = false; }

        // Vértice seleccionado con teclado en modo edición (-1 = ninguno)
        public int selected_vertex = -1;

        // Métricas cacheadas
        private double _len_px  = 0.0;
        private double _len_m   = 0.0;
        private double _area_m2 = 0.0;

        // ── Construcción ──────────────────────────────────────────────────

        public Wall () { Object (); }

        // ── API de dibujo ─────────────────────────────────────────────────

        public void start_draw (double x, double y)
        {
            _vx          = { x };
            _vy          = { y };
            _cx          = x;
            _cy          = y;
            _has_started = true;
            is_drawing   = true;
        }

        public void update_preview (double x, double y)
        {
            if (draw_mode == DrawMode.FLATTEN && _vx.length > 0) {
                int i = _vx.length - 1;
                flatten_point (x, y, _vx[i], _vy[i], out _cx, out _cy);
            } else {
                _cx = x;
                _cy = y;
            }
        }

        public void add_vertex (double x, double y)
        {
            update_preview (x, y);
            int    last = _vx.length - 1;
            double dx   = _cx - _vx[last];
            double dy   = _cy - _vy[last];
            if (Math.sqrt (dx * dx + dy * dy) < MIN_SEG_LEN) return;
            _vx += _cx;
            _vy += _cy;
            update_metrics ();
        }

        public void remove_last_vertex ()
        {
            int n = _vx.length;
            if (n <= 1) return;
            _vx = _vx[0 : n - 1];
            _vy = _vy[0 : n - 1];
            update_metrics ();
        }

        public void close ()
        {
            is_closed  = true;
            is_drawing = false;
            update_metrics ();
        }

        public void finish ()
        {
            is_drawing = false;
            update_metrics ();
        }

        public bool near_first_vertex (double x, double y)
        {
            if (_vx.length < 3) return false;
            double dx = x - _vx[0];
            double dy = y - _vy[0];
            return (dx * dx + dy * dy) <= (SNAP_RADIUS * SNAP_RADIUS);
        }

        public int vertex_count { get { return _vx.length; } }

        // ── API de transformación ─────────────────────────────────────────

        /** Desplaza todos los vértices (y el cursor de previsualización) por (dx, dy). */
        public override void translate (double dx, double dy)
        {
            for (int i = 0; i < _vx.length; i++) {
                _vx[i] += dx;
                _vy[i] += dy;
            }
            _cx += dx;
            _cy += dy;
            update_metrics ();
        }

        /**
         * Escala los vértices usando (ox, oy) como punto ancla.
         * Se usa para redimensionar arrastrando una esquina del bbox.
         */
        public void scale_vertices (double sx, double sy, double ox, double oy)
        {
            for (int i = 0; i < _vx.length; i++) {
                _vx[i] = ox + (_vx[i] - ox) * sx;
                _vy[i] = oy + (_vy[i] - oy) * sy;
            }
            update_metrics ();
        }

        /**
         * Rota los vértices un ángulo (en radianes) alrededor de (cx, cy).
         */
        public void rotate_vertices (double angle, double cx, double cy)
        {
            double ca = Math.cos (angle);
            double sa = Math.sin (angle);
            for (int i = 0; i < _vx.length; i++) {
                double dx = _vx[i] - cx;
                double dy = _vy[i] - cy;
                _vx[i]   = cx + dx * ca - dy * sa;
                _vy[i]   = cy + dx * sa + dy * ca;
            }
            update_metrics ();
        }

        /** Devuelve copias de los arrays de vértices (para snapshot de transforms). */
        public void get_vertex_snapshot (out double[] vx, out double[] vy)
        {
            vx = _vx[0 : _vx.length];
            vy = _vy[0 : _vy.length];
        }

        /** Restaura los vértices desde una copia previa y recalcula métricas. */
        public void restore_snapshot (double[] vx, double[] vy)
        {
            _vx = vx[0 : vx.length];
            _vy = vy[0 : vy.length];
            update_metrics ();
        }

        // ── API de edición de vértices ────────────────────────────────────

        /**
         * Busca el segmento más cercano al punto (x, y) dentro de la tolerancia tol.
         * Si lo encuentra devuelve su índice y la proyección del punto sobre él.
         * Retorna -1 si ningún segmento está a esa distancia.
         */
        public int find_segment_at (double x, double y, double tol,
                                    out double proj_x, out double proj_y)
        {
            proj_x = x;
            proj_y = y;
            int n    = _vx.length;
            int segs = is_closed ? n : n - 1;

            for (int i = 0; i < segs; i++) {
                double x1, y1, x2, y2;
                if (i < n - 1) {
                    x1 = _vx[i];     y1 = _vy[i];
                    x2 = _vx[i + 1]; y2 = _vy[i + 1];
                } else {
                    x1 = _vx[n - 1]; y1 = _vy[n - 1];
                    x2 = _vx[0];     y2 = _vy[0];
                }
                double dx   = x2 - x1;
                double dy   = y2 - y1;
                double len2 = dx * dx + dy * dy;
                if (len2 < 1.0) continue;

                double t  = ((x - x1) * dx + (y - y1) * dy) / len2;
                t         = t.clamp (0.0, 1.0);
                double ex = x1 + t * dx;
                double ey = y1 + t * dy;
                double d  = Math.sqrt ((x - ex) * (x - ex) + (y - ey) * (y - ey));
                if (d <= tol) {
                    proj_x = ex;
                    proj_y = ey;
                    return i;
                }
            }
            return -1;
        }

        /**
         * Inserta un nuevo vértice en (x, y) tras el segmento seg_idx.
         * Devuelve el índice del vértice insertado.
         */
        public int insert_vertex (int seg_idx, double x, double y)
        {
            int insert_at = seg_idx + 1;
            double[] new_vx = {};
            double[] new_vy = {};

            for (int i = 0; i < insert_at; i++) {
                new_vx += _vx[i];
                new_vy += _vy[i];
            }
            new_vx += x;
            new_vy += y;
            for (int i = insert_at; i < _vx.length; i++) {
                new_vx += _vx[i];
                new_vy += _vy[i];
            }

            _vx = new_vx;
            _vy = new_vy;
            update_metrics ();
            return insert_at;
        }

        /** Índice del vértice más cercano al punto (x, y), o -1 si ninguno. */
        public int find_vertex (double x, double y)
        {
            double tol2 = HANDLE_RADIUS * HANDLE_RADIUS * 4.0;
            for (int i = 0; i < _vx.length; i++) {
                double dx = x - _vx[i];
                double dy = y - _vy[i];
                if (dx * dx + dy * dy <= tol2) return i;
            }
            return -1;
        }

        /** Coordenada X del vértice idx. */
        public double get_vertex_x (int idx)
        {
            return (idx >= 0 && idx < _vx.length) ? _vx[idx] : 0.0;
        }

        /** Coordenada Y del vértice idx. */
        public double get_vertex_y (int idx)
        {
            return (idx >= 0 && idx < _vy.length) ? _vy[idx] : 0.0;
        }

        /** Mueve el vértice de índice idx a (x, y) y recalcula métricas. */
        public void move_vertex (int idx, double x, double y)
        {
            if (idx < 0 || idx >= _vx.length) return;
            _vx[idx] = x;
            _vy[idx] = y;
            update_metrics ();
        }

        // ── Shape: detección de handles ───────────────────────────────────

        public override bool has_handle_at (double x, double y)
        {
            return find_vertex (x, y) >= 0;
        }

        // ── Shape: snap ───────────────────────────────────────────────────

        public override double[] get_snap_xs () { return _vx; }
        public override double[] get_snap_ys () { return _vy; }

        // ── Shape: bounding box ───────────────────────────────────────────

        public override BBoxRect get_bbox ()
        {
            int n = _vx.length;
            if (n == 0) return { 0.0, 0.0, 0.0, 0.0 };
            double min_x = _vx[0], max_x = _vx[0];
            double min_y = _vy[0], max_y = _vy[0];
            for (int i = 1; i < n; i++) {
                if (_vx[i] < min_x) min_x = _vx[i];
                if (_vx[i] > max_x) max_x = _vx[i];
                if (_vy[i] < min_y) min_y = _vy[i];
                if (_vy[i] > max_y) max_y = _vy[i];
            }
            return { min_x, min_y, max_x - min_x, max_y - min_y };
        }

        // ── Cálculos internos ─────────────────────────────────────────────

        private void flatten_point (double mx, double my,
                                    double ox, double oy,
                                    out double rx, out double ry)
        {
            double dx  = mx - ox;
            double dy  = my - oy;
            double len = Math.sqrt (dx * dx + dy * dy);
            if (len < 1.0) { rx = ox; ry = oy; return; }

            double deg = Math.atan2 (dy, dx) * 180.0 / Math.PI;
            if (deg < 0) deg += 360.0;

            double snap;
            if      (deg >= 23  && deg < 68)  snap = 45.0;
            else if (deg >= 68  && deg < 113) snap = 90.0;
            else if (deg >= 113 && deg < 158) snap = 135.0;
            else if (deg >= 158 && deg < 203) snap = 180.0;
            else if (deg >= 203 && deg < 248) snap = 225.0;
            else if (deg >= 248 && deg < 293) snap = 270.0;
            else if (deg >= 293 && deg < 338) snap = 315.0;
            else                              snap = 0.0;

            double rad = snap * Math.PI / 180.0;
            rx = ox + len * Math.cos (rad);
            ry = oy + len * Math.sin (rad);
        }

        private void update_metrics ()
        {
            int n = _vx.length;
            _len_px = 0.0;

            for (int i = 0; i < n - 1; i++) {
                double dx = _vx[i + 1] - _vx[i];
                double dy = _vy[i + 1] - _vy[i];
                _len_px += Math.sqrt (dx * dx + dy * dy);
            }
            if (is_closed && n >= 2) {
                double dx = _vx[0] - _vx[n - 1];
                double dy = _vy[0] - _vy[n - 1];
                _len_px += Math.sqrt (dx * dx + dy * dy);
            }
            _len_m = Utils.convert_to_metters (_len_px);

            if (is_closed && n >= 3) {
                double area = 0.0;
                for (int i = 0; i < n; i++) {
                    int j = (i + 1) % n;
                    area += _vx[i] * _vy[j] - _vx[j] * _vy[i];
                }
                double scale = (double) MEASURE_IN_PIXELS;
                _area_m2 = Math.fabs (area) / (2.0 * scale * scale);
            } else {
                _area_m2 = 0.0;
            }
        }

        // ── Drawable: hit-testing ─────────────────────────────────────────

        public override bool contains_point (double x, double y)
        {
            double tol = 8.0;
            int    n   = _vx.length;

            // Proximidad a cualquier segmento (borde)
            for (int i = 0; i < n - 1; i++) {
                if (near_segment (x, y, _vx[i], _vy[i], _vx[i + 1], _vy[i + 1], tol)) {
                    return true;
                }
            }
            if (is_closed && n >= 2) {
                if (near_segment (x, y, _vx[n - 1], _vy[n - 1], _vx[0], _vy[0], tol)) {
                    return true;
                }
                // Interior del polígono cerrado (ray casting)
                if (point_in_polygon (x, y)) {
                    return true;
                }
            }
            return false;
        }

        /** Ray-casting: devuelve true si (x, y) está dentro del polígono. */
        private bool point_in_polygon (double x, double y)
        {
            int  n      = _vx.length;
            bool inside = false;
            int  j      = n - 1;
            for (int i = 0; i < n; i++) {
                double xi = _vx[i], yi = _vy[i];
                double xj = _vx[j], yj = _vy[j];
                if (((yi > y) != (yj > y)) &&
                    (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
                    inside = !inside;
                }
                j = i;
            }
            return inside;
        }

        private bool near_segment (double px, double py,
                                   double x1, double y1,
                                   double x2, double y2,
                                   double tol)
        {
            double dx   = x2 - x1;
            double dy   = y2 - y1;
            double len2 = dx * dx + dy * dy;
            if (len2 < 1.0) {
                return Math.sqrt ((px - x1) * (px - x1) + (py - y1) * (py - y1)) <= tol;
            }
            double t  = ((px - x1) * dx + (py - y1) * dy) / len2;
            t         = t.clamp (0.0, 1.0);
            double ex = x1 + t * dx;
            double ey = y1 + t * dy;
            return Math.sqrt ((px - ex) * (px - ex) + (py - ey) * (py - ey)) <= tol;
        }

        // ── Drawable: eventos ratón (no-op: la lógica está en Scene) ──────

        public override void on_mouse_pressed  (double x, double y) {}
        public override void on_mouse_dragged  (double x, double y) {}
        public override void on_mouse_released (double x, double y) {}

        // ── Drawable: validación ──────────────────────────────────────────

        public override bool is_valid ()
        {
            return _vx.length >= 2;
        }

        // ── Drawable: métricas ────────────────────────────────────────────

        public override MetricLine[] get_metrics ()
        {
            MetricLine[] m = { metric_px_m (_("Longitud total"), _len_px) };
            if (is_closed && _area_m2 > 0) {
                MetricLine a = { _("Área"), "", "%.3f m²".printf (_area_m2) };
                m += a;
            }
            return m;
        }

        public override string get_size_px ()
        {
            return "%.1f px".printf (_len_px);
        }

        public override string get_size_m ()
        {
            return "%.3f m".printf (_len_m);
        }

        public override string get_area_m2 ()
        {
            if (is_closed && _area_m2 > 0) {
                return "%.3f m²".printf (_area_m2);
            }
            return "";
        }

        // ── Drawable: renderizado ─────────────────────────────────────────

        public override void paint (Cairo.Context cr)
        {
            int n = _vx.length;
            if (n == 0) return;

            cr.save ();
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);

            // Relleno semi-transparente si está cerrado
            if (is_closed && n >= 3) {
                cr.move_to (_vx[0], _vy[0]);
                for (int i = 1; i < n; i++) cr.line_to (_vx[i], _vy[i]);
                cr.close_path ();
                cr.set_source_rgba (fill_r, fill_g, fill_b, fill_a);
                cr.fill ();
            }

            // Trazo de segmentos confirmados
            cr.set_line_width (WALL_LINE_W);
            if (_is_selected) {
                cr.set_source_rgba (0.8, 0.1, 0.1, 1.0);
            } else {
                cr.set_source_rgba (stroke_r, stroke_g, stroke_b, stroke_a);
            }
            if (n >= 2) {
                cr.move_to (_vx[0], _vy[0]);
                for (int i = 1; i < n; i++) cr.line_to (_vx[i], _vy[i]);
                if (is_closed) cr.close_path ();
                cr.stroke ();
            }

            // Segmento de previsualización (punteado)
            if (is_drawing) {
                cr.save ();
                double[] dash = { 6.0, 4.0 };
                cr.set_dash (dash, 0.0);
                cr.set_source_rgba (stroke_r, stroke_g, stroke_b, stroke_a * 0.6);
                cr.move_to (_vx[n - 1], _vy[n - 1]);
                cr.line_to (_cx, _cy);
                cr.stroke ();
                cr.restore ();
            }

            // Handles de vértices (sólo en modo edición de vértices o al dibujar)
            if (is_drawing || (_is_selected && vertex_handles_visible)) {
                cr.set_line_width (1.5);
                if (_is_selected) {
                    cr.set_source_rgba (0.1, 0.3, 0.9, 1.0);
                } else {
                    cr.set_source_rgba (stroke_r, stroke_g, stroke_b, 1.0);
                }
                for (int i = 0; i < n; i++) {
                    if (i == selected_vertex) {
                        // Vértice seleccionado con teclado: círculo relleno azul
                        cr.set_source_rgba (0.1, 0.3, 0.9, 1.0);
                        cr.arc (_vx[i], _vy[i], HANDLE_RADIUS + 1.5, 0, 2.0 * Math.PI);
                        cr.fill ();
                    } else {
                        paint_handle (cr, _vx[i], _vy[i]);
                    }
                }

                // Indicador verde: cerca del primer vértice → cierre de polígono
                if (is_drawing && n >= 3 && near_first_vertex (_cx, _cy)) {
                    cr.set_source_rgba (0.2, 0.78, 0.2, 0.9);
                    cr.arc (_vx[0], _vy[0], HANDLE_RADIUS * 2.0, 0, 2.0 * Math.PI);
                    cr.fill ();
                }
            }

            // Etiquetas de longitud y área
            paint_segment_labels (cr);
            if (is_closed && _area_m2 > 0.0) {
                double cx = 0.0, cy = 0.0;
                for (int i = 0; i < n; i++) { cx += _vx[i]; cy += _vy[i]; }
                paint_label (cr, "%.2f m²".printf (_area_m2), cx / n, cy / n);
            }

            cr.restore ();
        }

        private void paint_segment_labels (Cairo.Context cr)
        {
            int n    = _vx.length;
            int segs = is_closed ? n : n - 1;

            for (int i = 0; i < segs; i++) {
                double x1, y1, x2, y2;
                if (i < n - 1) {
                    x1 = _vx[i]; y1 = _vy[i];
                    x2 = _vx[i + 1]; y2 = _vy[i + 1];
                } else {
                    x1 = _vx[n - 1]; y1 = _vy[n - 1];
                    x2 = _vx[0];     y2 = _vy[0];
                }
                double dx  = x2 - x1;
                double dy  = y2 - y1;
                double len = Math.sqrt (dx * dx + dy * dy);
                if (len < 30.0) continue;

                double mx   = (x1 + x2) / 2.0;
                double my   = (y1 + y2) / 2.0;
                double perp = Math.atan2 (dy, dx) - Math.PI / 2.0;
                paint_label (cr, format_m (Utils.convert_to_metters (len)),
                             mx + Math.cos (perp) * 14.0,
                             my + Math.sin (perp) * 14.0);
            }

            if (is_drawing && n >= 1) {
                double x1  = _vx[n - 1];
                double y1  = _vy[n - 1];
                double dx  = _cx - x1;
                double dy  = _cy - y1;
                double len = Math.sqrt (dx * dx + dy * dy);
                if (len >= 30.0) {
                    double mx   = (x1 + _cx) / 2.0;
                    double my   = (y1 + _cy) / 2.0;
                    double perp = Math.atan2 (dy, dx) - Math.PI / 2.0;
                    paint_label (cr, format_m (Utils.convert_to_metters (len)),
                                 mx + Math.cos (perp) * 14.0,
                                 my + Math.sin (perp) * 14.0);
                }
            }
        }
    }
}
