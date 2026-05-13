namespace Planly
{
    /**
     * Muro: polilínea/polígono con soporte para curvas de Bézier cúbicas.
     *
     * Modelo de handles Bézier
     * ────────────────────────
     * Cada vértice i tiene dos flags independientes:
     *   _bezier_outgoing_active[i]  → handle saliente: controla el segmento i → i+1
     *   _bezier_incoming_active[i]  → handle entrante: controla el segmento i-1 → i
     *
     * Al borrar el vértice k sólo se limpia:
     *   _bezier_outgoing_active[prev]  (era para el tramo prev→k, que desaparece)
     *   _bezier_incoming_active[next]  (era para el tramo k→next, que desaparece)
     * …sin tocar _bezier_incoming_active[prev] ni _bezier_outgoing_active[next].
     */
    public class Wall : Shape
    {
        private const double SNAP_RADIUS              = 15.0;
        private const double HANDLE_RADIUS            =  5.0;
        private const double BEZ_HANDLE_R             =  4.5;
        private const double WALL_LINE_W              =  3.0;
        private const double MIN_SEG_LEN              =  4.0;

        // Bézier: número de puntos de muestreo para distintos cálculos
        private const int    BEZ_OUTLINE_SAMPLES      =  6;   // detección de colisión
        private const int    ARC_LENGTH_SAMPLES       = 20;   // longitud de arco

        // Bézier: longitud inicial de los handles al activarse (toggle)
        private const double BEZ_HANDLE_FRAC          =  3.0; // divisor: len_media / 3
        private const double BEZ_HANDLE_DEFAULT_LEN   = 40.0; // fallback si no hay vecinos

        // ── Geometría ─────────────────────────────────────────────────────
        private double[] _vertices_x = {};
        private double[] _vertices_y = {};

        // ── Bézier ────────────────────────────────────────────────────────
        private bool[]   _bezier_incoming_active = {};   // handle entrante activo
        private bool[]   _bezier_outgoing_active = {};   // handle saliente activo
        private double[] _control_point_outgoing_x = {}; // control point saliente X
        private double[] _control_point_outgoing_y = {}; // control point saliente Y
        private double[] _control_point_incoming_x = {}; // control point entrante X
        private double[] _control_point_incoming_y = {}; // control point entrante Y

        // ── Previsualización ──────────────────────────────────────────────
        private double _cursor_x = 0.0;
        private double _cursor_y = 0.0;

        public bool is_drawing { get; private set; default = true; }
        public bool is_closed  { get; private set; default = false; }

        public int selected_vertex  = -1;
        /** True si la previsualización actual está bloqueada (colisión). */
        public bool preview_blocked  = false;

        // ── Métricas ──────────────────────────────────────────────────────
        private double _total_length_pixels  = 0.0;
        private double _total_length_meters  = 0.0;
        private double _area_square_meters   = 0.0;

        // ── Construcción ──────────────────────────────────────────────────

        public Wall ()
        {
            Object();
        }

        // ── API de dibujo ─────────────────────────────────────────────────

        public void start_draw(double x, double y)
        {
            _vertices_x = { x }; _vertices_y = { y };
            _bezier_incoming_active = { false }; _bezier_outgoing_active = { false };
            _control_point_outgoing_x = { 0.0 }; _control_point_outgoing_y = { 0.0 };
            _control_point_incoming_x = { 0.0 }; _control_point_incoming_y = { 0.0 };
            _cursor_x = x; _cursor_y = y;
            _has_started = true;
            is_drawing   = true;
        }

        public void update_preview(double x, double y)
        {
            if (draw_mode == DrawMode.FLATTEN && _vertices_x.length > 0) {
                int i = _vertices_x.length - 1;
                flatten_point(x, y, _vertices_x[i], _vertices_y[i], out _cursor_x, out _cursor_y);
            } else {
                _cursor_x = x; _cursor_y = y;
            }
        }

        public void add_vertex(double x, double y)
        {
            update_preview(x, y);
            int last = _vertices_x.length - 1;
            double dx   = _cursor_x - _vertices_x[last];
            double dy   = _cursor_y - _vertices_y[last];
            if (Math.sqrt(dx * dx + dy * dy) < MIN_SEG_LEN)  return;
            _vertices_x += _cursor_x; _vertices_y += _cursor_y;
            _bezier_incoming_active += false; _bezier_outgoing_active += false;
            _control_point_outgoing_x += 0.0; _control_point_outgoing_y += 0.0;
            _control_point_incoming_x += 0.0; _control_point_incoming_y += 0.0;
            update_metrics();
        }

        public void remove_last_vertex()
        {
            int n = _vertices_x.length;
            if (n <= 1) return;
            _vertices_x = _vertices_x[0 : n-1]; _vertices_y = _vertices_y[0 : n-1];
            _bezier_incoming_active  = _bezier_incoming_active[0 : n-1];
            _bezier_outgoing_active  = _bezier_outgoing_active[0 : n-1];
            _control_point_outgoing_x = _control_point_outgoing_x[0 : n-1];
            _control_point_outgoing_y = _control_point_outgoing_y[0 : n-1];
            _control_point_incoming_x = _control_point_incoming_x[0 : n-1];
            _control_point_incoming_y = _control_point_incoming_y[0 : n-1];
            update_metrics();
        }

        public void close()
        {
            is_closed  = true;  is_drawing = false; update_metrics();
        }

        public void finish()
        {
            is_drawing = false; update_metrics();
        }

        public bool near_first_vertex(double x, double y)
        {
            if (_vertices_x.length < 3) return false;
            double dx = x - _vertices_x[0], dy = y - _vertices_y[0];
            return (dx*dx + dy*dy) <= (SNAP_RADIUS * SNAP_RADIUS);
        }

        public int vertex_count { get { return _vertices_x.length; } }

        // ── Transformaciones ──────────────────────────────────────────────

        public override void translate(double dx, double dy)
        {
            for (int i = 0; i < _vertices_x.length; i++) {
                _vertices_x[i] += dx; _vertices_y[i] += dy;
                _control_point_outgoing_x[i] += dx; _control_point_outgoing_y[i] += dy;
                _control_point_incoming_x[i] += dx; _control_point_incoming_y[i] += dy;
            }
            _cursor_x += dx; _cursor_y += dy;
            update_metrics();
        }

        public void scale_vertices(double sx, double sy, double ox, double oy)
        {
            for (int i = 0; i < _vertices_x.length; i++) {
                _vertices_x[i] = ox + (_vertices_x[i]-ox)*sx;
                _vertices_y[i] = oy + (_vertices_y[i]-oy)*sy;
                _control_point_outgoing_x[i] = ox + (_control_point_outgoing_x[i]-ox)*sx;
                _control_point_outgoing_y[i] = oy + (_control_point_outgoing_y[i]-oy)*sy;
                _control_point_incoming_x[i] = ox + (_control_point_incoming_x[i]-ox)*sx;
                _control_point_incoming_y[i] = oy + (_control_point_incoming_y[i]-oy)*sy;
            }
            update_metrics();
        }

        public void rotate_vertices(double angle, double center_x, double center_y)
        {
            double cos_angle = Math.cos(angle), sin_angle = Math.sin(angle);
            for (int i = 0; i < _vertices_x.length; i++) {
                double dx = _vertices_x[i]-center_x, dy = _vertices_y[i]-center_y;
                _vertices_x[i] = center_x + dx*cos_angle - dy*sin_angle;
                _vertices_y[i] = center_y + dx*sin_angle + dy*cos_angle;
                double ox = _control_point_outgoing_x[i]-center_x, oy = _control_point_outgoing_y[i]-center_y;
                _control_point_outgoing_x[i] = center_x + ox*cos_angle - oy*sin_angle;
                _control_point_outgoing_y[i] = center_y + ox*sin_angle + oy*cos_angle;
                double ix = _control_point_incoming_x[i]-center_x, iy = _control_point_incoming_y[i]-center_y;
                _control_point_incoming_x[i] = center_x + ix*cos_angle - iy*sin_angle;
                _control_point_incoming_y[i] = center_y + ix*sin_angle + iy*cos_angle;
            }
            update_metrics();
        }

        public void get_full_snapshot(out double[] vertices_x, out double[] vertices_y,
            out bool[]   bezier_incoming, out bool[]   bezier_outgoing,
            out double[] control_outgoing_x, out double[] control_outgoing_y,
            out double[] control_incoming_x, out double[] control_incoming_y)
        {
            vertices_x       = _vertices_x[0 : _vertices_x.length];
            vertices_y       = _vertices_y[0 : _vertices_y.length];
            bezier_incoming  = _bezier_incoming_active[0 : _bezier_incoming_active.length];
            bezier_outgoing  = _bezier_outgoing_active[0 : _bezier_outgoing_active.length];
            control_outgoing_x = _control_point_outgoing_x[0 : _control_point_outgoing_x.length];
            control_outgoing_y = _control_point_outgoing_y[0 : _control_point_outgoing_y.length];
            control_incoming_x = _control_point_incoming_x[0 : _control_point_incoming_x.length];
            control_incoming_y = _control_point_incoming_y[0 : _control_point_incoming_y.length];
        }

        public void restore_full_snapshot(double[] vertices_x, double[] vertices_y,
            bool[]   bezier_incoming, bool[]   bezier_outgoing,
            double[] control_outgoing_x, double[] control_outgoing_y,
            double[] control_incoming_x, double[] control_incoming_y)
        {
            _vertices_x              = vertices_x[0 : vertices_x.length];
            _vertices_y              = vertices_y[0 : vertices_y.length];
            _bezier_incoming_active  = bezier_incoming[0 : bezier_incoming.length];
            _bezier_outgoing_active  = bezier_outgoing[0 : bezier_outgoing.length];
            _control_point_outgoing_x = control_outgoing_x[0 : control_outgoing_x.length];
            _control_point_outgoing_y = control_outgoing_y[0 : control_outgoing_y.length];
            _control_point_incoming_x = control_incoming_x[0 : control_incoming_x.length];
            _control_point_incoming_y = control_incoming_y[0 : control_incoming_y.length];
            update_metrics();
        }

        // ── Edición de vértices ───────────────────────────────────────────

        /**
         * Elimina el vértice idx y mantiene la figura cerrada/abierta.
         * Sólo desactiva los handles que apuntaban a los segmentos adyacentes
         * al vértice eliminado; el resto de handles se conservan intactos.
         */
        public bool delete_vertex(int idx)
        {
            int n         = _vertices_x.length;
            int min_verts = is_closed ? 3 : 2;
            if (n <= min_verts || idx < 0 || idx >= n) return false;

            int prev_b = is_closed ? (idx - 1 + n) % n : (idx > 0     ? idx - 1 : -1);
            int next_b = is_closed ? (idx + 1) % n      : (idx < n - 1 ? idx + 1 : -1);

            double[] new_vertices_x = {}, new_vertices_y = {};
            bool[]   new_bezier_incoming = {}, new_bezier_outgoing = {};
            double[] new_control_outgoing_x = {}, new_control_outgoing_y = {};
            double[] new_control_incoming_x = {}, new_control_incoming_y = {};
            for (int i = 0; i < n; i++) {
                if (i == idx) continue;
                new_vertices_x += _vertices_x[i]; new_vertices_y += _vertices_y[i];
                new_bezier_incoming += _bezier_incoming_active[i];
                new_bezier_outgoing += _bezier_outgoing_active[i];
                new_control_outgoing_x += _control_point_outgoing_x[i];
                new_control_outgoing_y += _control_point_outgoing_y[i];
                new_control_incoming_x += _control_point_incoming_x[i];
                new_control_incoming_y += _control_point_incoming_y[i];
            }
            _vertices_x = new_vertices_x; _vertices_y = new_vertices_y;
            _bezier_incoming_active = new_bezier_incoming;
            _bezier_outgoing_active = new_bezier_outgoing;
            _control_point_outgoing_x = new_control_outgoing_x;
            _control_point_outgoing_y = new_control_outgoing_y;
            _control_point_incoming_x = new_control_incoming_x;
            _control_point_incoming_y = new_control_incoming_y;

            // Ajustar índices tras la eliminación
            int new_prev = (prev_b >= 0) ? (prev_b > idx ? prev_b - 1 : prev_b) : -1;
            int new_next = (next_b >= 0) ? (next_b > idx ? next_b - 1 : next_b) : -1;

            // Solo limpiar exactamente los handles que apuntaban al vértice borrado:
            //   - _bezier_outgoing_active[prev]: era el handle saliente de prev hacia idx
            //   - _bezier_incoming_active[next]: era el handle entrante de next desde idx
            // Los demás (_bezier_incoming_active[prev], _bezier_outgoing_active[next]) se respetan.
            if (new_prev >= 0 && new_prev < _vertices_x.length)
                _bezier_outgoing_active[new_prev] = false;
            if (new_next >= 0 && new_next < _vertices_x.length)
                _bezier_incoming_active[new_next] = false;

            update_metrics();
            return true;
        }

        public int find_segment_at(double x, double y, double tol,
            out double proj_x, out double proj_y)
        {
            proj_x = x; proj_y = y;
            int n = _vertices_x.length, segment_count = is_closed ? n : n - 1;
            for (int i = 0; i < segment_count; i++) {
                double x1, y1, x2, y2;
                if (i < n-1) {
                    x1=_vertices_x[i]; y1=_vertices_y[i];
                    x2=_vertices_x[i+1]; y2=_vertices_y[i+1];
                }else {
                    x1=_vertices_x[n-1]; y1=_vertices_y[n-1];
                    x2=_vertices_x[0]; y2=_vertices_y[0];
                }
                double dx=x2-x1, dy=y2-y1, len2=dx*dx+dy*dy;
                if (len2 < 1.0) continue;
                double t = ((x-x1)*dx+(y-y1)*dy)/len2;
                t = t.clamp(0.0, 1.0);
                double ex=x1+t*dx, ey=y1+t*dy;
                if (Math.sqrt((x-ex)*(x-ex)+(y-ey)*(y-ey)) <= tol) {
                    proj_x=ex; proj_y=ey; return i;
                }
            }
            return -1;
        }

        public int insert_vertex(int seg_idx, double x, double y)
        {
            int insert_at = seg_idx + 1;
            double[] new_vertices_x={}, new_vertices_y={};
            bool[]   new_bezier_incoming={}, new_bezier_outgoing={};
            double[] new_control_outgoing_x={}, new_control_outgoing_y={};
            double[] new_control_incoming_x={}, new_control_incoming_y={};
            for (int i = 0; i < _vertices_x.length; i++) {
                if (i == insert_at) {
                    new_vertices_x+=x; new_vertices_y+=y;
                    new_bezier_incoming+=false; new_bezier_outgoing+=false;
                    new_control_outgoing_x+=0.0; new_control_outgoing_y+=0.0;
                    new_control_incoming_x+=0.0; new_control_incoming_y+=0.0;
                }
                new_vertices_x+=_vertices_x[i]; new_vertices_y+=_vertices_y[i];
                new_bezier_incoming+=_bezier_incoming_active[i];
                new_bezier_outgoing+=_bezier_outgoing_active[i];
                new_control_outgoing_x+=_control_point_outgoing_x[i];
                new_control_outgoing_y+=_control_point_outgoing_y[i];
                new_control_incoming_x+=_control_point_incoming_x[i];
                new_control_incoming_y+=_control_point_incoming_y[i];
            }
            if (insert_at >= _vertices_x.length) {
                new_vertices_x+=x; new_vertices_y+=y;
                new_bezier_incoming+=false; new_bezier_outgoing+=false;
                new_control_outgoing_x+=0.0; new_control_outgoing_y+=0.0;
                new_control_incoming_x+=0.0; new_control_incoming_y+=0.0;
            }
            _vertices_x=new_vertices_x; _vertices_y=new_vertices_y;
            _bezier_incoming_active=new_bezier_incoming;
            _bezier_outgoing_active=new_bezier_outgoing;
            _control_point_outgoing_x=new_control_outgoing_x;
            _control_point_outgoing_y=new_control_outgoing_y;
            _control_point_incoming_x=new_control_incoming_x;
            _control_point_incoming_y=new_control_incoming_y;
            update_metrics();
            return insert_at;
        }

        public int find_vertex(double x, double y)
        {
            double tol2 = HANDLE_RADIUS * HANDLE_RADIUS * 4.0;
            for (int i = 0; i < _vertices_x.length; i++) {
                double dx=x-_vertices_x[i], dy=y-_vertices_y[i];
                if (dx*dx+dy*dy <= tol2) return i;
            }
            return -1;
        }

        public double get_vertex_x(int idx)
        {
            return (idx>=0 && idx<_vertices_x.length) ? _vertices_x[idx] : 0.0;
        }

        public double get_vertex_y(int idx)
        {
            return (idx>=0 && idx<_vertices_y.length) ? _vertices_y[idx] : 0.0;
        }

        public void move_vertex(int idx, double x, double y)
        {
            if (idx < 0 || idx >= _vertices_x.length) return;
            double dx=x-_vertices_x[idx], dy=y-_vertices_y[idx];
            _vertices_x[idx]=x; _vertices_y[idx]=y;
            _control_point_outgoing_x[idx]+=dx; _control_point_outgoing_y[idx]+=dy;
            _control_point_incoming_x[idx]+=dx; _control_point_incoming_y[idx]+=dy;
            update_metrics();
        }

        // ── API Bézier ────────────────────────────────────────────────────

        public void toggle_bezier(int idx)
        {
            if (idx < 0 || idx >= _vertices_x.length) return;
            bool was = _bezier_incoming_active[idx] || _bezier_outgoing_active[idx];
            if (was) {
                _bezier_incoming_active[idx] = false; _bezier_outgoing_active[idx] = false;
            } else {
                _bezier_incoming_active[idx] = true; _bezier_outgoing_active[idx] = true;
                int n    = _vertices_x.length;
                int prev = is_closed ? (idx-1+n)%n : (idx>0     ? idx-1 : idx);
                int next = is_closed ? (idx+1)%n    : (idx<n-1   ? idx+1 : idx);
                double tx=0.0, ty=0.0;
                if (prev != idx) {
                    double pd=Math.sqrt((_vertices_x[idx]-_vertices_x[prev])*(_vertices_x[idx]-_vertices_x[prev]) +
                            (_vertices_y[idx]-_vertices_y[prev])*(_vertices_y[idx]-_vertices_y[prev]));
                    if (pd>0) {
                        tx+=(_vertices_x[idx]-_vertices_x[prev])/pd;
                        ty+=(_vertices_y[idx]-_vertices_y[prev])/pd;
                    }
                }
                if (next != idx) {
                    double nd=Math.sqrt((_vertices_x[next]-_vertices_x[idx])*(_vertices_x[next]-_vertices_x[idx]) +
                            (_vertices_y[next]-_vertices_y[idx])*(_vertices_y[next]-_vertices_y[idx]));
                    if (nd>0) {
                        tx+=(_vertices_x[next]-_vertices_x[idx])/nd;
                        ty+=(_vertices_y[next]-_vertices_y[idx])/nd;
                    }
                }
                double tl=Math.sqrt(tx*tx+ty*ty);
                if (tl>0) {
                    tx/=tl; ty/=tl;
                } else {
                    tx=1.0; ty=0.0;
                }
                double total=0.0; int cnt=0;
                if (prev!=idx) {
                    double d=Math.sqrt((_vertices_x[idx]-_vertices_x[prev])*(_vertices_x[idx]-_vertices_x[prev])+
                            (_vertices_y[idx]-_vertices_y[prev])*(_vertices_y[idx]-_vertices_y[prev]));
                    total+=d; cnt++;
                }
                if (next!=idx) {
                    double d=Math.sqrt((_vertices_x[next]-_vertices_x[idx])*(_vertices_x[next]-_vertices_x[idx])+
                            (_vertices_y[next]-_vertices_y[idx])*(_vertices_y[next]-_vertices_y[idx]));
                    total+=d; cnt++;
                }
                double len = (cnt > 0) ? (total / cnt) / BEZ_HANDLE_FRAC : BEZ_HANDLE_DEFAULT_LEN;
                _control_point_outgoing_x[idx]=_vertices_x[idx]+tx*len;
                _control_point_outgoing_y[idx]=_vertices_y[idx]+ty*len;
                _control_point_incoming_x[idx]=_vertices_x[idx]-tx*len;
                _control_point_incoming_y[idx]=_vertices_y[idx]-ty*len;
            }
            update_metrics();
        }

        public int find_bezier_handle(double x, double y, out bool is_out)
        {
            is_out = false;
            double tol2 = BEZ_HANDLE_R * BEZ_HANDLE_R * 4.0;
            for (int i = 0; i < _vertices_x.length; i++) {
                if (_bezier_outgoing_active[i]) {
                    double dox=x-_control_point_outgoing_x[i], doy=y-_control_point_outgoing_y[i];
                    if (dox*dox+doy*doy<=tol2) {
                        is_out=true;  return i;
                    }
                }
                if (_bezier_incoming_active[i]) {
                    double dix=x-_control_point_incoming_x[i], diy=y-_control_point_incoming_y[i];
                    if (dix*dix+diy*diy<=tol2) {
                        is_out=false; return i;
                    }
                }
            }
            return -1;
        }

        public void move_bezier_cp(int idx, bool is_out, double x, double y)
        {
            if (idx < 0 || idx >= _vertices_x.length) return;
            double vertex_x=_vertices_x[idx], vertex_y=_vertices_y[idx];
            if (is_out) {
                _control_point_outgoing_x[idx]=x; _control_point_outgoing_y[idx]=y;
                _control_point_incoming_x[idx]=2*vertex_x-x;
                _control_point_incoming_y[idx]=2*vertex_y-y;
            } else {
                _control_point_incoming_x[idx]=x; _control_point_incoming_y[idx]=y;
                _control_point_outgoing_x[idx]=2*vertex_x-x;
                _control_point_outgoing_y[idx]=2*vertex_y-y;
            }
            update_metrics();
        }

        // ── Detección de colisión ─────────────────────────────────────────

        /**
         * True si el segmento (x1,y1)→(x2,y2) se cruza con algún segmento YA
         * CONFIRMADO de este mismo muro (auto-intersección).
         *
         * from_idx : índice del vértice en (x1,y1); se salta el segmento que
         *            termina en ese vértice (adyacente, no se considera cruce).
         * closing  : true cuando el segmento es el de cierre → también salta S0
         *            (que comparte V0 con el segmento de cierre).
         */
        public bool new_segment_crosses_self(double x1, double y1,
            double x2, double y2,
            int from_idx,
            bool closing = false)
        {
            int n = _vertices_x.length;
            for (int i = 0; i < n - 1; i++) {
                if (from_idx > 0 && i == from_idx - 1) continue; // adyacente al inicio
                if (closing && i == 0)                  continue; // adyacente al cierre (V0)
                if (segs_cross(x1, y1, x2, y2,
                    _vertices_x[i], _vertices_y[i], _vertices_x[i+1], _vertices_y[i+1])) {
                    return true;
                }
            }
            return false;
        }

        /**
         * True si existe algún par de segmentos no adyacentes que se cruzan
         * en el estado actual del muro (abierto o cerrado).
         * Se usa después de mover un vértice para detectar auto-intersecciones.
         */
        public bool has_self_intersection()
        {
            int n    = _vertices_x.length;
            int segment_count = is_closed ? n : n - 1;
            if (segment_count < 3) return false;

            for (int i = 0; i < segment_count; i++) {
                int ni = (i + 1) % n;
                double segment_a_x = _vertices_x[i], segment_a_y = _vertices_y[i];
                double segment_b_x = _vertices_x[ni], segment_b_y = _vertices_y[ni];

                for (int j = i + 2; j < segment_count; j++) {
                    // Para polígono cerrado: (Sc, S0) son adyacentes, saltar
                    if (is_closed && i == 0 && j == segment_count - 1) continue;
                    int nj = (j + 1) % n;
                    if (segs_cross(segment_a_x, segment_a_y, segment_b_x, segment_b_y,
                        _vertices_x[j], _vertices_y[j], _vertices_x[nj], _vertices_y[nj])) {
                        return true;
                    }
                }
            }
            return false;
        }

        /**
         * Devuelve true si alguno de los puntos (vertices_x[i], vertices_y[i]) caería dentro de
         * este polígono (evaluado como contorno cerrado aunque is_closed sea false).
         * Se usa para impedir dibujar un polígono que encierre a una figura existente.
         */
        public bool encloses_any_of(double[] vertices_x, double[] vertices_y)
        {
            for (int i = 0; i < vertices_x.length; i++) {
                if (point_in_polygon(vertices_x[i], vertices_y[i]))  return true;
            }
            return false;
        }

        /**
         * Devuelve true si el segmento (x1,y1)→(x2,y2) cruza o penetra este muro.
         * Cuando x1==x2 y y1==y2 sólo comprueba si el punto está dentro del polígono.
         * Se usa para impedir dibujar sobre figuras existentes.
         */
        public bool blocks_new_segment(double x1, double y1, double x2, double y2)
        {
            double[] ox, oy;
            get_outline_pts(out ox, out oy);

            for (int i = 0; i < ox.length - 1; i++) {
                if (segs_cross(x1, y1, x2, y2, ox[i], oy[i], ox[i+1], oy[i+1]))  return true;
            }

            if (is_closed && point_in_polygon(x2, y2))  return true;

            return false;
        }

        /**
         * Devuelve true si este muro se superpone geométricamente con other.
         *
         * Algoritmo:
         *   1. Convertir ambos muros a polilíneas (aproximando curvas Bézier).
         *   2. Comprobar si algún par de segmentos se cruza propiamente.
         *   3. Para polígonos cerrados, comprobar también si uno está dentro del otro.
         */
        public bool collides_with(Wall other)
        {
            double[] outline_a_x, outline_a_y, outline_b_x, outline_b_y;
            get_outline_pts(out outline_a_x, out outline_a_y);
            other.get_outline_pts(out outline_b_x, out outline_b_y);

            int outline_a_length = outline_a_x.length, outline_b_length = outline_b_x.length;

            for (int i = 0; i < outline_a_length - 1; i++) {
                for (int j = 0; j < outline_b_length - 1; j++) {
                    if (segs_cross(outline_a_x[i], outline_a_y[i],
                                   outline_a_x[i+1], outline_a_y[i+1],
                                   outline_b_x[j], outline_b_y[j],
                                   outline_b_x[j+1], outline_b_y[j+1])) {
                        return true;
                    }
                }
            }

            if (is_closed && outline_b_length > 0 &&
                point_in_polygon(outline_b_x[0], outline_b_y[0]))  return true;
            if (other.is_closed && outline_a_length > 0 &&
                other.point_in_polygon(outline_a_x[0], outline_a_y[0]))  return true;

            return false;
        }

        /**
         * Devuelve los puntos de la polilínea de contorno.
         * Los segmentos Bézier se aproximan con 6 puntos intermedios.
         */
        private void get_outline_pts(out double[] ox, out double[] oy)
        {
            double[] px = {}, py = {};
            int n = _vertices_x.length;
            if (n == 0) {
                ox = px; oy = py; return;
            }

            px += _vertices_x[0]; py += _vertices_y[0];
            int segment_count = is_closed ? n : n - 1;

            for (int i = 0; i < segment_count; i++) {
                int to = (i < n - 1) ? i + 1 : 0;
                if (_bezier_outgoing_active[i] || _bezier_incoming_active[to]) {
                    double point0_x = _vertices_x[i], point0_y = _vertices_y[i];
                    double point3_x = _vertices_x[to], point3_y = _vertices_y[to];
                    double point1_x = _bezier_outgoing_active[i]
                        ? _control_point_outgoing_x[i] : point0_x;
                    double point1_y = _bezier_outgoing_active[i]
                        ? _control_point_outgoing_y[i] : point0_y;
                    double point2_x = _bezier_incoming_active[to]
                        ? _control_point_incoming_x[to] : point3_x;
                    double point2_y = _bezier_incoming_active[to]
                        ? _control_point_incoming_y[to] : point3_y;
                    const int N = BEZ_OUTLINE_SAMPLES;
                    for (int k = 1; k <= N; k++) {
                        double t = (double)k / N, mt = 1.0 - t;
                        px += mt*mt*mt*point0_x + 3*mt*mt*t*point1_x
                            + 3*mt*t*t*point2_x + t*t*t*point3_x;
                        py += mt*mt*mt*point0_y + 3*mt*mt*t*point1_y
                            + 3*mt*t*t*point2_y + t*t*t*point3_y;
                    }
                } else {
                    px += _vertices_x[to]; py += _vertices_y[to];
                }
            }
            ox = px; oy = py;
        }

        /** True si los segmentos (x1,y1)-(x2,y2) y (x3,y3)-(x4,y4) se cruzan propiamente. */
        private bool segs_cross(double x1, double y1, double x2, double y2,
            double x3, double y3, double x4, double y4)
        {
            double d1 = cross2d(x3, y3, x4, y4, x1, y1);
            double d2 = cross2d(x3, y3, x4, y4, x2, y2);
            double d3 = cross2d(x1, y1, x2, y2, x3, y3);
            double d4 = cross2d(x1, y1, x2, y2, x4, y4);
            return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
                   ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
        }

        private double cross2d(double ox, double oy, double ex, double ey,
            double px, double py)
        {
            return (ex - ox) * (py - oy) - (ey - oy) * (px - ox);
        }

        // ── Shape overrides ───────────────────────────────────────────────

        public override bool has_handle_at(double x, double y)
        {
            if (find_vertex(x, y) >= 0)  return true;
            bool dummy;
            return find_bezier_handle(x, y, out dummy) >= 0;
        }

        public override double[] get_snap_xs()
        {
            return _vertices_x;
        }

        public override double[] get_snap_ys()
        {
            return _vertices_y;
        }

        public override BBoxRect get_bbox()
        {
            int n = _vertices_x.length;
            if (n == 0) return { 0.0, 0.0, 0.0, 0.0 };
            double min_x=_vertices_x[0], max_x=_vertices_x[0];
            double min_y=_vertices_y[0], max_y=_vertices_y[0];
            for (int i = 1; i < n; i++) {
                if (_vertices_x[i]<min_x) min_x=_vertices_x[i];
                if (_vertices_x[i]>max_x) max_x=_vertices_x[i];
                if (_vertices_y[i]<min_y) min_y=_vertices_y[i];
                if (_vertices_y[i]>max_y) max_y=_vertices_y[i];
            }
            return { min_x, min_y, max_x-min_x, max_y-min_y };
        }

        // ── Cálculos internos ─────────────────────────────────────────────

        private void flatten_point(double mx, double my, double ox, double oy,
                                    out double rx, out double ry)
        {
            double dx = mx - ox, dy = my - oy;
            double len = Math.sqrt(dx*dx + dy*dy);
            if (len < 1.0) { rx = ox; ry = oy; return; }
            double rad = DrawingMath.snap_angle_to_cardinal(
                Math.atan2(dy, dx) * 180.0 / Math.PI) * Math.PI / 180.0;
            rx = ox + len * Math.cos(rad);
            ry = oy + len * Math.sin(rad);
        }

        private void update_metrics()
        {
            int n = _vertices_x.length;
            _total_length_pixels = 0.0;
            for (int i = 0; i < n-1; i++) _total_length_pixels += seg_arc_length(i, i+1);
            if (is_closed && n >= 2) _total_length_pixels += seg_arc_length(n-1, 0);
            _total_length_meters = DrawingMath.convert_pixels_to_meters(_total_length_pixels);
            if (is_closed && n >= 3) {
                double area = 0.0;
                for (int i = 0; i < n; i++) area += seg_area_term(i, (i+1)%n);
                double scale = (double) MEASURE_IN_PIXELS;
                _area_square_meters = Math.fabs(area) / (2.0 * scale * scale);
            } else {
                _area_square_meters = 0.0;
            }
        }

        private double seg_arc_length(int from, int to)
        {
            if (!_bezier_outgoing_active[from] && !_bezier_incoming_active[to]) {
                double dx=_vertices_x[to]-_vertices_x[from],
                       dy=_vertices_y[to]-_vertices_y[from];
                return Math.sqrt(dx*dx+dy*dy);
            }
            return bez_arc_length(
                _vertices_x[from], _vertices_y[from],
                _bezier_outgoing_active[from]
                    ? _control_point_outgoing_x[from] : _vertices_x[from],
                _bezier_outgoing_active[from]
                    ? _control_point_outgoing_y[from] : _vertices_y[from],
                _bezier_incoming_active[to]
                    ? _control_point_incoming_x[to] : _vertices_x[to],
                _bezier_incoming_active[to]
                    ? _control_point_incoming_y[to] : _vertices_y[to],
                _vertices_x[to], _vertices_y[to]);
        }

        private double bez_arc_length(double point0_x, double point0_y,
            double point1_x, double point1_y,
            double point2_x, double point2_y,
            double point3_x, double point3_y)
        {
            const int N = ARC_LENGTH_SAMPLES;
            double arc_length=0.0, px=point0_x, py=point0_y;
            for (int i = 1; i <= N; i++) {
                double t=(double)i/N, mt=1.0-t;
                double bx=mt*mt*mt*point0_x+3*mt*mt*t*point1_x
                         +3*mt*t*t*point2_x+t*t*t*point3_x;
                double by=mt*mt*mt*point0_y+3*mt*mt*t*point1_y
                         +3*mt*t*t*point2_y+t*t*t*point3_y;
                double dx=bx-px, dy=by-py;
                arc_length+=Math.sqrt(dx*dx+dy*dy);
                px=bx; py=by;
            }
            return arc_length;
        }

        private double seg_area_term(int from, int to)
        {
            if (!_bezier_outgoing_active[from] && !_bezier_incoming_active[to]) {
                return _vertices_x[from]*_vertices_y[to] - _vertices_x[to]*_vertices_y[from];
            }
            double point0_x=_vertices_x[from], point0_y=_vertices_y[from];
            double point3_x=_vertices_x[to], point3_y=_vertices_y[to];
            double point1_x=_bezier_outgoing_active[from] ? _control_point_outgoing_x[from] : point0_x;
            double point1_y=_bezier_outgoing_active[from] ? _control_point_outgoing_y[from] : point0_y;
            double point2_x=_bezier_incoming_active[to]   ? _control_point_incoming_x[to]   : point3_x;
            double point2_y=_bezier_incoming_active[to]   ? _control_point_incoming_y[to]   : point3_y;
            const int N=20;
            double term=0.0, px=point0_x, py=point0_y;
            for (int i = 1; i <= N; i++) {
                double t=(double)i/N, mt=1.0-t;
                double bx=mt*mt*mt*point0_x+3*mt*mt*t*point1_x+3*mt*t*t*point2_x+t*t*t*point3_x;
                double by=mt*mt*mt*point0_y+3*mt*mt*t*point1_y+3*mt*t*t*point2_y+t*t*t*point3_y;
                term+=px*by-bx*py; px=bx; py=by;
            }
            return term;
        }

        // ── Drawable: hit-testing ─────────────────────────────────────────

        public override bool contains_point(double x, double y)
        {
            double tol=8.0; int n=_vertices_x.length;
            for (int i=0; i<n-1; i++)
                if (near_segment(x, y, _vertices_x[i], _vertices_y[i],
                                 _vertices_x[i+1], _vertices_y[i+1], tol)) return true;
            if (is_closed && n>=2) {
                if (near_segment(x, y, _vertices_x[n-1], _vertices_y[n-1],
                                 _vertices_x[0], _vertices_y[0], tol)) return true;
                if (point_in_polygon(x, y)) return true;
            }
            return false;
        }

        private bool point_in_polygon(double x, double y)
        {
            int n=_vertices_x.length; bool inside=false; int j=n-1;
            for (int i=0; i<n; i++) {
                double xi=_vertices_x[i], yi=_vertices_y[i];
                double xj=_vertices_x[j], yj=_vertices_y[j];
                if (((yi>y)!=(yj>y)) && (x<(xj-xi)*(y-yi)/(yj-yi)+xi)) inside=!inside;
                j=i;
            }
            return inside;
        }

        private bool near_segment(double px, double py,
            double x1, double y1,
            double x2, double y2, double tol)
        {
            double dx=x2-x1, dy=y2-y1, len2=dx*dx+dy*dy;
            if (len2<1.0) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))<=tol;
            double t=((px-x1)*dx+(py-y1)*dy)/len2;
            t=t.clamp(0.0, 1.0);
            double ex=x1+t*dx, ey=y1+t*dy;
            return Math.sqrt((px-ex)*(px-ex)+(py-ey)*(py-ey))<=tol;
        }


        public override bool is_valid()
        {
            return _vertices_x.length >= 2;
        }

        // ── Métricas ──────────────────────────────────────────────────────

        public override MetricLine[] get_metrics()
        {
            MetricLine[] m = { metric_px_m(_("Longitud total"), _total_length_pixels) };
            if (is_closed && _area_square_meters > 0) {
                MetricLine a = { _("Área"), "", "%.3f m²".printf(_area_square_meters) };
                m += a;
            }
            return m;
        }

        public override string get_size_px()
        {
            return "%.1f px".printf(_total_length_pixels);
        }

        public override string get_size_m()
        {
            return "%.3f m".printf(_total_length_meters);
        }

        public override string get_area_m2()
        {
            if (is_closed && _area_square_meters>0) return "%.3f m²".printf(_area_square_meters);
            return "";
        }

        // ── Renderizado ───────────────────────────────────────────────────

        public override void paint(Cairo.Context cr)
        {
            int n = _vertices_x.length;
            if (n == 0) return;
            cr.save();
            var palette = ColorTheme.instance.active;

            cr.set_line_cap(Cairo.LineCap.ROUND);
            cr.set_line_join(Cairo.LineJoin.ROUND);

            if (is_closed && n >= 3) {
                cr.move_to(_vertices_x[0], _vertices_y[0]);
                for (int i=0; i<n-1; i++) paint_seg(cr, i, i+1);
                paint_seg(cr, n-1, 0);
                palette.wall_fill.apply(cr);
                cr.fill();
            }

            cr.set_line_width(WALL_LINE_W);
            if (_is_selected) {
                palette.wall_selected.apply(cr);
            } else {
                palette.wall_stroke.apply(cr);
            }
            if (n >= 2) {
                cr.move_to(_vertices_x[0], _vertices_y[0]);
                for (int i=0; i<n-1; i++) paint_seg(cr, i, i+1);
                if (is_closed) paint_seg(cr, n-1, 0);
                cr.stroke();
            }

            // Segmento de previsualización — rojo si está bloqueado por colisión
            if (is_drawing) {
                cr.save();
                double[] dash = { 6.0, 4.0 };
                cr.set_dash(dash, 0.0);
                if (preview_blocked) {
                    palette.wall_preview_blocked.apply(cr);
                } else {
                    palette.wall_stroke.with_alpha(palette.wall_stroke.alpha * 0.6).apply(cr);
                }
                cr.move_to(_vertices_x[n-1], _vertices_y[n-1]);
                cr.line_to(_cursor_x, _cursor_y);
                cr.stroke();
                cr.restore();
            }

            if (is_drawing || (_is_selected && vertex_handles_visible)) {
                cr.set_line_width(1.5);
                if (_is_selected) {
                    palette.handle_vertex_active.apply(cr);
                } else {
                    palette.handle_vertex.apply(cr);
                }
                for (int i=0; i<n; i++) {
                    if (i == selected_vertex) {
                        palette.handle_vertex_active.apply(cr);
                        cr.arc(_vertices_x[i], _vertices_y[i], HANDLE_RADIUS+1.5, 0, 2.0*Math.PI);
                        cr.fill();
                    } else {
                        paint_handle(cr, _vertices_x[i], _vertices_y[i]);
                    }
                }
                // Indicador de cierre: verde si es válido, rojo si está bloqueado
                if (is_drawing && n>=3 && near_first_vertex(_cursor_x, _cursor_y)) {
                    if (preview_blocked) {
                        palette.wall_preview_blocked.apply(cr);
                    } else {
                        palette.handle_vertex_snap.apply(cr);
                    }
                    cr.arc(_vertices_x[0], _vertices_y[0], HANDLE_RADIUS*2.0, 0, 2.0*Math.PI);
                    cr.fill();
                }
                if (!is_drawing) paint_bezier_handles(cr);
            }

            paint_segment_labels(cr);
            paint_vertex_angles(cr);
            if (is_closed && _area_square_meters>0.0) {
                double base_center_x=0.0, base_center_y=0.0;
                for (int i=0; i<n; i++) {
                    base_center_x+=_vertices_x[i]; base_center_y+=_vertices_y[i];
                }
                paint_label(cr, "%.2f m²".printf(_area_square_meters),
                            base_center_x/n, base_center_y/n);
            }
            cr.restore();
        }

        private void paint_seg(Cairo.Context cr, int from, int to)
        {
            if (_bezier_outgoing_active[from] || _bezier_incoming_active[to]) {
                double cp1x=_bezier_outgoing_active[from]
                    ?_control_point_outgoing_x[from]:_vertices_x[from];
                double cp1y=_bezier_outgoing_active[from]
                    ?_control_point_outgoing_y[from]:_vertices_y[from];
                double cp2x=_bezier_incoming_active[to]
                    ?_control_point_incoming_x[to]:_vertices_x[to];
                double cp2y=_bezier_incoming_active[to]
                    ?_control_point_incoming_y[to]:_vertices_y[to];
                cr.curve_to(cp1x, cp1y, cp2x, cp2y, _vertices_x[to], _vertices_y[to]);
            } else {
                cr.line_to(_vertices_x[to], _vertices_y[to]);
            }
        }

        private void paint_bezier_handles(Cairo.Context cr)
        {
            for (int i=0; i<_vertices_x.length; i++) {
                if (!_bezier_incoming_active[i] && !_bezier_outgoing_active[i]) continue;
                cr.save();
                cr.set_line_width(0.8);
                ColorTheme.instance.active.bezier_tangent_line.apply(cr);
                if (_bezier_outgoing_active[i]) {
                    cr.move_to(_vertices_x[i], _vertices_y[i]);
                    cr.line_to(_control_point_outgoing_x[i], _control_point_outgoing_y[i]);
                }
                if (_bezier_incoming_active[i]) {
                    cr.move_to(_vertices_x[i], _vertices_y[i]);
                    cr.line_to(_control_point_incoming_x[i], _control_point_incoming_y[i]);
                }
                cr.stroke();
                if (_bezier_outgoing_active[i])
                    paint_bez_dot(cr, _control_point_outgoing_x[i], _control_point_outgoing_y[i]);
                if (_bezier_incoming_active[i])
                    paint_bez_dot(cr, _control_point_incoming_x[i], _control_point_incoming_y[i]);
                cr.restore();
            }
        }

        private void paint_bez_dot(Cairo.Context cr, double x, double y)
        {
            var palette = ColorTheme.instance.active;
            cr.set_line_width(1.2);
            palette.bbox_handle_fill.apply(cr);
            cr.arc(x, y, BEZ_HANDLE_R, 0, 2.0*Math.PI); cr.fill();
            palette.bezier_handle_dot.apply(cr);
            cr.arc(x, y, BEZ_HANDLE_R, 0, 2.0*Math.PI); cr.stroke();
        }

        /**
         * Dibuja el ángulo interior (en grados) en cada vértice que tenga dos
         * segmentos adyacentes.  La etiqueta se coloca a lo largo de la bisectriz
         * hacia el interior del polígono (o entre los dos brazos para polilíneas).
         */
        private void paint_vertex_angles(Cairo.Context cr)
        {
            int n = _vertices_x.length;
            if (n < 2) return;

            // Signo del área (shoelace) para distinguir interior de polígonos cerrados
            double area_sign = 0.0;
            if (is_closed && n >= 3) {
                double a = 0.0;
                for (int k = 0; k < n; k++) {
                    int kn = (k + 1) % n;
                    a += _vertices_x[k] * _vertices_y[kn] - _vertices_x[kn] * _vertices_y[k];
                }
                area_sign = (a >= 0) ? 1.0 : -1.0; // +1 = CCW, -1 = CW
            }

            for (int i = 0; i < n; i++) {
                int prev = (i > 0) ? i - 1 : (is_closed ? n - 1 : -1);
                int next = (i < n - 1) ? i + 1 : (is_closed ? 0 : -1);
                if (prev < 0 || next < 0) continue;

                // Vectores desde el vértice hacia sus vecinos
                double segment_a_x = _vertices_x[prev] - _vertices_x[i];
                double segment_a_y = _vertices_y[prev] - _vertices_y[i];
                double segment_b_x = _vertices_x[next] - _vertices_x[i];
                double segment_b_y = _vertices_y[next] - _vertices_y[i];
                double magnitude_a = Math.sqrt(segment_a_x*segment_a_x + segment_a_y*segment_a_y);
                double magnitude_b = Math.sqrt(segment_b_x*segment_b_x + segment_b_y*segment_b_y);
                if (magnitude_a < 1.0 || magnitude_b < 1.0) continue;

                // Ángulo entre los dos segmentos adyacentes (0–180°)
                double cos_a = (segment_a_x*segment_b_x + segment_a_y*segment_b_y)
                               / (magnitude_a * magnitude_b);
                double angle_deg = Math.acos(cos_a.clamp(-1.0, 1.0)) * 180.0 / Math.PI;
                if (angle_deg < 1.0) continue;

                // Bisectriz = suma de los vectores unitarios
                double unit_x = segment_a_x/magnitude_a + segment_b_x/magnitude_b;
                double unit_y = segment_a_y/magnitude_a + segment_b_y/magnitude_b;
                double ulen = Math.sqrt(unit_x*unit_x + unit_y*unit_y);

                if (ulen < 0.01) {
                    // Ángulo de 180°: la bisectriz es degenerada, usar perpendicular
                    unit_x = -segment_a_y / magnitude_a;
                    unit_y =  segment_a_x / magnitude_a;
                    ulen = 1.0;
                } else {
                    unit_x /= ulen;  unit_y /= ulen;
                }

                // Para polígonos cerrados: asegurarse de que apunta al interior
                if (is_closed && area_sign != 0.0) {
                    // Producto vectorial entrante × saliente para detectar vértice reflex
                    double px = _vertices_x[i] - _vertices_x[prev];
                    double py = _vertices_y[i] - _vertices_y[prev];
                    double qx = _vertices_x[next] - _vertices_x[i];
                    double qy = _vertices_y[next] - _vertices_y[i];
                    double cross = px * qy - py * qx;
                    bool convex = (area_sign * cross) > 0;
                    if (!convex) {
                        unit_x = -unit_x; unit_y = -unit_y;
                    }
                }

                // ── Arco indicador del ángulo ─────────────────────────────
                double arc_radius = 10.0;
                double angle_a    = Math.atan2(segment_a_y, segment_a_x); // dirección hacia prev
                double angle_b    = Math.atan2(segment_b_y, segment_b_x); // dirección hacia next
                double angle_bisector = Math.atan2(unit_y, unit_x);       // bisectriz (interior)

                // Normalizar angle_b y angle_bisector en [angle_a, angle_a + 2π)
                // para decidir si barrer CCW o CW
                double normalized_a = angle_a;
                double normalized_b = angle_b;
                while (normalized_b < normalized_a) normalized_b += 2.0 * Math.PI;
                double normalized_m = angle_bisector;
                while (normalized_m < normalized_a) normalized_m += 2.0 * Math.PI;

                cr.save();
                cr.set_line_width(1.0);
                ColorTheme.instance.active.angle_arc.apply(cr);

                cr.new_sub_path();  // evitar que Cairo conecte el punto actual con el arco
                if (normalized_m <= normalized_b) {
                    cr.arc(_vertices_x[i], _vertices_y[i], arc_radius, angle_a, angle_b);
                } else {
                    cr.arc_negative(_vertices_x[i], _vertices_y[i], arc_radius, angle_a, angle_b);
                }
                cr.stroke();
                cr.restore();

                // ── Etiqueta con el valor ──────────────────────────────────
                paint_label(cr, "%.1f°".printf(angle_deg),
                    _vertices_x[i] + unit_x * 20.0,
                    _vertices_y[i] + unit_y * 20.0,
                    0.0);
            }
        }

        /**
         * Cotas arquitectónicas en el EXTERIOR de cada segmento:
         *   – Líneas de extensión desde los extremos del segmento hacia afuera
         *   – Línea de cota paralela al segmento (a OFF1 px de la pared)
         *   – Flechas rellenas en ambos extremos de la cota
         *   – Etiqueta de medida (a OFF1+OFF2 px de la pared)
         */
        private void paint_segment_labels(Cairo.Context cr)
        {
            int n    = _vertices_x.length;
            int segment_count = is_closed ? n : n - 1;

            // Signo del área para saber qué lado es el exterior del polígono
            double area_sign = 1.0;
            if (is_closed && n >= 3) {
                double a = 0.0;
                for (int k = 0; k < n; k++) {
                    int kn = (k + 1) % n;
                    a += _vertices_x[k] * _vertices_y[kn] - _vertices_x[kn] * _vertices_y[k];
                }
                area_sign = (a >= 0) ? 1.0 : -1.0;
            }

            // Constantes de la cota
            const double OFF1    = 10.0; // pared → línea de cota (px)
            const double OFF2    =  12.0; // línea de cota → centro del label (px)
            const double EXT     =  3.0; // extensión de las líneas de extensión más allá de la cota
            const double ARR_LEN =  5.0; // longitud de la cabeza de flecha
            const double ARR_W   =  2.5; // semiancho de la cabeza de flecha

            for (int i = 0; i < segment_count; i++) {
                int to    = (i < n - 1) ? i + 1 : 0;
                double x1    = _vertices_x[i], y1 = _vertices_y[i];
                double x2    = _vertices_x[to], y2 = _vertices_y[to];
                double dx    = x2 - x1, dy = y2 - y1;
                double chord = Math.sqrt(dx*dx + dy*dy);
                if (chord < 30.0) continue;

                // Vector unitario a lo largo del segmento y perpendicular exterior
                double unit_x = dx / chord, unit_y = dy / chord;
                double normal_x = area_sign * unit_y, normal_y = -area_sign * unit_x;

                // Extremos de la línea de cota
                double dim_line_start_x = x1 + normal_x*OFF1, dim_line_start_y = y1 + normal_y*OFF1;
                double dim_line_end_x   = x2 + normal_x*OFF1, dim_line_end_y   = y2 + normal_y*OFF1;

                // Posición del label (centro de la cota desplazado hacia afuera)
                double label_x = (dim_line_start_x+dim_line_end_x)/2.0 + normal_x*OFF2;
                double label_y = (dim_line_start_y+dim_line_end_y)/2.0 + normal_y*OFF2;

                cr.save();
                cr.set_line_width(0.7);
                ColorTheme.instance.active.dimension_line.apply(cr);

                // ── Líneas de extensión ───────────────────────────────────
                cr.new_sub_path();
                cr.move_to(x1, y1);
                cr.line_to(x1 + normal_x*(OFF1+EXT), y1 + normal_y*(OFF1+EXT));
                cr.move_to(x2, y2);
                cr.line_to(x2 + normal_x*(OFF1+EXT), y2 + normal_y*(OFF1+EXT));
                cr.stroke();

                // ── Línea de cota ─────────────────────────────────────────
                cr.move_to(dim_line_start_x, dim_line_start_y);
                cr.line_to(dim_line_end_x, dim_line_end_y);
                cr.stroke();

                // ── Flecha en dim_line_start, apunta hacia dim_line_end (+unit) ──
                cr.move_to(dim_line_start_x, dim_line_start_y);
                cr.line_to(dim_line_start_x - ARR_LEN*unit_x - ARR_W*unit_y,
                    dim_line_start_y - ARR_LEN*unit_y + ARR_W*unit_x);
                cr.line_to(dim_line_start_x - ARR_LEN*unit_x + ARR_W*unit_y,
                    dim_line_start_y - ARR_LEN*unit_y - ARR_W*unit_x);
                cr.close_path(); cr.fill();

                // ── Flecha en dim_line_end, apunta hacia dim_line_start (-unit) ──
                cr.move_to(dim_line_end_x, dim_line_end_y);
                cr.line_to(dim_line_end_x + ARR_LEN*unit_x - ARR_W*unit_y,
                    dim_line_end_y + ARR_LEN*unit_y + ARR_W*unit_x);
                cr.line_to(dim_line_end_x + ARR_LEN*unit_x + ARR_W*unit_y,
                    dim_line_end_y + ARR_LEN*unit_y - ARR_W*unit_x);
                cr.close_path(); cr.fill();

                cr.restore();

                // ── Etiqueta ──────────────────────────────────────────────
                paint_label(cr,
                    format_m(DrawingMath.convert_pixels_to_meters(seg_arc_length(i, to))),
                    label_x, label_y, Math.atan2(dy, dx));
            }

            // Previsualización: etiqueta simple sin cota completa
            if (is_drawing && n >= 1) {
                double pdx   = _cursor_x - _vertices_x[n-1];
                double pdy   = _cursor_y - _vertices_y[n-1];
                double plen  = Math.sqrt(pdx*pdx + pdy*pdy);
                if (plen >= 30.0) {
                    double pangle = Math.atan2(pdy, pdx);
                    double perpendicular_angle  = pangle - Math.PI / 2.0;
                    paint_label(cr, format_m(DrawingMath.convert_pixels_to_meters(plen)),
                        (_vertices_x[n-1]+_cursor_x)/2.0 + Math.cos(perpendicular_angle)*14.0,
                        (_vertices_y[n-1]+_cursor_y)/2.0 + Math.sin(perpendicular_angle)*14.0,
                        pangle);
                }
            }
        }
    }
}
