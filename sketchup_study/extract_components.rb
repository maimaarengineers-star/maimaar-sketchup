# extract_components.rb — pull REAL component geometry (connection plates, clips, bolts,
# a sample tapered frame member, a Z purlin) out of existing Maimaar models and save each
# as its own .skp into components_lib/. The generator then PLACES these real parts so new
# models are built from Maimaar's actual geometry (mirror), not approximations.
#
# RUN (auto via bootstrap): MAIMAAR_EXTRACT_LIST = ['E:/.../a.skp', ...]; load this file.

require 'json'

module MaimaarExtract
  OUT = 'D:/maimaar-os/sketchup_study/components_lib'

  def self.mm(l); l.to_mm.round(1); end

  def self.classify(a, b, c)   # a<=b<=c (sorted dims, mm)
    return 'bolt'    if a < 30 && b < 60 && c < 140
    return 'clip'    if a <= 14 && b <= 320 && c <= 450
    return 'plate'   if a <= 32 && b <= 1300 && c <= 2600
    return 'frame_I' if a >= 150 && a <= 520 && b >= 300 && b <= 1500 && c > 3000
    return 'purlinZ' if b >= 140 && b <= 320 && a >= 40 && a <= 170 && c > 3000
    nil
  end

  def self.run(path)
    Sketchup.open_file(path)
    m = Sketchup.active_model
    Dir.mkdir(OUT) unless Dir.exist?(OUT)
    tag = File.basename(path, '.skp').gsub(/[^\w\-]/, '_')
    per_class = Hash.new(0)
    manifest = File.exist?(File.join(OUT, 'manifest.json')) ?
               JSON.parse(File.read(File.join(OUT, 'manifest.json'))) : []
    cand = []
    m.definitions.each do |d|
      next if d.image? || d.bounds.empty?
      bb = d.bounds
      dims = [mm(bb.width), mm(bb.height), mm(bb.depth)].sort
      cls = classify(dims[0], dims[1], dims[2])
      next unless cls
      cand << { d: d, cls: cls, dims: dims, inst: d.count_used_instances }
    end
    # keep the most-used few per class (real, representative parts)
    cand.sort_by! { |h| -h[:inst] }
    cand.each do |h|
      lim = { 'bolt' => 3, 'clip' => 6, 'plate' => 8, 'frame_I' => 3, 'purlinZ' => 3 }[h[:cls]]
      next if per_class[h[:cls]] >= lim
      per_class[h[:cls]] += 1
      nm = "#{h[:cls]}__#{h[:dims][0].round}x#{h[:dims][1].round}x#{h[:dims][2].round}__#{tag}_#{per_class[h[:cls]]}.skp"
      file = File.join(OUT, nm)
      begin
        h[:d].save_as(file)
        manifest << { cls: h[:cls], dims: h[:dims], inst: h[:inst], file: nm, src: tag }
      rescue => e
        manifest << { cls: h[:cls], error: e.message, src: tag }
      end
    end
    File.write(File.join(OUT, 'manifest.json'), JSON.pretty_generate(manifest))
  end
end

if defined?(Sketchup) && defined?(MAIMAAR_EXTRACT_LIST)
  log = File.join(MaimaarExtract::OUT, 'extract.log')
  Dir.mkdir(MaimaarExtract::OUT) unless Dir.exist?(MaimaarExtract::OUT)
  MAIMAAR_EXTRACT_LIST.each_with_index do |p, i|
    begin
      MaimaarExtract.run(p)
      File.open(log, 'a') { |f| f.puts("#{i + 1} OK #{p}") }
    rescue => e
      File.open(log, 'a') { |f| f.puts("#{i + 1} ERR #{p}: #{e.message}") }
    end
  end
  File.open(log, 'a') { |f| f.puts("DONE #{Time.now}") }
end
