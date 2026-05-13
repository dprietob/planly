namespace Planly
{
    /**
     * Muro: polilínea/polígono con soporte para curvas de Bézier cúbicas.
     *
     * Modelo de handles Bézier
     * ────────────────────────
     * Cada vértice i tiene dos flags independientes:
     *   _bez_out[i]  → handle saliente: controla el segmento i → i+1
     *   _bez_in[i]   → handle entrante: controla el segmento i-1 → i
     *
     * Al borrar el vértice k sólo se limpia:
     *   _bez_out[prev]  (era para el tramo prev→k, que desaparece)
     *   _bez_in[next]   (era para el tramo k→next, que desaparece)
     * …sin tocar _bez_in[prev] ni _bez_out[next].
     */
    public class Wall : Shape
    {
        private const double SNAP_RADIUS  = 15.0;
        private const double HANDLE_RADIUS =  5.0;
        private const double BEZ_HANDLE_R  =  4.5;
        private const double WALL_LINE_W   =  3.0;
        private const double MIN_SEG_LEN   =  4.0;

        // ── Geometría ─────────────────────────────────────────────────────
        private double[] _vx = {};
        private double[] _vy = {};

        // ── Bézier ────────────────────────────────────────────────────────
        private bool[]   _bez_in  = {};   // handle entrante activo
        private bool[]   _bez_out = {};   // handle saliente activo
        private double[] _cp_ox   = {};   // control point saliente X
        private double[] _cp_oy   = {};   // control point saliente Y
        private double[] _cp_ix   = {};   // control point entrante X
        private double[] _cp_iy   = {};   // control point entrante Y

        // ── Previsualización ──────────────────────────────────────────────
        private double _cx = 0.0;
        private double _cy = 0.0;

        public bool is_drawing { get; private set; default = true; }
        public bool is_closed  { get; private set; default = false; }

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
            _vx = { x }; _vy = { y };
            _bez_in = { false }; _bez_out = { false };
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
            _vx += _cx; _vy += _cy;
            _bez_in += false; _bez_out += false;
            _cp_ox += 0.0; _cp_oy += 0.0;
            _cp_ix += 0.0; _cp_iy += 0.0;
            update_metrics ();
        }

        public void remove_last_vertex ()
        {
            int n = _vx.length;
            if (n <= 1) return;
            _vx = _vx[0 : n-1]; _vy = _vy[0 : n-1];
            _bez_in  = _bez_in[0 : n-1];  _bez_out = _bez_out[0 : n-1];
            _cp_ox = _cp_ox[0 : n-1]; _cp_oy = _cp_oy[0 : n-1];
            _cp_ix = _cp_ix[0 : n-1]; _cp_iy = _cp_iy[0 : n-1];
            update_metrics ();
        }

        public void close ()  { is_closed  = true;  is_drawing = false; update_metrics (); }
        public void finish () { is_drawing = false; update_metrics (); }

        public bool near_first_vertex (double x, double y)
        {
            if (_vx.length < 3) return false;
            double dx = x - _vx[0], dy = y - _vy[0];
            return (dx*dx + dy*dy) <= (SNAP_RADIUS * SNAP_RADIUS);
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
                _vx[i] = ox + (_vx[i]-ox)*sx; _vy[i] = oy + (_vy[i]-oy)*sy;
                _cp_ox[i] = ox + (_cp_ox[i]-ox)*sx; _cp_oy[i] = oy + (_cp_oy[i]-oy)*sy;
                _cp_ix[i] = ox + (_cp_ix[i]-ox)*sx; _cp_iy[i] = oy + (_cp_iy[i]-oy)*sy;
            }
            update_metrics ();
        }

        public void rotate_vertices (double angle, double cx, double cy)
        {
            double ca = Math.cos (angle), sa = Math.sin (angle);
            for (int i = 0; i < _vx.length; i++) {
                double dx = _vx[i]-cx, dy = _vy[i]-cy;
                _vx[i] = cx + dx*ca - dy*sa; _vy[i] = cy + dx*sa + dy*ca;
                double ox = _cp_ox[i]-cx, oy = _cp_oy[i]-cy;
                _cp_ox[i] = cx + ox*ca - oy*sa; _cp_oy[i] = cy + ox*sa + oy*ca;
                double ix = _cp_ix[i]-cx, iy = _cp_iy[i]-cy;
                _cp_ix[i] = cx + ix*ca - iy*sa; _cp_iy[i] = cy + ix*sa + iy*ca;
            }
            update_metrics ();
        }

        public void get_full_snapshot (out double[] vx,     out double[] vy,
                                       out bool[]   bez_in, out bool[]   bez_out,
                                       out double[] cox,    out double[] coy,
                                       out double[] cix,    out double[] ciy)
        {
            vx     = _vx[0 : _vx.length];     vy     = _vy[0 : _vy.length];
            bez_in = _bez_in[0 : _bez_in.length]; bez_out = _bez_out[0 : _bez_out.length];
            cox = _cp_ox[0 : _cp_ox.length];  coy = _cp_oy[0 : _cp_oy.length];
            cix = _cp_ix[0 : _cp_ix.length];  ciy = _cp_iy[0 : _cp_iy.length];
        }

        public void restore_full_snapshot (double[] vx,     double[] vy,
                                           bool[]   bez_in, bool[]   bez_out,
                                           double[] cox,    double[] coy,
                                           double[] cix,    double[] ciy)
        {
            _vx     = vx[0 : vx.length];       _vy     = vy[0 : vy.length];
            _bez_in = bez_in[0 : bez_in.length]; _bez_out = bez_out[0 : bez_out.length];
            _cp_ox = cox[0 : cox.length]; _cp_oy = coy[0 : coy.length];
            _cp_ix = cix[0 : cix.length]; _cp_iy = ciy[0 : ciy.length];
            update_metrics ();
        }

        // ── Edición de vértices ───────────────────────────────────────────

        /**
         * Elimina el vértice idx y mantiene la figura cerrada/abierta.
         * Sólo desactiva los handles que apuntaban a los segmentos adyacentes
         * al vértice eliminado; el resto de handles se conservan intactos.
         */
        public bool delete_vertex (int idx)
        {
            int n         = _vx.length;
            int min_verts = is_closed ? 3 : 2;
            if (n <= min_verts || idx < 0 || idx >= n) return false;

            int prev_b = is_closed ? (idx - 1 + n) % n : (idx > 0     ? idx - 1 : -1);
            int next_b = is_closed ? (idx + 1) % n      : (idx < n - 1 ? idx + 1 : -1);

            double[] nvx = {}, nvy = {};
            bool[]   nbi = {}, nbo = {};
            double[] ncox = {}, ncoy = {}, ncix = {}, nciy = {};
            for (int i = 0; i < n; i++) {
                if (i == idx) continue;
                nvx += _vx[i]; nvy += _vy[i];
                nbi += _bez_in[i]; nbo += _bez_out[i];
                ncox += _cp_ox[i]; ncoy += _cp_oy[i];
                ncix += _cp_ix[i]; nciy += _cp_iy[i];
            }
            _vx = nvx; _vy = nvy;
            _bez_in = nbi; _bez_out = nbo;
            _cp_ox = ncox; _cp_oy = ncoy;
            _cp_ix = ncix; _cp_iy = nciy;

            // Ajustar índices tras la eliminación
            int new_prev = (prev_b >= 0) ? (prev_b > idx ? prev_b - 1 : prev_b) : -1;
            int new_next = (next_b >= 0) ? (next_b > idx ? next_b - 1 : next_b) : -1;

            // Solo limpiar exactamente los handles que apuntaban al vértice borrado:
            //   - _bez_out[prev]: era el handle saliente de prev hacia idx
            //   - _bez_in[next]:  era el handle entrante de next desde idx
            // Los demás (_bez_in[prev], _bez_out[next]) se respetan.
            if (new_prev >= 0 && new_prev < _vx.length) _bez_out[new_prev] = false;
            if (new_next >= 0 && new_next < _vx.length) _bez_in[new_next]  = false;

            update_metrics ();
            return true;
        }

        public int find_segment_at (double x, double y, double tol,
                                    out double proj_x, out double proj_y)
        {
            proj_x = x; proj_y = y;
            int n = _vx.length, segs = is_closed ? n : n - 1;
            for (int i = 0; i < segs; i++) {
                double x1, y1, x2, y2;
                if (i < n-1) { x1=_vx[i]; y1=_vy[i]; x2=_vx[i+1]; y2=_vy[i+1]; }
                else          { x1=_vx[n-1]; y1=_vy[n-1]; x2=_vx[0]; y2=_vy[0]; }
                double dx=x2-x1, dy=y2-y1, len2=dx*dx+dy*dy;
                if (len2 < 1.0) continue;
                double t = ((x-x1)*dx+(y-y1)*dy)/len2;
                t = t.clamp (0.0, 1.0);
                double ex=x1+t*dx, ey=y1+t*dy;
                if (Math.sqrt ((x-ex)*(x-ex)+(y-ey)*(y-ey)) <= tol) {
                    proj_x=ex; proj_y=ey; return i;
                }
            }
            return -1;
        }

        public int insert_vertex (int seg_idx, double x, double y)
        {
            int insert_at = seg_idx + 1;
            double[] nvx={}, nvy={};
            bool[]   nbi={}, nbo={};
            double[] ncox={}, ncoy={}, ncix={}, nciy={};
            for (int i = 0; i < _vx.length; i++) {
                if (i == insert_at) {
                    nvx+=x; nvy+=y; nbi+=false; nbo+=false;
                    ncox+=0.0; ncoy+=0.0; ncix+=0.0; nciy+=0.0;
                }
                nvx+=_vx[i]; nvy+=_vy[i]; nbi+=_bez_in[i]; nbo+=_bez_out[i];
                ncox+=_cp_ox[i]; ncoy+=_cp_oy[i]; ncix+=_cp_ix[i]; nciy+=_cp_iy[i];
            }
            if (insert_at >= _vx.length) {
                nvx+=x; nvy+=y; nbi+=false; nbo+=false;
                ncox+=0.0; ncoy+=0.0; ncix+=0.0; nciy+=0.0;
            }
            _vx=nvx; _vy=nvy; _bez_in=nbi; _bez_out=nbo;
            _cp_ox=ncox; _cp_oy=ncoy; _cp_ix=ncix; _cp_iy=nciy;
            update_metrics ();
            return insert_at;
        }

        public int find_vertex (double x, double y)
        {
            double tol2 = HANDLE_RADIUS * HANDLE_RADIUS * 4.0;
            for (int i = 0; i < _vx.length; i++) {
                double dx=x-_vx[i], dy=y-_vy[i];
                if (dx*dx+dy*dy <= tol2) return i;
            }
            return -1;
        }

        public double get_vertex_x (int idx) { return (idx>=0 && idx<_vx.length) ? _vx[idx] : 0.0; }
        public double get_vertex_y (int idx) { return (idx>=0 && idx<_vy.length) ? _vy[idx] : 0.0; }

        public void move_vertex (int idx, double x, double y)
        {
            if (idx < 0 || idx >= _vx.length) return;
            double dx=x-_vx[idx], dy=y-_vy[idx];
            _vx[idx]=x; _vy[idx]=y;
            _cp_ox[idx]+=dx; _cp_oy[idx]+=dy;
            _cp_ix[idx]+=dx; _cp_iy[idx]+=dy;
            update_metrics ();
        }

        // ── API Bézier ────────────────────────────────────────────────────

        public void toggle_bezier (int idx)
        {
            if (idx < 0 || idx >= _vx.length) return;
            bool was = _bez_in[idx] || _bez_out[idx];
            if (was) {
                _bez_in[idx] = false; _bez_out[idx] = false;
            } else {
                _bez_in[idx] = true; _bez_out[idx] = true;
                int n    = _vx.length;
                int prev = is_closed ? (idx-1+n)%n : (idx>0     ? idx-1 : idx);
                int next = is_closed ? (idx+1)%n    : (idx<n-1   ? idx+1 : idx);
                double tx=0.0, ty=0.0;
                if (prev != idx) {
                    double pd=Math.sqrt((_vx[idx]-_vx[prev])*(_vx[idx]-_vx[prev]) + (_vy[idx]-_vy[prev])*(_vy[idx]-_vy[prev]));
                    if (pd>0) { tx+=(_vx[idx]-_vx[prev])/pd; ty+=(_vy[idx]-_vy[prev])/pd; }
                }
                if (next != idx) {
                    double nd=Math.sqrt((_vx[next]-_vx[idx])*(_vx[next]-_vx[idx]) + (_vy[next]-_vy[idx])*(_vy[next]-_vy[idx]));
                    if (nd>0) { tx+=(_vx[next]-_vx[idx])/nd; ty+=(_vy[next]-_vy[idx])/nd; }
                }
                double tl=Math.sqrt(tx*tx+ty*ty);
                if (tl>0) { tx/=tl; ty/=tl; } else { tx=1.0; ty=0.0; }
                double total=0.0; int cnt=0;
                if (prev!=idx) { double d=Math.sqrt((_vx[idx]-_vx[prev])*(_vx[idx]-_vx[prev])+(_vy[idx]-_vy[prev])*(_vy[idx]-_vy[prev])); total+=d; cnt++; }
                if (next!=idx) { double d=Math.sqrt((_vx[next]-_vx[idx])*(_vx[next]-_vx[idx])+(_vy[next]-_vy[idx])*(_vy[next]-_vy[idx])); total+=d; cnt++; }
                double len=(cnt>0) ? (total/cnt)/3.0 : 40.0;
                _cp_ox[idx]=_vx[idx]+tx*len; _cp_oy[idx]=_vy[idx]+ty*len;
                _cp_ix[idx]=_vx[idx]-tx*len; _cp_iy[idx]=_vy[idx]-ty*len;
            }
            update_metrics ();
        }

        public int find_bezier_handle (double x, double y, out bool is_out)
        {
            is_out = false;
            double tol2 = BEZ_HANDLE_R * BEZ_HANDLE_R * 4.0;
            for (int i = 0; i < _vx.length; i++) {
                if (_bez_out[i]) {
                    double dox=x-_cp_ox[i], doy=y-_cp_oy[i];
                    if (dox*dox+doy*doy<=tol2) { is_out=true;  return i; }
                }
                if (_bez_in[i]) {
                    double dix=x-_cp_ix[i], diy=y-_cp_iy[i];
                    if (dix*dix+diy*diy<=tol2) { is_out=false; return i; }
                }
            }
            return -1;
        }

        public void move_bezier_cp (int idx, bool is_out, double x, double y)
        {
            if (idx < 0 || idx >= _vx.length) return;
            double vx=_vx[idx], vy=_vy[idx];
            if (is_out) {
                _cp_ox[idx]=x; _cp_oy[idx]=y;
                _cp_ix[idx]=2*vx-x; _cp_iy[idx]=2*vy-y;
            } else {
                _cp_ix[idx]=x; _cp_iy[idx]=y;
                _cp_ox[idx]=2*vx-x; _cp_oy[idx]=2*vy-y;
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
            double min_x=_vx[0], max_x=_vx[0], min_y=_vy[0], max_y=_vy[0];
            for (int i = 1; i < n; i++) {
                if (_vx[i]<min_x) min_x=_vx[i]; if (_vx[i]>max_x) max_x=_vx[i];
                if (_vy[i]<min_y) min_y=_vy[i]; if (_vy[i]>max_y) max_y=_vy[i];
            }
            return { min_x, min_y, max_x-min_x, max_y-min_y };
        }

        // ── Cálculos internos ─────────────────────────────────────────────

        private void flatten_point (double mx, double my, double ox, double oy,
                                    out double rx, out double ry)
        {
            double dx=mx-ox, dy=my-oy, len=Math.sqrt(dx*dx+dy*dy);
            if (len<1.0) { rx=ox; ry=oy; return; }
            double deg=Math.atan2(dy,dx)*180.0/Math.PI;
            if (deg<0) deg+=360.0;
            double snap;
            if      (deg>=23  && deg<68)  snap=45.0;
            else if (deg>=68  && deg<113) snap=90.0;
            else if (deg>=113 && deg<158) snap=135.0;
            else if (deg>=158 && deg<203) snap=180.0;
            else if (deg>=203 && deg<248) snap=225.0;
            else if (deg>=248 && deg<293) snap=270.0;
            else if (deg>=293 && deg<338) snap=315.0;
            else                          snap=0.0;
            double rad=snap*Math.PI/180.0;
            rx=ox+len*Math.cos(rad); ry=oy+len*Math.sin(rad);
        }

        private void update_metrics ()
        {
            int n = _vx.length;
            _len_px = 0.0;
            for (int i = 0; i < n-1; i++) _len_px += seg_arc_length (i, i+1);
            if (is_closed && n >= 2)       _len_px += seg_arc_length (n-1, 0);
            _len_m = Utils.convert_to_metters (_len_px);
            if (is_closed && n >= 3) {
                double area = 0.0;
                for (int i = 0; i < n; i++) area += seg_area_term (i, (i+1)%n);
                double scale = (double) MEASURE_IN_PIXELS;
                _area_m2 = Math.fabs (area) / (2.0 * scale * scale);
            } else {
                _area_m2 = 0.0;
            }
        }

        private double seg_arc_length (int from, int to)
        {
            if (!_bez_out[from] && !_bez_in[to]) {
                double dx=_vx[to]-_vx[from], dy=_vy[to]-_vy[from];
                return Math.sqrt (dx*dx+dy*dy);
            }
            return bez_arc_length (
                _vx[from], _vy[from],
                _bez_out[from] ? _cp_ox[from] : _vx[from],
                _bez_out[from] ? _cp_oy[from] : _vy[from],
                _bez_in[to]    ? _cp_ix[to]   : _vx[to],
                _bez_in[to]    ? _cp_iy[to]   : _vy[to],
                _vx[to], _vy[to]);
        }

        private double bez_arc_length (double p0x, double p0y,
                                       double p1x, double p1y,
                                       double p2x, double p2y,
                                       double p3x, double p3y)
        {
            const int N = 20;
            double len=0.0, px=p0x, py=p0y;
            for (int i = 1; i <= N; i++) {
                double t=(double)i/N, mt=1.0-t;
                double bx=mt*mt*mt*p0x+3*mt*mt*t*p1x+3*mt*t*t*p2x+t*t*t*p3x;
                double by=mt*mt*mt*p0y+3*mt*mt*t*p1y+3*mt*t*t*p2y+t*t*t*p3y;
                double dx=bx-px, dy=by-py;
                len+=Math.sqrt(dx*dx+dy*dy);
                px=bx; py=by;
            }
            return len;
        }

        private double seg_area_term (int from, int to)
        {
            if (!_bez_out[from] && !_bez_in[to]) {
                return _vx[from]*_vy[to] - _vx[to]*_vy[from];
            }
            double p0x=_vx[from], p0y=_vy[from], p3x=_vx[to], p3y=_vy[to];
            double p1x=_bez_out[from] ? _cp_ox[from] : p0x;
            double p1y=_bez_out[from] ? _cp_oy[from] : p0y;
            double p2x=_bez_in[to]    ? _cp_ix[to]   : p3x;
            double p2y=_bez_in[to]    ? _cp_iy[to]   : p3y;
            const int N=20;
            double term=0.0, px=p0x, py=p0y;
            for (int i = 1; i <= N; i++) {
                double t=(double)i/N, mt=1.0-t;
                double bx=mt*mt*mt*p0x+3*mt*mt*t*p1x+3*mt*t*t*p2x+t*t*t*p3x;
                double by=mt*mt*mt*p0y+3*mt*mt*t*p1y+3*mt*t*t*p2y+t*t*t*p3y;
                term+=px*by-bx*py; px=bx; py=by;
            }
            return term;
        }

        // ── Drawable: hit-testing ─────────────────────────────────────────

        public override bool contains_point (double x, double y)
        {
            double tol=8.0; int n=_vx.length;
            for (int i=0; i<n-1; i++)
                if (near_segment(x,y,_vx[i],_vy[i],_vx[i+1],_vy[i+1],tol)) return true;
            if (is_closed && n>=2) {
                if (near_segment(x,y,_vx[n-1],_vy[n-1],_vx[0],_vy[0],tol)) return true;
                if (point_in_polygon(x,y)) return true;
            }
            return false;
        }

        private bool point_in_polygon (double x, double y)
        {
            int n=_vx.length; bool inside=false; int j=n-1;
            for (int i=0; i<n; i++) {
                double xi=_vx[i], yi=_vy[i], xj=_vx[j], yj=_vy[j];
                if (((yi>y)!=(yj>y)) && (x<(xj-xi)*(y-yi)/(yj-yi)+xi)) inside=!inside;
                j=i;
            }
            return inside;
        }

        private bool near_segment (double px, double py,
                                   double x1, double y1,
                                   double x2, double y2, double tol)
        {
            double dx=x2-x1, dy=y2-y1, len2=dx*dx+dy*dy;
            if (len2<1.0) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))<=tol;
            double t=((px-x1)*dx+(py-y1)*dy)/len2;
            t=t.clamp(0.0,1.0);
            double ex=x1+t*dx, ey=y1+t*dy;
            return Math.sqrt((px-ex)*(px-ex)+(py-ey)*(py-ey))<=tol;
        }

        public override void on_mouse_pressed  (double x, double y) {}
        public override void on_mouse_dragged  (double x, double y) {}
        public override void on_mouse_released (double x, double y) {}

        public override bool is_valid () { return _vx.length >= 2; }

        // ── Métricas ──────────────────────────────────────────────────────

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
            if (is_closed && _area_m2>0) return "%.3f m²".printf (_area_m2);
            return "";
        }

        // ── Renderizado ───────────────────────────────────────────────────

        public override void paint (Cairo.Context cr)
        {
            int n = _vx.length;
            if (n == 0) return;
            cr.save ();
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);

            if (is_closed && n >= 3) {
                cr.move_to (_vx[0], _vy[0]);
                for (int i=0; i<n-1; i++) paint_seg(cr,i,i+1);
                paint_seg(cr,n-1,0);
                cr.set_source_rgba(fill_r,fill_g,fill_b,fill_a);
                cr.fill();
            }

            cr.set_line_width (WALL_LINE_W);
            cr.set_source_rgba(_is_selected?0.8:stroke_r, _is_selected?0.1:stroke_g,
                               _is_selected?0.1:stroke_b, 1.0);
            if (n >= 2) {
                cr.move_to(_vx[0],_vy[0]);
                for (int i=0; i<n-1; i++) paint_seg(cr,i,i+1);
                if (is_closed) paint_seg(cr,n-1,0);
                cr.stroke();
            }

            if (is_drawing) {
                cr.save();
                double[] dash={6.0,4.0};
                cr.set_dash(dash,0.0);
                cr.set_source_rgba(stroke_r,stroke_g,stroke_b,stroke_a*0.6);
                cr.move_to(_vx[n-1],_vy[n-1]); cr.line_to(_cx,_cy);
                cr.stroke(); cr.restore();
            }

            if (is_drawing || (_is_selected && vertex_handles_visible)) {
                cr.set_line_width(1.5);
                cr.set_source_rgba(0.1,0.3,0.9,1.0);
                for (int i=0; i<n; i++) {
                    if (i == selected_vertex) {
                        cr.set_source_rgba(0.1,0.3,0.9,1.0);
                        cr.arc(_vx[i],_vy[i],HANDLE_RADIUS+1.5,0,2.0*Math.PI);
                        cr.fill();
                    } else {
                        paint_handle(cr,_vx[i],_vy[i]);
                    }
                }
                if (is_drawing && n>=3 && near_first_vertex(_cx,_cy)) {
                    cr.set_source_rgba(0.2,0.78,0.2,0.9);
                    cr.arc(_vx[0],_vy[0],HANDLE_RADIUS*2.0,0,2.0*Math.PI);
                    cr.fill();
                }
                if (!is_drawing) paint_bezier_handles(cr);
            }

            paint_segment_labels(cr);
            if (is_closed && _area_m2>0.0) {
                double cx=0.0, cy=0.0;
                for (int i=0; i<n; i++) { cx+=_vx[i]; cy+=_vy[i]; }
                paint_label(cr,"%.2f m²".printf(_area_m2),cx/n,cy/n);
            }
            cr.restore();
        }

        private void paint_seg (Cairo.Context cr, int from, int to)
        {
            if (_bez_out[from] || _bez_in[to]) {
                double cp1x=_bez_out[from]?_cp_ox[from]:_vx[from];
                double cp1y=_bez_out[from]?_cp_oy[from]:_vy[from];
                double cp2x=_bez_in[to]   ?_cp_ix[to]  :_vx[to];
                double cp2y=_bez_in[to]   ?_cp_iy[to]  :_vy[to];
                cr.curve_to(cp1x,cp1y,cp2x,cp2y,_vx[to],_vy[to]);
            } else {
                cr.line_to(_vx[to],_vy[to]);
            }
        }

        private void paint_bezier_handles (Cairo.Context cr)
        {
            for (int i=0; i<_vx.length; i++) {
                if (!_bez_in[i] && !_bez_out[i]) continue;
                cr.save();
                cr.set_line_width(0.8);
                cr.set_source_rgba(0.4,0.4,0.4,0.7);
                if (_bez_out[i]) {
                    cr.move_to(_vx[i],_vy[i]); cr.line_to(_cp_ox[i],_cp_oy[i]);
                }
                if (_bez_in[i]) {
                    cr.move_to(_vx[i],_vy[i]); cr.line_to(_cp_ix[i],_cp_iy[i]);
                }
                cr.stroke();
                if (_bez_out[i]) paint_bez_dot(cr,_cp_ox[i],_cp_oy[i]);
                if (_bez_in[i])  paint_bez_dot(cr,_cp_ix[i],_cp_iy[i]);
                cr.restore();
            }
        }

        private void paint_bez_dot (Cairo.Context cr, double x, double y)
        {
            cr.set_line_width(1.2);
            cr.set_source_rgba(1.0,1.0,1.0,1.0);
            cr.arc(x,y,BEZ_HANDLE_R,0,2.0*Math.PI); cr.fill();
            cr.set_source_rgba(0.15,0.4,0.9,1.0);
            cr.arc(x,y,BEZ_HANDLE_R,0,2.0*Math.PI); cr.stroke();
        }

        private void paint_segment_labels (Cairo.Context cr)
        {
            int n=_vx.length, segs=is_closed?n:n-1;
            for (int i=0; i<segs; i++) {
                int to=(i<n-1)?i+1:0;
                double x1=_vx[i],y1=_vy[i],x2=_vx[to],y2=_vy[to];
                double dx=x2-x1, dy=y2-y1;
                if (Math.sqrt(dx*dx+dy*dy)<30.0) continue;
                double arc=seg_arc_length(i,to);
                double mx=(x1+x2)/2.0, my=(y1+y2)/2.0;
                double perp=Math.atan2(dy,dx)-Math.PI/2.0;
                paint_label(cr,format_m(Utils.convert_to_metters(arc)),
                            mx+Math.cos(perp)*14.0,my+Math.sin(perp)*14.0);
            }
            if (is_drawing && n>=1) {
                double dx=_cx-_vx[n-1], dy=_cy-_vy[n-1];
                double len=Math.sqrt(dx*dx+dy*dy);
                if (len>=30.0) {
                    double mx=(_vx[n-1]+_cx)/2.0, my=(_vy[n-1]+_cy)/2.0;
                    double perp=Math.atan2(dy,dx)-Math.PI/2.0;
                    paint_label(cr,format_m(Utils.convert_to_metters(len)),
                                mx+Math.cos(perp)*14.0,my+Math.sin(perp)*14.0);
                }
            }
        }
    }
}
