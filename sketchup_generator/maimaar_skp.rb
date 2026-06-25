# ============================================================================
# maimaar_skp.rb  —  DYNAMIC SketchUp generator (pure Ruby, no Python).
#
# Generates a real Maimaar PEB .skp + 8 scene snaps DIRECTLY from an Inquiry-Form
# canonical building-model JSON, inside the SketchUp Ruby Console.
#
# USE (Window > Ruby Console):
#   MAIMAAR_MODEL = 'D:/maimaar-os/sketchup_generator/samples/sample_model.json'
#   load 'D:/maimaar-os/sketchup_generator/maimaar_skp.rb'
# -> builds the model, exports out/<proposalNo>.skp + 8 PNG snaps.
#
# Rules baked in (from 271 models + 133 approval drawings — see sketchup_study):
#   RED tapered built-up I frame; 200Z purlins/girts that bypass on galv. clips;
#   real end-plate/clip components; M20/M24 bolts; cable X-bracing in braced bays;
#   eave struts, flange braces, sag rods, edge trims; Type-R ribbed translucent
#   sheeting; masonry base band; doors/windows/skylights; multi-building/area.
# ============================================================================
require 'json'

module MaimaarSKP
  HERE = File.dirname(__FILE__)
  PARTS = File.join(HERE, 'parts')

  # --- canonical tags: [r,g,b,alpha] -------------------------------------------------
  TAGS = {
    'MS-FRAME'        => [206, 32, 32, 1.0],   'PLATE' => [120, 124, 130, 1.0],
    'CLIP'            => [150, 156, 164, 1.0],  'PURLIN' => [178, 184, 190, 1.0],  # galvanised silver
    'SHEETING'        => [214, 219, 225, 0.50], 'ROOF-SHEET' => [212, 217, 223, 1.0],  # opaque light metal roof
    'SKYLIGHT'        => [225, 238, 248, 0.22], 'GUTTER-DOWNPIPE' => [150, 156, 162, 1.0],
    'BRACE-CABLE'     => [60, 63, 70, 1.0],     'TRIM' => [180, 186, 192, 1.0],
    'SHEET-RIB'       => [150, 158, 166, 1.0],  'BOLT' => [40, 42, 46, 1.0],
    'WINDOW'          => [150, 190, 215, 0.45], 'DOOR' => [70, 72, 78, 1.0],
    'BRICK-MASONRY'   => [150, 95, 62, 1.0],
  }
  # sections (m)
  IFW = 0.225; IFT = 0.016; IWT = 0.008          # built-up I flange w / flange t / web t
  ZD = 0.20; ZF = 0.06; ZT = 0.020               # 200Z: depth / flange / thk
  SAG = 0.012; PSP = 1.5; GOFF = 0.12; BGAP = 12.0
  WALLS = %w[NSW FSW LEW REW]

  def self.num(v, d = 0.0); Float(v) rescue d.to_f; end
  def self.pt(x, y, z); Geom::Point3d.new(x.m, y.m, z.m); end

  # ---- materials / tags -------------------------------------------------------------
  def self.setup(model)
    @mat = {}
    TAGS.each do |name, c|
      model.layers[name] || model.layers.add(name)
      m = model.materials[name] || model.materials.add(name)
      m.color = Sketchup::Color.new(c[0], c[1], c[2]); m.alpha = c[3]
      @mat[name] = m
    end
    ro = model.rendering_options
    ro['BackgroundColor'] = Sketchup::Color.new(255, 255, 255) rescue nil
    ro['DrawHorizon'] = false rescue nil
    ro['EdgeColorMode'] = 1 rescue nil          # colour edges BY LAYER (rib lines grey, not harsh black)
    ro['DisplayColorByLayer'] = true rescue nil
    model.shadow_info['DisplayShadows'] = true rescue nil
  end

  def self.lay(model, tag); model.layers[tag] || model.layers.add(tag); end

  # ---- geometry helpers -------------------------------------------------------------
  def self.basis(a, b)
    d = (b - a); d = Z_AXIS.clone if d.length == 0; d.normalize!
    up = d.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
    r = d.cross(up); r.normalize!; u = r.cross(d); u.normalize!; [d, r, u]
  end

  def self.safe_face(e, pts)
    begin; f = e.add_face(pts); return f if f; rescue; end
    first = nil
    (1..pts.length - 2).each { |i| begin; ff = e.add_face([pts[0], pts[i], pts[i + 1]]); first ||= ff; rescue; end }
    first
  end

  def self.off(p, r, u, dr, du)
    Geom::Point3d.new(p.x + r.x * dr.m + u.x * du.m, p.y + r.y * dr.m + u.y * du.m, p.z + r.z * dr.m + u.z * du.m)
  end

  # tapered box a->b, section wA x hA -> wB x hB
  def self.box(ents, a, b, wa, ha, wb, hb, tag)
    _, r, u = basis(a, b)
    c = lambda do |e, w, h, sr, su|
      Geom::Point3d.new(e.x + sr * r.x * (w / 2.0).m + su * u.x * (h / 2.0).m,
                        e.y + sr * r.y * (w / 2.0).m + su * u.y * (h / 2.0).m,
                        e.z + sr * r.z * (w / 2.0).m + su * u.z * (h / 2.0).m)
    end
    g = ents.add_group; ge = g.entities
    a00 = c.call(a, wa, ha, -1, -1); a10 = c.call(a, wa, ha, 1, -1); a11 = c.call(a, wa, ha, 1, 1); a01 = c.call(a, wa, ha, -1, 1)
    b00 = c.call(b, wb, hb, -1, -1); b10 = c.call(b, wb, hb, 1, -1); b11 = c.call(b, wb, hb, 1, 1); b01 = c.call(b, wb, hb, -1, 1)
    [[a00, a10, a11, a01], [b00, b01, b11, b10], [a00, b00, b10, a10],
     [a10, b10, b11, a11], [a11, b11, b01, a01], [a01, b01, b00, a00]].each { |q| safe_face(ge, q) }
    g.layer = lay(@model, tag); g.material = @mat[tag]; g
  end

  def self.seg(ents, a, b, w, h, tag); box(ents, a, b, w, h, w, h, tag); end

  # built-up I (tapered web dA->dB, constant flanges)
  def self.imember(ents, a, b, da, db, tag)
    _, r, u = basis(a, b)
    g = ents.add_group; e = g.entities
    box(e, a, b, IWT, da, IWT, db, tag)
    box(e, off(a, r, u, 0, da / 2.0 - IFT / 2.0), off(b, r, u, 0, db / 2.0 - IFT / 2.0), IFW, IFT, IFW, IFT, tag)
    box(e, off(a, r, u, 0, -(da / 2.0 - IFT / 2.0)), off(b, r, u, 0, -(db / 2.0 - IFT / 2.0)), IFW, IFT, IFW, IFT, tag)
    g.layer = lay(@model, tag); g
  end

  # Z section (web + 2 opposite flanges)
  def self.zmember(ents, a, b, tag)
    _, r, u = basis(a, b)
    g = ents.add_group; e = g.entities
    box(e, a, b, ZT, ZD, ZT, ZD, tag)
    box(e, off(a, r, u, ZF / 2.0, ZD / 2.0 - ZT / 2.0), off(b, r, u, ZF / 2.0, ZD / 2.0 - ZT / 2.0), ZF, ZT, ZF, ZT, tag)
    box(e, off(a, r, u, -ZF / 2.0, -(ZD / 2.0 - ZT / 2.0)), off(b, r, u, -ZF / 2.0, -(ZD / 2.0 - ZT / 2.0)), ZF, ZT, ZF, ZT, tag)
    g.layer = lay(@model, tag); g
  end

  def self.plate(ents, poly, thick, tag)
    g = ents.add_group; f = safe_face(g.entities, poly.map { |c| pt(*c) })
    return (g.erase! rescue nil) if f.nil?
    (f.pushpull(thick.m, false) rescue nil)
    g.entities.grep(Sketchup::Face).each { |ff| ff.material = @mat[tag]; ff.back_material = @mat[tag] }
    g.layer = lay(@model, tag); g.material = @mat[tag]; g
  end

  def self.endplate(ents, c, axis, w, d, thick, tag)
    dir = Geom::Vector3d.new(*axis); dir = Z_AXIS.clone if dir.length == 0; dir.normalize!
    up = dir.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
    r = dir.cross(up); r.normalize!; u = r.cross(dir); u.normalize!
    cc = Geom::Point3d.new(c[0].m - dir.x * (thick / 2.0).m, c[1].m - dir.y * (thick / 2.0).m, c[2].m - dir.z * (thick / 2.0).m)
    cor = lambda { |sr, su| Geom::Point3d.new(cc.x + sr * r.x * (w / 2.0).m + su * u.x * (d / 2.0).m, cc.y + sr * r.y * (w / 2.0).m + su * u.y * (d / 2.0).m, cc.z + sr * r.z * (w / 2.0).m + su * u.z * (d / 2.0).m) }
    g = ents.add_group; f = safe_face(g.entities, [cor.call(-1, -1), cor.call(1, -1), cor.call(1, 1), cor.call(-1, 1)])
    return (g.erase! rescue nil) if f.nil?
    (f.pushpull(thick.m, false) rescue nil)
    g.entities.grep(Sketchup::Face).each { |ff| ff.material = @mat[tag]; ff.back_material = @mat[tag] }
    g.layer = lay(@model, tag); g
  end

  def self.load_comp(comp)
    @cc ||= {}
    return @cc[comp] if @cc.key?(comp)
    p = File.join(PARTS, "#{comp}.skp")
    @cc[comp] = (File.exist?(p) ? (@model.definitions.load(p) rescue nil) : nil)
  end

  def self.realcomp(comp, at, rot, tag)
    d = load_comp(comp); return nil unless d
    c = d.bounds.center
    t = Geom::Transformation.translation(Geom::Vector3d.new(at[0].m, at[1].m, at[2].m)) *
        Geom::Transformation.rotation(ORIGIN, Z_AXIS, rot.degrees) *
        Geom::Transformation.translation(Geom::Point3d.new(0, 0, 0) - c)
    inst = @model.entities.add_instance(d, t); inst.layer = lay(@model, tag); inst
  end

  def self.face(ents, poly, tag)
    g = ents.add_group; pts = poly.map { |c| pt(*c) }
    f = safe_face(g.entities, pts)
    return (g.erase! rescue nil) if f.nil?
    g.entities.grep(Sketchup::Face).each { |ff| ff.material = @mat[tag]; ff.back_material = @mat[tag] }
    g.layer = lay(@model, tag); g.material = @mat[tag]; g
  end

  def self.lines(ents, segs, tag)
    g = ents.add_group
    segs.each { |s| begin; g.entities.add_line(pt(*s[0]), pt(*s[1])); rescue; end }
    g.layer = lay(@model, tag); g
  end

  # ---- one area -----------------------------------------------------------------
  def self.build_area(area, ox, oy)
    ents = @model.entities
    r = area['resolved']; m = r['metrics']
    w = num(m['width']); l = num(m['length']); eave = num(m['eaveHeight'])
    peak = num(r['roof']['peakHeight'] || m['peakHeight'] || eave)
    ridge = num((r['roof']['ridgePos'] rescue nil) || w / 2.0)
    xs = ((r['grids']['length'] rescue []) || []).map { |g| num(g['pos']) }
    xs = [0.0, l] if xs.empty?
    db = 0.35; da = 0.35; dk = [1.6, [0.45, w * 0.040].max].min
    zat = lambda { |y| (ridge <= 0 || ridge >= w) ? eave : eave + (peak - eave) * (y <= ridge ? y / ridge : (w - y) / (w - ridge)) }
    draf = lambda { |y| f = (ridge <= 0 || ridge >= w) ? 0.0 : (y <= ridge ? y / ridge : (w - y) / (w - ridge)); f = [[f, 0.0].max, 1.0].min; dk + (da - dk) * f }
    gap = 0.015
    pz = lambda { |y| zat.call(y) + draf.call(y) / 2.0 + ZD / 2.0 + gap }
    rtop = lambda { |y| pz.call(y) + ZD / 2.0 + gap }
    x0 = xs.first + ox; xl = xs.last + ox

    # frames + connections
    xs.each do |x0g|
      x = x0g + ox
      imember(ents, pt(x, oy + 0, 0), pt(x, oy + 0, eave), db, dk, 'MS-FRAME')
      imember(ents, pt(x, oy + w, 0), pt(x, oy + w, eave), db, dk, 'MS-FRAME')
      apex = [x, oy + ridge, peak]
      imember(ents, pt(x, oy + 0, eave), pt(*apex), dk, da, 'MS-FRAME')
      imember(ents, pt(*apex), pt(x, oy + w, eave), da, dk, 'MS-FRAME')
      # base plates (320x490x22) + M24 anchors
      [0.0, w].each do |yc|
        plate(ents, [[x - 0.16, oy + yc - 0.245, 0], [x + 0.16, oy + yc - 0.245, 0], [x + 0.16, oy + yc + 0.245, 0], [x - 0.16, oy + yc + 0.245, 0]], 0.022, 'PLATE')
        [[-0.10, -0.16], [0.10, -0.16], [-0.10, 0.16], [0.10, 0.16]].each { |dx, dy| seg(ents, pt(x + dx, oy + yc + dy, 0), pt(x + dx, oy + yc + dy, 0.08), 0.040, 0.040, 'BOLT') }
      end
      # knee: real end-plate + gusset + M20 bolts; ridge end-plate
      un = lambda { |a, b| v = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]; n = Math.sqrt(v.reduce(0) { |s, c| s + c * c }); n = 1.0 if n == 0; v.map { |c| c / n } }
      fw2 = IFW / 2.0 + 0.012
      [[0.0, 1.0], [w, -1.0]].each do |wy, inn|
        corner = [x, oy + wy, eave]; ax = un.call(corner, apex)
        # CONNECTION PLATE at the knee: clear projecting bolted end-plate (always visible)...
        endplate(ents, [corner[0] + ax[0] * 0.04, corner[1] + ax[1] * 0.04, corner[2] + ax[2] * 0.04], ax, IFW + 0.14, dk + 0.14, 0.022, 'PLATE')
        # ...+ the REAL extracted end-plate component (bolt holes) + haunch gusset
        realcomp('endplate', [corner[0], corner[1], corner[2] - dk * 0.35], 0.0, 'PLATE')
        gl = dk * 1.1
        [-fw2, fw2].each { |sx| plate(ents, [[x + sx, oy + wy, eave], [x + sx, oy + wy, eave - gl], [x + sx, oy + wy + inn * gl, eave]], 0.012, 'PLATE') }
        [0.20, 0.42, 0.64, 0.86].each { |t| seg(ents, pt(x - 0.17, oy + wy, eave - dk * t), pt(x + 0.17, oy + wy, eave - dk * t), 0.034, 0.034, 'BOLT') }
      end
      # RIDGE connection plate: clear projecting end-plate + real component + bolts
      axr = un.call([x, oy + 0, eave], apex)
      endplate(ents, [apex[0] - axr[0] * 0.04, apex[1] - axr[1] * 0.04, apex[2] - axr[2] * 0.04], axr, IFW + 0.14, da + 0.14, 0.022, 'PLATE')
      realcomp('endplate', [x, oy + ridge, peak - da * 0.35], 0.0, 'PLATE')
      [0.25, 0.55, 0.85].each { |t| seg(ents, pt(x - 0.17, oy + ridge, peak - da * t), pt(x + 0.17, oy + ridge, peak - da * t), 0.034, 0.034, 'BOLT') }
    end

    # purlins (bypass) + clips
    ys = []
    [[0.0, ridge], [w, ridge]].each do |s, e|
      y = s; step = e > s ? PSP : -PSP
      while (step > 0 ? y < e : y > e); ys << y; y += step; end
      ys << e
    end
    ys.uniq.each do |y|
      z = pz.call(y); zmember(ents, pt(x0, oy + y, z), pt(xl, oy + y, z), 'PURLIN')
      zc = zat.call(y) + draf.call(y) / 2.0
      xs.each { |xg| realcomp('clip', [xg + ox, oy + y, (zc + z) / 2.0], 0.0, 'CLIP') }
    end
    # girts (bypass) + clips
    [[0.0, -1.0], [w, 1.0]].each do |wy, sgn|
      gy = wy + sgn * GOFF; gz = PSP
      while gz < eave
        zmember(ents, pt(x0, oy + gy, gz), pt(xl, oy + gy, gz), 'PURLIN')
        xs.each { |xg| realcomp('clip_small', [xg + ox, oy + (wy + gy) / 2.0, gz], 90.0, 'CLIP') }
        gz += PSP
      end
    end
    # eave struts
    [0.0, w].each { |wy| zmember(ents, pt(x0, oy + wy, eave - 0.02), pt(xl, oy + wy, eave - 0.02), 'PURLIN') }

    # cable X-bracing in braced bays
    xsb = xs.map { |g| g + ox }
    ((r['bracing'] || {})['braced'] || []).each do |b|
      i = (b['bayIndex'] || -1).to_i
      next if i < 0 || i + 1 >= xsb.length
      xa = xsb[i]; xb = xsb[i + 1]
      [0.0, w].each do |wy|
        seg(ents, pt(xa, oy + wy, 0.2), pt(xb, oy + wy, eave - 0.2), SAG, SAG, 'BRACE-CABLE')
        seg(ents, pt(xb, oy + wy, 0.2), pt(xa, oy + wy, eave - 0.2), SAG, SAG, 'BRACE-CABLE')
      end
      seg(ents, pt(xa, oy + 0, eave), pt(xb, oy + ridge, peak), SAG, SAG, 'BRACE-CABLE')
      seg(ents, pt(xb, oy + 0, eave), pt(xa, oy + ridge, peak), SAG, SAG, 'BRACE-CABLE')
      seg(ents, pt(xa, oy + w, eave), pt(xb, oy + ridge, peak), SAG, SAG, 'BRACE-CABLE')
      seg(ents, pt(xb, oy + w, eave), pt(xa, oy + ridge, peak), SAG, SAG, 'BRACE-CABLE')
    end

    # edge trims (eave / gable rake / corners)
    [0.0, w].each { |wy| seg(ents, pt(x0, oy + wy, eave + 0.05), pt(xl, oy + wy, eave + 0.05), 0.08, 0.08, 'TRIM') }
    [x0, xl].each do |xe|
      seg(ents, pt(xe, oy + 0, eave), pt(xe, oy + ridge, peak), 0.08, 0.08, 'TRIM')
      seg(ents, pt(xe, oy + ridge, peak), pt(xe, oy + w, eave), 0.08, 0.08, 'TRIM')
      [0.0, w].each { |wy| seg(ents, pt(xe, oy + wy, 0), pt(xe, oy + wy, eave), 0.08, 0.08, 'TRIM') }
    end

    # cladding (+ masonry band) + roof
    bwh = num((r['finish'] || {})['blockWallHeight']); bwh = (bwh > 0.1 ? [bwh, eave - 0.3].min : 0.0)
    face(ents, [[x0, oy + 0, rtop.call(0)], [xl, oy + 0, rtop.call(0)], [xl, oy + ridge, rtop.call(ridge)], [x0, oy + ridge, rtop.call(ridge)]], 'ROOF-SHEET')
    face(ents, [[x0, oy + ridge, rtop.call(ridge)], [xl, oy + ridge, rtop.call(ridge)], [xl, oy + w, rtop.call(w)], [x0, oy + w, rtop.call(w)]], 'ROOF-SHEET')
    [[0.0, 'NSW'], [w, 'FSW']].each do |wy, nm|
      face(ents, [[x0, oy + wy, 0], [xl, oy + wy, 0], [xl, oy + wy, bwh], [x0, oy + wy, bwh]], 'BRICK-MASONRY') if bwh > 0
      face(ents, [[x0, oy + wy, bwh], [xl, oy + wy, bwh], [xl, oy + wy, eave], [x0, oy + wy, eave]], 'SHEETING')
    end
    [x0, xl].each do |xe|
      face(ents, [[xe, oy + 0, 0], [xe, oy + w, 0], [xe, oy + w, bwh], [xe, oy + 0, bwh]], 'BRICK-MASONRY') if bwh > 0
      face(ents, [[xe, oy + 0, bwh], [xe, oy + w, bwh], [xe, oy + w, eave], [xe, oy + ridge, peak], [xe, oy + 0, eave]], 'SHEETING')
    end

    # Type-R rib lines (coarser pitch so they read as ribs, not a black mass)
    rib = 0.60; rs = []; xr = x0 + rib
    while xr < xl
      rs << [[xr, oy + 0, rtop.call(0) + 0.01], [xr, oy + ridge, rtop.call(ridge) + 0.01]]
      rs << [[xr, oy + ridge, rtop.call(ridge) + 0.01], [xr, oy + w, rtop.call(w) + 0.01]]
      xr += rib
    end
    lines(ents, rs, 'SHEET-RIB') unless rs.empty?
    ws = []; xr = x0 + rib
    while xr < xl
      ws << [[xr, oy - 0.01, bwh], [xr, oy - 0.01, eave]]; ws << [[xr, oy + w + 0.01, bwh], [xr, oy + w + 0.01, eave]]; xr += rib
    end
    yr = rib
    while yr < w
      ws << [[x0 - 0.01, oy + yr, bwh], [x0 - 0.01, oy + yr, eave]]; ws << [[xl + 0.01, oy + yr, bwh], [xl + 0.01, oy + yr, eave]]; yr += rib
    end
    lines(ents, ws, 'SHEET-RIB') unless ws.empty?

    # eave gutters + downpipes
    [[0.0, -1.0], [w, 1.0]].each { |wy, sgn| seg(ents, pt(x0, oy + wy + sgn * 0.10, eave + 0.02), pt(xl, oy + wy + sgn * 0.10, eave + 0.02), 0.18, 0.12, 'GUTTER-DOWNPIPE') }
    [x0, xl].each { |cx| [[0.0, -1.0], [w, 1.0]].each { |wy, sgn| seg(ents, pt(cx, oy + wy + sgn * 0.16, 0), pt(cx, oy + wy + sgn * 0.16, eave), 0.10, 0.10, 'GUTTER-DOWNPIPE') } }

    # openings: doors / windows from placements (distributed)
    gmapL = {}; ((r['grids']['length'] rescue []) || []).each { |g| gmapL[g['id'].to_s] = num(g['pos']) }
    surf = { 'NSW' => [l, 0.0, -1], 'FSW' => [l, w, 1], 'LEW' => [w, 0.0, -1], 'REW' => [w, l, 1] }
    (area['placements'] || []).each_with_index do |pp, idx|
      s = pp['surface'].to_s.upcase; next unless surf.key?(s)
      ww = num(pp['width']) / 1000.0; hh = num(pp['height']) / 1000.0; sill = num(pp['sill']) / 1000.0
      next if ww <= 0 || hh <= 0
      span = surf[s][0]; tag = (pp['type'].to_s =~ /door|shutter|roller/i ? 'DOOR' : 'WINDOW')
      qty = [1, pp['qty'].to_i].max
      qty.times do |k|
        a = span * (idx + k + 1) / (qty + 4.0) - ww / 2.0; a = [[a, 0.15].max, span - ww - 0.15].min
        z1 = [sill + hh, eave - 0.1].min
        poly = case s
               when 'NSW' then [[x0 + a, oy - 0.06, sill], [x0 + a + ww, oy - 0.06, sill], [x0 + a + ww, oy - 0.06, z1], [x0 + a, oy - 0.06, z1]]
               when 'FSW' then [[x0 + a, oy + w + 0.06, sill], [x0 + a + ww, oy + w + 0.06, sill], [x0 + a + ww, oy + w + 0.06, z1], [x0 + a, oy + w + 0.06, z1]]
               when 'LEW' then [[x0 - 0.06, oy + a, sill], [x0 - 0.06, oy + a + ww, sill], [x0 - 0.06, oy + a + ww, z1], [x0 - 0.06, oy + a, z1]]
               else [[xl + 0.06, oy + a, sill], [xl + 0.06, oy + a + ww, sill], [xl + 0.06, oy + a + ww, z1], [xl + 0.06, oy + a, z1]]
               end
        face(ents, poly, tag)
      end
    end
    [l, w, eave, peak]
  end

  # ---- scenes + export --------------------------------------------------------------
  DIRS = { 'ISO-FL' => [-1, -1, -0.6], 'ISO-FR' => [1, -1, -0.6], 'ISO-BL' => [-1, 1, -0.6], 'ISO-BR' => [1, 1, -0.6],
           'FRONT' => [0, -1, 0], 'SIDE' => [-1, 0, 0], 'TOP' => [0, 0, -1] }
  SCENES = %w[ISO-FL ISO-FR ISO-BL ISO-BR FRONT SIDE TOP KNEE-DETAIL BASE-DETAIL]

  def self.scenes(bbox, knee, base)
    v = @model.active_view
    cx = bbox[0] / 2.0; cy = bbox[1] / 2.0; cz = bbox[2] / 2.0; tgt = pt(cx, cy, cz)
    dist = Math.sqrt(bbox[0]**2 + bbox[1]**2 + bbox[2]**2) * 1.8
    pages = []
    SCENES.each do |nm|
      if nm == 'KNEE-DETAIL' && knee
        v.camera = Sketchup::Camera.new(Geom::Point3d.new((knee[0] - 4).m, (knee[1] - 5).m, (knee[2] + 2).m), pt(*knee), Z_AXIS)
      elsif nm == 'BASE-DETAIL' && base
        v.camera = Sketchup::Camera.new(Geom::Point3d.new((base[0] - 2.5).m, (base[1] - 3.0).m, (base[2] + 1.6).m), pt(base[0], base[1], base[2] + 0.4), Z_AXIS)
      else
        d = DIRS[nm] || [-1, -1, -0.6]
        v.camera = Sketchup::Camera.new(Geom::Point3d.new((cx - d[0] * dist).m, (cy - d[1] * dist).m, (cz - d[2] * dist).m), tgt, nm == 'TOP' ? Y_AXIS : Z_AXIS)
        v.zoom_extents; v.zoom(0.85)
      end
      pages << @model.pages.add(nm)
    end
    pages
  end

  # ---- main -------------------------------------------------------------------------
  def self.generate(model_path = nil)
    model_path ||= (defined?(MAIMAAR_MODEL) ? MAIMAAR_MODEL : File.join(HERE, 'samples', 'sample_model.json'))
    model = JSON.parse(File.read(model_path))
    @model = Sketchup.active_model
    out = File.join(HERE, 'out'); Dir.mkdir(out) unless Dir.exist?(out)
    @model.start_operation('Maimaar PEB', true)
    @model.entities.clear! rescue nil
    setup(@model)
    bb = [0.0, 0.0, 0.0]; site_y = 0.0; knee = nil
    model['buildings'].each do |b|
      layout = {}; ((b['layout'] || {})['areas'] || []).each { |la| layout[la['na']] = la }
      bw = num((b['layout'] || {})['totalWidth']); base = site_y; maxw = 0.0
      b['areas'].each do |area|
        la = layout[area['areaNo']] || {}
        ox = num(la['x']); oy = base + num(la['y'])
        dims = build_area(area, ox, oy)
        bb[0] = [bb[0], ox + dims[0]].max; bb[1] = [bb[1], oy + dims[1]].max; bb[2] = [bb[2], dims[3]].max
        maxw = [maxw, num(la['y']) + dims[1]].max
        knee ||= [ox + ((area['resolved']['grids']['length'][1]['pos'].to_f rescue 1.0)), oy, num(area['resolved']['metrics']['eaveHeight'])]
      end
      site_y += [bw, maxw].max + BGAP
    end
    @model.commit_operation
    base = knee ? [knee[0], knee[1], 0.0] : nil
    pages = scenes(bb, knee, base)
    base = (model['proposalNo'] || 'model').to_s.gsub(/[^\w\-]/, '_')
    skp = File.join(out, "#{base}.skp"); @model.save(skp)
    v = @model.active_view
    pages.each { |pg| @model.pages.selected_page = pg; v.camera = pg.camera; v.write_image(File.join(out, "#{base}_#{pg.name}.png"), 1600, 1000, true) }
    puts "[MaimaarSKP] saved #{skp} + #{pages.length} snaps"
    skp
  end
end

MaimaarSKP.generate
