# build_skp.rb — turn skp_build.json (from skp_build.py) into a real .skp model + snaps.
#
# Reads the neutral build spec (metres; x=length, y=width, z=up), creates Maimaar's
# canonical tags + colours, builds frame members as solids and sheeting as faces, sets
# up the standard scenes, exports snapshot PNGs, and saves the .skp. The draughtsman
# then opens it and fine-tunes (member profiles, openings, finishes).
#
# RUN inside SketchUp 2021 (Window > Ruby Console):
#   MAIMAAR_SPEC = 'D:/maimaar-os/sketchup_generator/skp_build.json'
#   load 'D:/maimaar-os/sketchup_generator/build_skp.rb'
# Output: <spec_dir>/out/<proposalNo>.skp and <proposalNo>_<scene>.png

require 'json'

module MaimaarSkpBuild
  M = 1.0  # spec is in metres; we convert each coord with .m below

  def self.p(x, y, z)
    Geom::Point3d.new(x.m, y.m, z.m)
  end

  def self.material(model, name, rgb, alpha = 1.0)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
    m.alpha = alpha
    m
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # orthonormal frame for an arbitrary axis a->b
  def self.basis(a, b)
    dir = (b - a); dir.normalize!
    up = dir.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
    right = dir.cross(up); right.normalize!
    up2 = right.cross(dir); up2.normalize!
    [dir, right, up2]
  end

  # solid (possibly TAPERED) prism along a->b. Section at a = wA x hA, at b = wB x hB,
  # measured along the right (width) and up2 (depth) vectors. Lofts the two end rects.
  def self.box(ents, a, b, wA, hA, wB, hB, mat, layer)
    _, r, u = basis(a, b)
    corner = lambda do |end_pt, w, h, sr, su|
      Geom::Point3d.new(end_pt.x + sr * r.x * (w / 2.0).m + su * u.x * (h / 2.0).m,
                        end_pt.y + sr * r.y * (w / 2.0).m + su * u.y * (h / 2.0).m,
                        end_pt.z + sr * r.z * (w / 2.0).m + su * u.z * (h / 2.0).m)
    end
    a00 = corner.call(a, wA, hA, -1, -1); a10 = corner.call(a, wA, hA, 1, -1)
    a11 = corner.call(a, wA, hA, 1, 1);   a01 = corner.call(a, wA, hA, -1, 1)
    b00 = corner.call(b, wB, hB, -1, -1); b10 = corner.call(b, wB, hB, 1, -1)
    b11 = corner.call(b, wB, hB, 1, 1);   b01 = corner.call(b, wB, hB, -1, 1)
    grp = ents.add_group
    g = grp.entities
    quads = [[a00, a10, a11, a01], [b00, b01, b11, b10],
             [a00, b00, b10, a10], [a10, b10, b11, a11],
             [a11, b11, b01, a01], [a01, b01, b00, a00]]
    quads.each { |q| f = g.add_face(q); f.material = mat if f }
    grp.layer = layer
    grp.material = mat
    grp
  end

  # build each face inside its OWN group so coplanar cladding faces that share edges
  # don't merge/cancel (loose coplanar faces were disappearing); also keeps tags clean.
  def self.offset_pt(pt, r, u, dr, du)
    Geom::Point3d.new(pt.x + r.x * dr.m + u.x * du.m,
                      pt.y + r.y * dr.m + u.y * du.m,
                      pt.z + r.z * dr.m + u.z * du.m)
  end

  # built-up I-section: tapered web (depth dA->dB) + constant top/bottom flanges.
  def self.imember(ents, a, b, dA, dB, bf, tf, tw, mat, layer)
    _, r, u = basis(a, b)
    g = ents.add_group; e = g.entities
    box(e, a, b, tw, dA, tw, dB, mat, layer)                                    # web
    at = offset_pt(a, r, u, 0, dA / 2.0 - tf / 2.0); bt = offset_pt(b, r, u, 0, dB / 2.0 - tf / 2.0)
    box(e, at, bt, bf, tf, bf, tf, mat, layer)                                  # top flange
    ab = offset_pt(a, r, u, 0, -(dA / 2.0 - tf / 2.0)); bb = offset_pt(b, r, u, 0, -(dB / 2.0 - tf / 2.0))
    box(e, ab, bb, bf, tf, bf, tf, mat, layer)                                  # bottom flange
    g.layer = layer; g.material = mat
    g
  end

  # cold-formed Z-section: web + top flange (+r side) + bottom flange (-r side).
  def self.zmember(ents, a, b, d, bz, t, mat, layer)
    _, r, u = basis(a, b)
    g = ents.add_group; e = g.entities
    box(e, a, b, t, d, t, d, mat, layer)                                        # web
    at = offset_pt(a, r, u, bz / 2.0, d / 2.0 - t / 2.0); bt = offset_pt(b, r, u, bz / 2.0, d / 2.0 - t / 2.0)
    box(e, at, bt, bz, t, bz, t, mat, layer)                                    # top flange (+r)
    ab = offset_pt(a, r, u, -bz / 2.0, -(d / 2.0 - t / 2.0)); bb = offset_pt(b, r, u, -bz / 2.0, -(d / 2.0 - t / 2.0))
    box(e, ab, bb, bz, t, bz, t, mat, layer)                                    # bottom flange (-r)
    g.layer = layer; g.material = mat
    g
  end

  def self.face(ents, poly, mat, layer)
    pts = poly.map { |c| p(c[0], c[1], c[2]) }
    grp = ents.add_group
    f = grp.entities.add_face(pts)
    unless f
      grp.erase!
      return nil
    end
    f.material = mat
    f.back_material = mat
    grp.layer = layer
    grp.material = mat
    grp
  end

  # flat steel plate: build the face in its own group, then extrude by `thick` metres.
  def self.plate(ents, poly, thick, mat, layer)
    pts = poly.map { |c| p(c[0], c[1], c[2]) }
    grp = ents.add_group
    f = grp.entities.add_face(pts)
    unless f
      grp.erase!
      return nil
    end
    f.pushpull(thick.m, false)
    grp.entities.grep(Sketchup::Face).each { |ff| ff.material = mat; ff.back_material = mat }
    grp.layer = layer
    grp.material = mat
    grp
  end

  # bolted end-plate: a w x d plate centred at c, normal = axis, extruded by `thick`.
  def self.endplate(ents, c, axis, w, d, thick, mat, layer)
    dir = Geom::Vector3d.new(axis[0], axis[1], axis[2]); dir.normalize!
    up = dir.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
    r = dir.cross(up); r.normalize!
    u = r.cross(dir); u.normalize!
    cc = Geom::Point3d.new(c[0].m - dir.x * (thick / 2.0).m,
                           c[1].m - dir.y * (thick / 2.0).m,
                           c[2].m - dir.z * (thick / 2.0).m)
    corner = lambda do |sr, su|
      Geom::Point3d.new(cc.x + sr * r.x * (w / 2.0).m + su * u.x * (d / 2.0).m,
                        cc.y + sr * r.y * (w / 2.0).m + su * u.y * (d / 2.0).m,
                        cc.z + sr * r.z * (w / 2.0).m + su * u.z * (d / 2.0).m)
    end
    grp = ents.add_group
    f = grp.entities.add_face([corner.call(-1, -1), corner.call(1, -1), corner.call(1, 1), corner.call(-1, 1)])
    unless f
      grp.erase!; return nil
    end
    f.pushpull(thick.m, false)
    grp.entities.grep(Sketchup::Face).each { |ff| ff.material = mat; ff.back_material = mat }
    grp.layer = layer; grp.material = mat
    grp
  end

  # camera direction unit vectors per scene name (looking AT the model)
  DIRS = {
    'ISO-FL' => [-1, -1, -0.6], 'ISO-FR' => [1, -1, -0.6],
    'ISO-BL' => [-1, 1, -0.6],  'ISO-BR' => [1, 1, -0.6],
    'FRONT'  => [0, -1, 0],     'BACK'   => [0, 1, 0],
    'SIDE'   => [-1, 0, 0],     'TOP'    => [0, 0, -1]
  }

  def self.add_scenes(model, scene_names, bbox, detail = nil)
    view = model.active_view
    cx = bbox[0] / 2.0; cy = bbox[1] / 2.0; cz = bbox[2] / 2.0
    target = p(cx, cy, cz)
    diag = Math.sqrt(bbox[0]**2 + bbox[1]**2 + bbox[2]**2)
    dist = (diag * 1.8)
    pages = []
    scene_names.each do |name|
      if name == 'KNEE-DETAIL' && detail
        # close-up on a knee connection so plates/clips/bolts read clearly
        tgt = p(detail[0], detail[1], detail[2])
        eye = Geom::Point3d.new((detail[0] - 4.0).m, (detail[1] - 5.0).m, (detail[2] + 2.0).m)
        view.camera = Sketchup::Camera.new(eye, tgt, Z_AXIS)
      else
        d = DIRS[name] || [-1, -1, -0.6]
        eye = Geom::Point3d.new((cx - d[0] * dist).m, (cy - d[1] * dist).m, (cz - d[2] * dist).m)
        up = name == 'TOP' ? Y_AXIS : Z_AXIS
        view.camera = Sketchup::Camera.new(eye, target, up)
        view.zoom_extents
        view.zoom(0.85)   # small margin around the model
      end
      pages << model.pages.add(name)
    end
    pages
  end

  def self.export_snaps(model, pages, out_dir, base, w = 1600, h = 1000)
    view = model.active_view
    paths = []
    pages.each do |pg|
      model.pages.selected_page = pg
      view.camera = pg.camera
      f = File.join(out_dir, "#{base}_#{pg.name}.png")
      view.write_image(f, w, h, true)
      paths << f
    end
    paths
  end

  def self.run(spec_path = nil)
    spec_path ||= (defined?(MAIMAAR_SPEC) ? MAIMAAR_SPEC :
                   File.join(File.dirname(__FILE__), 'skp_build.json'))
    spec = JSON.parse(File.read(spec_path))
    out_dir = File.join(File.dirname(spec_path), 'out')
    Dir.mkdir(out_dir) unless Dir.exist?(out_dir)

    model = Sketchup.active_model
    model.start_operation('Maimaar SKP build', true)

    # clean white background so cream cladding contrasts (sky/ground off, shadows on)
    ro = model.rendering_options
    ro['BackgroundColor'] = Sketchup::Color.new(255, 255, 255) rescue nil
    ro['DrawHorizon'] = false rescue nil
    ro['DisplayColorByLayer'] = false rescue nil
    model.shadow_info['DisplayShadows'] = true rescue nil

    # start from a clean slate (we may have opened a throwaway seed model)
    begin; model.entities.clear!; rescue; end

    mats = {}
    spec['tags'].each do |name, t|
      tag(model, name)
      mats[name] = material(model, name, t['rgb'], (t['alpha'] || 1.0))
    end
    default_mat = mats.values.first

    ents = model.entities
    spec['primitives'].each do |pr|
      layer = tag(model, pr['tag'])
      mat = mats[pr['tag']] || default_mat
      if pr['kind'] == 'member'
        case pr['profile']
        when 'I'
          imember(ents, p(*pr['a']), p(*pr['b']), pr['dA'], pr['dB'], pr['bf'], pr['tf'], pr['tw'], mat, layer)
        when 'Z'
          zmember(ents, p(*pr['a']), p(*pr['b']), pr['d'], pr['bz'], pr['t'], mat, layer)
        else
          box(ents, p(*pr['a']), p(*pr['b']), pr['wA'], pr['hA'], pr['wB'], pr['hB'], mat, layer)
        end
      elsif pr['kind'] == 'plate'
        plate(ents, pr['poly'], pr['thick'], mat, layer)
      elsif pr['kind'] == 'endplate'
        endplate(ents, pr['c'], pr['n'], pr['w'], pr['d'], pr['thick'], mat, layer)
      else
        face(ents, pr['poly'], mat, layer)
      end
    end

    model.commit_operation

    bbox = spec['meta']['bbox']
    pages = add_scenes(model, spec['scenes'], bbox, spec['meta']['detail_target'])

    base = (spec['meta']['proposalNo'] || 'model').gsub(/[^\w\-]/, '_')
    skp = File.join(out_dir, "#{base}.skp")
    model.save(skp)
    snaps = export_snaps(model, pages, out_dir, base)

    puts "saved #{skp}"
    puts "snaps:"; snaps.each { |s| puts "  #{s}" }
    skp
  end
end

MaimaarSkpBuild.run
