# export_geometry.rb — harvest the REAL geometry/parts from Maimaar SketchUp models, to
# build the section/connection database (the existing models are the ground truth: real
# tapered I-frames, Z girts/purlins, clips, connection plates, base plates).
#
# Per model it captures: overall size (W/L/H mm), tags, scenes, and the COMPONENT
# DEFINITIONS (name, instance count, bbox dims) + per-tag entity counts & extents. The
# definitions are effectively the parts library; their bbox dims give member sections.
#
# Output: D:/maimaar-os/sketchup_study/geom_out/<sanitized>.geom.json (central, since the
# proposal folders may be read-only).
#
# RUN (auto via bootstrap) or in the Ruby Console:
#   MAIMAAR_GEOM_LIST = ['E:/.../a.skp', 'E:/.../b.skp']
#   load 'D:/maimaar-os/sketchup_study/export_geometry.rb'

require 'json'

module MaimaarSkpExport
  OUT_DIR = 'D:/maimaar-os/sketchup_study/geom_out'

  def self.mm(len); (len.to_mm).round(1); end

  def self.bbox_dims(bb)
    return nil if bb.nil? || bb.empty?
    { w: mm(bb.width), d: mm(bb.height), h: mm(bb.depth) }   # SU: width=x, height=y, depth=z
  end

  def self.defn_catalogue(model)
    model.definitions.map do |d|
      next nil if d.image?
      dims = bbox_dims(d.bounds)
      sects = dims ? [dims[:w], dims[:d], dims[:h]].sort : nil   # smallest two ~ section
      { name: d.name, instances: d.count_used_instances, dims: dims,
        section: (sects ? sects[0..1] : nil), length: (sects ? sects[2] : nil) }
    end.compact.sort_by { |h| -h[:instances] }
  end

  def self.tag_summary(model)
    counts = Hash.new(0); boxes = {}
    model.entities.each do |e|
      t = (e.respond_to?(:layer) && e.layer) ? e.layer.name : 'Untagged'
      counts[t] += 1
      if e.respond_to?(:bounds) && !e.bounds.empty?
        boxes[t] ||= Geom::BoundingBox.new
        boxes[t].add(e.bounds)
      end
    end
    out = {}
    counts.each { |t, c| out[t] = { count: c, bbox: bbox_dims(boxes[t]) } }
    out
  end

  def self.export(model = Sketchup.active_model)
    data = {
      title: model.title, path: model.path,
      bbox: bbox_dims(model.bounds),
      units: model.options['UnitsOptions']['LengthUnit'],
      layers: model.layers.map(&:name),
      scenes: model.pages.map(&:name),
      tags: tag_summary(model),
      definitions: defn_catalogue(model),
    }
    Dir.mkdir(OUT_DIR) unless Dir.exist?(OUT_DIR)
    base = (model.path.empty? ? 'untitled' : File.basename(model.path, '.skp')).gsub(/[^\w\-]/, '_')
    # de-dup if two models share a basename
    out = File.join(OUT_DIR, base + '.geom.json'); i = 1
    while File.exist?(out); out = File.join(OUT_DIR, "#{base}_#{i}.geom.json"); i += 1; end
    File.write(out, JSON.pretty_generate(data))
    out
  end

  def self.export_paths(paths)
    log = File.join(OUT_DIR, 'batch.log')
    Dir.mkdir(OUT_DIR) unless Dir.exist?(OUT_DIR)
    paths.each_with_index do |p, i|
      begin
        Sketchup.open_file(p)
        o = export(Sketchup.active_model)
        File.open(log, 'a') { |f| f.puts("#{i + 1}/#{paths.size} OK  #{p} -> #{o}") }
      rescue => e
        File.open(log, 'a') { |f| f.puts("#{i + 1}/#{paths.size} ERR #{p}: #{e.message}") }
      end
    end
    File.open(log, 'a') { |f| f.puts("DONE #{Time.now}") }
  end
end

if defined?(Sketchup)
  if defined?(MAIMAAR_GEOM_LIST)
    MaimaarSkpExport.export_paths(MAIMAAR_GEOM_LIST)
  elsif Sketchup.active_model
    MaimaarSkpExport.export(Sketchup.active_model)
  end
end
