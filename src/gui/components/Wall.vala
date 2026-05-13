namespace Planly
{
    /**
     * Muro: polilínea/polígono con soporte para curvas de Bézier cúbicas.
     *
     * ── Dibujo ────────────────────────────────────────────────────────────
     *   start_draw / update_preview / add_vertex / remove_last_vertex
     *   close / finish / near_first_vertex
     *
     * ── Transformaciones ──────────────────────────────────────────────────
     *   translate / scale_vertices / rotate_vertices
     *   get_full_snapshot / restore_full_snapshot
     *
     * ── Edición de vértices ───────────────────────────────────────────────
     *   find_vertex / move_vertex / insert_vertex / find_segment_at
     *   get_vertex_x / get_vertex_y
     *
     * ── Bézier ────────────────────────────────────────────────────────────
     *   toggle_bezier     — activa/desactiva handles en un vértice
     *   find_bezier_handle— hit-test sobre los puntos de control
     *   move_bezier_cp    — mueve un punto de control (simétrico por defecto)
     */
    public class Wall : Shape
    {
        private const double SNAP_RADIUS   = 15.0;
        private const double HANDLE_RADIUS =  5.0;
        private const double BEZ_HANDLE_R  =  4.5;
        private const double WALL_LINE_W   =  3.0;
        private const double MIN_SEG_LEN   =  4.0;

        // ── Geometría ─────────────────────────────────────────────────────
        private double[] _vx = {};
        private double[] _vy = {};

        // ── Bézier (un juego de CPs por vértice) ──────────────────────────
        // _bez[i]  = true  → el vértice i tiene handles activos
        // _cp_ox/y = punto de control "saliente" (hacia el segmento i→i+1)
        // _cp_ix/y = punto de control "entrante" (desde el segmento i-1→i)
        private bool[]   _bez   = {};
        private double[] _cp_ox = {};
        private double[] _cp_oy = {};
        private double[] _cp_ix = {};
        private double[] _cp_iy = {};

        // ── Previsualización ──────────────────────────────────────────────
        private double _cx = 0.0;
        private double _cy = 0.0;

        public bool is_drawing { get; private set; default = true; }
        public bool is_closed  { get; private set; default = false; }

        // Vértice resaltado con teclado (-1 = ninguno)
        public int selected_vertex = -1;

        // ── Métricas ──────────────────────────────────────────────────────
        private double _len_px  = 0.0;
        private double _len_m   = 0.0;
        private double _area_m2 = 0.0;

        // ── Construcción ──────────────────────────────────────────────────

        public Wall () { Object (); }

        // ── API de dibujo ─────────────────────────────────────────────────

        public void start_draw (double x, double y)
        {
            _vx  = { x }; _vy  = { y };
            _bez = { false };
            _cp_ox = { 0.0 }; _cp_oy = { 0.0 };
            _cp_ix = { 0.0 }; _cp_iy = { 0.0 };
            _cx = x; _cy = y;
            _has_started = true;
            is_drawing   = true;
        }

        public void update_preview (double x, double y)
        {
            if (draw_mode == DrawMode.FLATTEN && _vx.length > 0) {
                int i = _vx.length - 1;
                flatten_point (x, y, _vx[i], _vy[i], out _cx, out _cy);
            } else {
                _cx = x; _cy = y;
            }
        }

        public void add_vertex (double x, double y)
        {
            update_preview (x, y);
            int    last = _vx.length - 1;
            double dx   = _cx - _vx[last];
            double dy   = _cy - _vy[last];
            if (Math.sqrt (dx * dx + dy * dy) < MIN_SEG_LEN) return;
            _vx  += _cx; _vy  += _cy;
            _bez += false;
            _cp_ox += 0.0; _cp_oy += 0.0;
            _cp_ix += 0.0; _cp_iy += 0.0;
            update_metrics ();
        }

        public void remove_last_vertex ()
        {
            int n = _vx.length;
            if (n <= 1) return;
            _vx = _vx[0 : n - 1]; _vy = _vy[0 : n - 1];
            _bez   = _bez[0 : n - 1];
            _cp_ox = _cp_ox[0 : n - 1]; _cp_oy = _cp_oy[0 : n - 1];
            _cp_ix = _cp_ix[0 : n - 1]; _cp_iy = _cp_iy[0 : n - 1];
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
            double dx = x - _vx[0], dy = y - _vy[0];
            return (dx * dx + dy * dy) <= (SNAP_RADIUS * SNAP_RADIUS);
        }

        public int vertex_count { get { return _vx.length; } }

        // ── Transformaciones ──────────────────────────────────────────────

        public override void translate (double dx, double dy)
        {
            for (int i = 0; i < _vx.length; i++) {
                _vx[i] += dx; _vy[i] += dy;
                _cp_ox[i] += dx; _cp_oy[i] += dy;
                _cp_ix[i] += dx; _cp_iy[i] += dy;
            }
            _cx += dx; _cy += dy;
            update_metrics ();
        }

        public void scale_vertices (double sx, double sy, double ox, double oy)
        {
            for (int i = 0; i < _vx.length; i++) {
                _vx[i] = ox + (_vx[i] - ox) * sx;
                _vy[i] = oy + (_vy[i] - oy) * sy;
                _cp_ox[i] = ox + (_cp_ox[i] - ox) * sx;
                _cp_oy[i] = oy + (_cp_oy[i] - oy) * sy;
                _cp_ix[i] = ox + (_cp_ix[i] - ox) * sx;
                _cp_iy[i] = oy + (_cp_iy[i] - oy) * sy;
            }
            update_metrics ();
        }

        public void rotate_vertices (double angle, double cx, double cy)
        {
            double ca = Math.cos (angle), sa = Math.sin (angle);
            for (int i = 0; i < _vx.length; i++) {
                double dx = _vx[i] - cx, dy = _vy[i] - cy;
                _vx[i] = cx + dx * ca - dy * sa;
                _vy[i] = cy + dx * sa + dy * ca;
                double ox = _cp_ox[i] - cx, oy = _cp_oy[i] - cy;
                _cp_ox[i] = cx + ox * ca - oy * sa;
                _cp_oy[i] = cy + ox * sa + oy * ca;
                double ix = _cp_ix[i] - cx, iy = _cp_iy[i] - cy;
                _cp_ix[i] = cx + ix * ca - iy * sa;
                _cp_iy[i] = cy + ix * sa + iy * ca;
            }
            update_metrics ();
        }

        /** Snapshot completo (vértices + datos Bézier) para transforms no destructivos. */
        public void get_full_snapshot (out double[] vx,  out double[] vy,
                                       out bool[]   bez,
                                       out double[] cox, out double[] coy,
                                       out double[] cix, out double[] ciy)
        {
            vx  = _vx[0 : _vx.length];
            vy  = _vy[0 : _vy.length];
            bez = _bez[0 : _bez.length];
            cox = _cp_ox[0 : _cp_ox.length];
            coy = _cp_oy[0 : _cp_oy.length];
            cix = _cp_ix[0 : _cp_ix.length];
            ciy = _cp_iy[0 : _cp_iy.length];
        }

        public void restore_full_snapshot (double[] vx,  double[] vy,
                                           bool[]   bez,
                                           double[] cox, double[] coy,
                                           double[] cix, double[] ciy)
        {
            _vx    = vx[0 : vx.length];   _vy    = vy[0 : vy.length];
            _bez   = bez[0 : bez.length];
            _cp_ox = cox[0 : cox.length];  _cp_oy = coy[0 : coy.length];
            _cp_ix = cix[0 : cix.length];  _cp_iy = ciy[0 : ciy.length];
            update_metrics ();
        }

        // ── Edición de vértices ───────────────────────────────────────────

        public int find_segment_at (double x, double y, double tol,
                                    out double proj_x, out double proj_y)
        {
            proj_x = x; proj_y = y;
            int n = _vx.length, segs = is_closed ? n : n - 1;
            for (int i = 0; i < segs; i++) {
                double x1, y1, x2, y2;
                if (i < n - 1) { x1 = _vx[i]; y1 = _vy[i]; x2 = _vx[i+1]; y2 = _vy[i+1]; }
                else            { x1 = _vx[n-1]; y1 = _vy[n-1]; x2 = _vx[0]; y2 = _vy[0]; }
                double dx = x2-x1, dy = y2-y1, len2 = dx*dx + dy*dy;
                if (len2 < 1.0) continue;
                double t  = ((x-x1)*dx + (y-y1)*dy) / len2;
                t         = t.clamp (0.0, 1.0);
                double ex = x1 + t*dx, ey = y1 + t*dy;
                if (Math.sqrt ((x-ex)*(x-ex) + (y-ey)*(y-ey)) <= tol) {
                    proj_x = ex; proj_y = ey;
                    return i;
                }
            }
            return -1;
        }

        public int insert_vertex (int seg_idx, double x, double y)
        {
            int insert_at = seg_idx + 1;
            double[] nvx = {}, nvy = {};
            bool[]   nb  = {};
            double[] ncox = {}, ncoy = {}, ncix = {}, nciy = {};

            for (int i = 0; i < insert_at; i++) {
                nvx += _vx[i]; nvy += _vy[i]; nb += _bez[i];
                ncox += _cp_ox[i]; ncoy += _cp_oy[i];
                ncix += _cp_ix[i]; nciy += _cp_iy[i];
            }
            nvx += x; nvy += y; nb += false;
            ncox += 0.0; ncoy += 0.0; ncix += 0.0; nciy += 0.0;
            for (int i = insert_at; i < _vx.length; i++) {
                nvx += _vx[i]; nvy += _vy[i]; nb += _bez[i];
                ncox += _cp_ox[i]; ncoy += _cp_oy[i];
                ncix += _cp_ix[i]; nciy += _cp_iy[i];
            }

            _vx = nvx; _vy = nvy; _bez = nb;
            _cp_ox = ncox; _cp_oy = ncoy;
            _cp_ix = ncix; _cp_iy = nciy;
            update_metrics ();
            return insert_at;
        }

        public int find_vertex (double x, double y)
        {
            double tol2 = HANDLE_RADIUS * HANDLE_RADIUS * 4.0;
            for (int i = 0; i < _vx.length; i++) {
                double dx = x - _vx[i], dy = y - _vy[i];
                if (dx*dx + dy*dy <= tol2) return i;
            }
            return -1;
        }

        public double get_vertex_x (int idx) { return (idx >= 0 && idx < _vx.length) ? _vx[idx] : 0.0; }
        public double get_vertex_y (int idx) { return (idx >= 0 && idx < _vy.length) ? _vy[idx] : 0.0; }

        public void move_vertex (int idx, double x, double y)
        {
            if (idx < 0 || idx >= _vx.length) return;
            double dx = x - _vx[idx], dy = y - _vy[idx];
            _vx[idx] = x; _vy[idx] = y;
            // Los CPs se mueven solidarios al vértice
            if (_bez[idx]) {
                _cp_ox[idx] += dx; _cp_oy[idx] += dy;
                _cp_ix[idx] += dx; _cp_iy[idx] += dy;
            }
            update_metrics ();
        }

        // ── API Bézier ────────────────────────────────────────────────────

        /**
         * Activa o desactiva los handles Bézier en el vértice idx.
         * Al activar, calcula posiciones iniciales tangenciales automáticas.
         */
        public void toggle_bezier (int idx)
        {
            if (idx < 0 || idx >= _vx.length) return;
            _bez[idx] = !_bez[idx];
            if (_bez[idx]) {
                int n    = _vx.length;
                int prev = (idx > 0)     ? idx - 1 : (is_closed ? n - 1 : idx);
                int next = (idx < n - 1) ? idx + 1 : (is_closed ? 0     : idx);

                double tx = 0.0, ty = 0.0;
                if (prev != idx) {
                    double pdx = _vx[idx] - _vx[prev], pdy = _vy[idx] - _vy[prev];
                    double pl  = Math.sqrt (pdx*pdx + pdy*pdy);
                    if (pl > 0) { tx += pdx/pl; ty += pdy/pl; }
                }
                if (next != idx) {
                    double ndx = _vx[next] - _vx[idx], ndy = _vy[next] - _vy[idx];
                    double nl  = Math.sqrt (ndx*ndx + ndy*ndy);
                    if (nl > 0) { tx += ndx/nl; ty += ndy/nl; }
                }
                double tl = Math.sqrt (tx*tx + ty*ty);
                if (tl > 0) { tx /= tl; ty /= tl; } else { tx = 1.0; ty = 0.0; }

                // Longitud = 1/3 de la media de los segmentos adyacentes
                double total = 0.0; int cnt = 0;
                if (prev != idx) {
                    double ddx = _vx[idx]-_vx[prev], ddy = _vy[idx]-_vy[prev];
                    total += Math.sqrt (ddx*ddx + ddy*ddy); cnt++;
                }
                if (next != idx) {
                    double ddx = _vx[next]-_vx[idx], ddy = _vy[next]-_vy[idx];
                    total += Math.sqrt (ddx*ddx + ddy*ddy); cnt++;
                }
                double len = (cnt > 0) ? (total / cnt) / 3.0 : 40.0;

                _cp_ox[idx] = _vx[idx] + tx * len;
                _cp_oy[idx] = _vy[idx] + ty * len;
                _cp_ix[idx] = _vx[idx] - tx * len;
                _cp_iy[idx] = _vy[idx] - ty * len;
            }
            update_metrics ();
        }

        /**
         * Devuelve el índice del vértice cuyo punto de control Bézier está bajo (x, y).
         * Rellena is_out: true = handle saliente, false = entrante.
         * Retorna -1 si ninguno.
         */
        public int find_bezier_handle (double x, double y, out bool is_out)
        {
            is_out = false;
            double tol2 = BEZ_HANDLE_R * BEZ_HANDLE_R * 4.0;
            for (int i = 0; i < _vx.length; i++) {
                if (!_bez[i]) continue;
                double dox = x - _cp_ox[i], doy = y - _cp_oy[i];
                if (dox*dox + doy*doy <= tol2) { is_out = true;  return i; }
                double dix = x - _cp_ix[i], diy = y - _cp_iy[i];
                if (dix*dix + diy*diy <= tol2) { is_out = false; return i; }
            }
            return -1;
        }

        /**
         * Mueve el punto de control Bézier.
         * Por defecto simétrico: el handle opuesto se refleja automáticamente.
         */
        public void move_bezier_cp (int idx, bool is_out, double x, double y)
        {
            if (idx < 0 || idx >= _vx.length || !_bez[idx]) return;
            double vx = _vx[idx], vy = _vy[idx];
            if (is_out) {
                _cp_ox[idx] = x; _cp_oy[idx] = y;
                _cp_ix[idx] = 2*vx - x; _cp_iy[idx] = 2*vy - y;
            } else {
                _cp_ix[idx] = x; _cp_iy[idx] = y;
                _cp_ox[idx] = 2*vx - x; _cp_oy[idx] = 2*vy - y;
            }
            update_metrics ();
        }

        // ── Shape overrides ───────────────────────────────────────────────

        public override bool has_handle_at (double x, double y)
        {
            if (find_vertex (x, y) >= 0) return true;
            bool dummy;
            return find_bezier_handle (x, y, out dummy) >= 0;
        }

        public override double[] get_snap_xs () { return _vx; }
        public override double[] get_snap_ys () { return _vy; }

        public override BBoxRect get_bbox ()
        {
            int n = _vx.length;
            if (n == 0) return { 0.0, 0.0, 0.0, 0.0 };
            double min_x = _vx[0], max_x = _vx[0];
            double min_y = _vy[0], max_y = _vy[0];
            for (int i = 1; i < n; i++) {
                if (_vx[i] < min_x) min_x = _vx[i]; if (_vx[i] > max_x) max_x = _vx[i];
                if (_vy[i] < min_y) min_y = _vy[i]; if (_vy[i] > max_y) max_y = _vy[i];
            }
            return { min_x, min_y, max_x - min_x, max_y - min_y };
        }

        // ── Cálculos internos ─────────────────────────────────────────────

        private void flatten_point (double mx, double my, double ox, double oy,
                                    out double rx, out double ry)
        {
            double dx = mx-ox, dy = my-oy;
            double len = Math.sqrt (dx*dx + dy*dy);
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
            for (int i = 0; i < n - 1; i++) _len_px += seg_arc_length (i, i + 1);
            if (is_closed && n >= 2)         _len_px += seg_arc_length (n - 1, 0);
            _len_m = Utils.convert_to_metters (_len_px);

            if (is_closed && n >= 3) {
                double area = 0.0;
                for (int i = 0; i < n; i++) area += seg_area_term (i, (i + 1) % n);
                double scale = (double) MEASURE_IN_PIXELS;
                _area_m2 = Math.fabs (area) / (2.0 * scale * scale);
            } else {
                _area_m2 = 0.0;
            }
        }

        /**
         * Longitud de arco del segmento from→to.
         * Exacta para segmentos rectos; numérica (N=20 puntos) para Bézier.
         */
        private double seg_arc_length (int from, int to)
        {
            if (!_bez[from] && !_bez[to]) {
                double dx = _vx[to]-_vx[from], dy = _vy[to]-_vy[from];
                return Math.sqrt (dx*dx + dy*dy);
            }
            return bez_arc_length (
                _vx[from], _vy[from],
                _bez[from] ? _cp_ox[from] : _vx[from],
                _bez[from] ? _cp_oy[from] : _vy[from],
                _bez[to]   ? _cp_ix[to]   : _vx[to],
                _bez[to]   ? _cp_iy[to]   : _vy[to],
                _vx[to], _vy[to]);
        }

        private double bez_arc_length (double p0x, double p0y,
                                       double p1x, double p1y,
                                       double p2x, double p2y,
                                       double p3x, double p3y)
        {
            const int N = 20;
            double len = 0.0, px = p0x, py = p0y;
            for (int i = 1; i <= N; i++) {
                double t = (double)i / N, mt = 1.0 - t;
                double bx = mt*mt*mt*p0x + 3*mt*mt*t*p1x + 3*mt*t*t*p2x + t*t*t*p3x;
                double by = mt*mt*mt*p0y + 3*mt*mt*t*p1y + 3*mt*t*t*p2y + t*t*t*p3y;
                double dx = bx-px, dy = by-py;
                len += Math.sqrt (dx*dx + dy*dy);
                px = bx; py = by;
            }
            return len;
        }

        /**
         * Término de la fórmula de Gauss (shoelace) para el segmento from→to.
         * Exacto para rectas; integración numérica (N=20) para Bézier.
         * Área total = |Σ seg_area_term| / 2.
         */
        private double seg_area_term (int from, int to)
        {
            if (!_bez[from] && !_bez[to]) {
                return _vx[from]*_vy[to] - _vx[to]*_vy[from];
            }
            double p0x = _vx[from], p0y = _vy[from];
            double p3x = _vx[to],   p3y = _vy[to];
            double p1x = _bez[from] ? _cp_ox[from] : p0x;
            double p1y = _bez[from] ? _cp_oy[from] : p0y;
            double p2x = _bez[to]   ? _cp_ix[to]   : p3x;
            double p2y = _bez[to]   ? _cp_iy[to]   : p3y;
            const int N = 20;
            double term = 0.0, px = p0x, py = p0y;
            for (int i = 1; i <= N; i++) {
                double t = (double)i / N, mt = 1.0 - t;
                double bx = mt*mt*mt*p0x + 3*mt*mt*t*p1x + 3*mt*t*t*p2x + t*t*t*p3x;
                double by = mt*mt*mt*p0y + 3*mt*mt*t*p1y + 3*mt*t*t*p2y + t*t*t*p3y;
                term += px*by - bx*py;
                px = bx; py = by;
            }
            return term;
        }

        // ── Drawable: hit-testing ─────────────────────────────────────────

        public override bool contains_point (double x, double y)
        {
            double tol = 8.0;
            int n = _vx.length;
            for (int i = 0; i < n - 1; i++) {
                if (near_segment (x, y, _vx[i], _vy[i], _vx[i+1], _vy[i+1], tol)) return true;
            }
            if (is_closed && n >= 2) {
                if (near_segment (x, y, _vx[n-1], _vy[n-1], _vx[0], _vy[0], tol)) return true;
                if (point_in_polygon (x, y)) return true;
            }
            return false;
        }

        private bool point_in_polygon (double x, double y)
        {
            int n = _vx.length; bool inside = false; int j = n - 1;
            for (int i = 0; i < n; i++) {
                double xi = _vx[i], yi = _vy[i], xj = _vx[j], yj = _vy[j];
                if (((yi > y) != (yj > y)) && (x < (xj-xi)*(y-yi)/(yj-yi)+xi))
                    inside = !inside;
                j = i;
            }
            return inside;
        }

        private bool near_segment (double px, double py,
                                   double x1, double y1,
                                   double x2, double y2, double tol)
        {
            double dx = x2-x1, dy = y2-y1, len2 = dx*dx + dy*dy;
            if (len2 < 1.0) return Math.sqrt ((px-x1)*(px-x1) + (py-y1)*(py-y1)) <= tol;
            double t = ((px-x1)*dx + (py-y1)*dy) / len2;
            t = t.clamp (0.0, 1.0);
            double ex = x1+t*dx, ey = y1+t*dy;
            return Math.sqrt ((px-ex)*(px-ex) + (py-ey)*(py-ey)) <= tol;
        }

        // ── Drawable: eventos ratón ───────────────────────────────────────

        public override void on_mouse_pressed  (double x, double y) {}
        public override void on_mouse_dragged  (double x, double y) {}
        public override void on_mouse_released (double x, double y) {}

        // ── Drawable: validación ──────────────────────────────────────────

        public override bool is_valid () { return _vx.length >= 2; }

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

        public override string get_size_px ()  { return "%.1f px".printf (_len_px); }
        public override string get_size_m ()   { return "%.3f m".printf (_len_m); }
        public override string get_area_m2 ()
        {
            if (is_closed && _area_m2 > 0) return "%.3f m²".printf (_area_m2);
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

            // Relleno del polígono cerrado
            if (is_closed && n >= 3) {
                cr.move_to (_vx[0], _vy[0]);
                for (int i = 0; i < n - 1; i++) paint_seg (cr, i, i + 1);
                paint_seg (cr, n - 1, 0);
                cr.set_source_rgba (fill_r, fill_g, fill_b, fill_a);
                cr.fill ();
            }

            // Trazo de segmentos confirmados
            cr.set_line_width (WALL_LINE_W);
            cr.set_source_rgba (_is_selected ? 0.8 : stroke_r,
                                _is_selected ? 0.1 : stroke_g,
                                _is_selected ? 0.1 : stroke_b,
                                1.0);
            if (n >= 2) {
                cr.move_to (_vx[0], _vy[0]);
                for (int i = 0; i < n - 1; i++) paint_seg (cr, i, i + 1);
                if (is_closed) paint_seg (cr, n - 1, 0);
                cr.stroke ();
            }

            // Segmento de previsualización (punteado, siempre recto)
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

            // Handles de vértice (modo edición o dibujo)
            if (is_drawing || (_is_selected && vertex_handles_visible)) {
                cr.set_line_width (1.5);
                cr.set_source_rgba (0.1, 0.3, 0.9, 1.0);
                for (int i = 0; i < n; i++) {
                    if (i == selected_vertex) {
                        cr.set_source_rgba (0.1, 0.3, 0.9, 1.0);
                        cr.arc (_vx[i], _vy[i], HANDLE_RADIUS + 1.5, 0, 2.0 * Math.PI);
                        cr.fill ();
                    } else {
                        paint_handle (cr, _vx[i], _vy[i]);
                    }
                }
                // Indicador verde de cierre
                if (is_drawing && n >= 3 && near_first_vertex (_cx, _cy)) {
                    cr.set_source_rgba (0.2, 0.78, 0.2, 0.9);
                    cr.arc (_vx[0], _vy[0], HANDLE_RADIUS * 2.0, 0, 2.0 * Math.PI);
                    cr.fill ();
                }

                // Handles Bézier (sólo en modo edición de vértices)
                if (!is_drawing) paint_bezier_handles (cr);
            }

            // Etiquetas
            paint_segment_labels (cr);
            if (is_closed && _area_m2 > 0.0) {
                double cx = 0.0, cy = 0.0;
                for (int i = 0; i < n; i++) { cx += _vx[i]; cy += _vy[i]; }
                paint_label (cr, "%.2f m²".printf (_area_m2), cx / n, cy / n);
            }
            cr.restore ();
        }

        /** Dibuja un segmento del muro: Bézier cúbico si alguno de los extremos tiene handles. */
        private void paint_seg (Cairo.Context cr, int from, int to)
        {
            if (_bez[from] || _bez[to]) {
                double cp1x = _bez[from] ? _cp_ox[from] : _vx[from];
                double cp1y = _bez[from] ? _cp_oy[from] : _vy[from];
                double cp2x = _bez[to]   ? _cp_ix[to]   : _vx[to];
                double cp2y = _bez[to]   ? _cp_iy[to]   : _vy[to];
                cr.curve_to (cp1x, cp1y, cp2x, cp2y, _vx[to], _vy[to]);
            } else {
                cr.line_to (_vx[to], _vy[to]);
            }
        }

        private void paint_bezier_handles (Cairo.Context cr)
        {
            for (int i = 0; i < _vx.length; i++) {
                if (!_bez[i]) continue;
                cr.save ();

                // Líneas de tangente (delgadas, grises)
                cr.set_line_width (0.8);
                cr.set_source_rgba (0.4, 0.4, 0.4, 0.7);
                cr.move_to (_vx[i], _vy[i]); cr.line_to (_cp_ox[i], _cp_oy[i]);
                cr.move_to (_vx[i], _vy[i]); cr.line_to (_cp_ix[i], _cp_iy[i]);
                cr.stroke ();

                // Handle saliente (círculo blanco borde azul)
                paint_bez_dot (cr, _cp_ox[i], _cp_oy[i]);
                // Handle entrante (círculo blanco borde azul)
                paint_bez_dot (cr, _cp_ix[i], _cp_iy[i]);

                cr.restore ();
            }
        }

        private void paint_bez_dot (Cairo.Context cr, double x, double y)
        {
            cr.set_line_width (1.2);
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.arc (x, y, BEZ_HANDLE_R, 0, 2.0 * Math.PI);
            cr.fill ();
            cr.set_source_rgba (0.15, 0.4, 0.9, 1.0);
            cr.arc (x, y, BEZ_HANDLE_R, 0, 2.0 * Math.PI);
            cr.stroke ();
        }

        private void paint_segment_labels (Cairo.Context cr)
        {
            int n = _vx.length, segs = is_closed ? n : n - 1;
            for (int i = 0; i < segs; i++) {
                int to = (i < n - 1) ? i + 1 : 0;
                double x1 = _vx[i], y1 = _vy[i], x2 = _vx[to], y2 = _vy[to];
                double dx = x2-x1, dy = y2-y1;
                // Usar la cuerda como umbral (rápido) y la longitud de arco para la etiqueta
                if (Math.sqrt (dx*dx + dy*dy) < 30.0) continue;
                double arc = seg_arc_length (i, to);
                double mx = (x1+x2)/2.0, my = (y1+y2)/2.0;
                double perp = Math.atan2 (dy, dx) - Math.PI / 2.0;
                paint_label (cr, format_m (Utils.convert_to_metters (arc)),
                             mx + Math.cos (perp)*14.0, my + Math.sin (perp)*14.0);
            }
            // Segmento de previsualización (siempre recto)
            if (is_drawing && n >= 1) {
                double dx = _cx-_vx[n-1], dy = _cy-_vy[n-1];
                double len = Math.sqrt (dx*dx + dy*dy);
                if (len >= 30.0) {
                    double mx = (_vx[n-1]+_cx)/2.0, my = (_vy[n-1]+_cy)/2.0;
                    double perp = Math.atan2 (dy, dx) - Math.PI / 2.0;
                    paint_label (cr, format_m (Utils.convert_to_metters (len)),
                                 mx + Math.cos (perp)*14.0, my + Math.sin (perp)*14.0);
                }
            }
        }
    }
}
