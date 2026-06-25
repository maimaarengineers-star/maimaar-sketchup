"""
generate_from_if.py — ONE COMMAND: Inquiry-Form canonical building model -> SketchUp .skp
+ 8 scene snapshot PNGs. This is the production entry point the web route shells out to.

Pipeline (Windows + SketchUp 2021):
  1. skp_build.build(model)  -> out/skp_build.json   (neutral 3D spec, from the IF)
  2. write a one-shot bootstrap into the SketchUp Plugins folder
  3. launch SketchUp 2021 on a throwaway seed (.skp) -> bootstrap auto-runs build_skp.rb
  4. poll out/ for <proposalNo>.skp + the 8 PNG snaps, return their paths

The IF web app produces the canonical building model via services/drawingData (the same
JSON the 2D drawing_generator consumes); pass that file here.

Usage:
  python generate_from_if.py <building_model.json> [--seed seed_template.skp]
                             [--sketchup "C:/Program Files/SketchUp/SketchUp 2021/SketchUp.exe"]
                             [--timeout 180]
"""
import os, sys, json, time, argparse, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skp_build  # noqa: E402

DEF_SKETCHUP = r"C:\Program Files\SketchUp\SketchUp 2021\SketchUp.exe"
DEF_PLUGINS = os.path.expandvars(r"%APPDATA%\SketchUp\SketchUp 2021\SketchUp\Plugins")
DEF_SEED = os.path.join(HERE, "seed_template.skp")
OUT = os.path.join(HERE, "out")

BOOTSTRAP = '''# AUTO-GENERATED one-shot. Runs the Maimaar SKP builder then self-deletes.
MAIMAAR_LOG = File.join(File.dirname(__FILE__), 'maimaar_oneshot.log')
File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}}  bootstrap loaded") }}
UI.start_timer(4, false) do
  begin
    load '{build_rb}'
    File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}}  build completed OK") }}
  rescue => e
    File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}}  ERROR #{{e.class}}: #{{e.message}}") }}
  ensure
    begin; File.delete(__FILE__); rescue; end
  end
end
'''


def sanitize(s):
    return "".join(c if (c.isalnum() or c in "-_") else "_" for c in str(s or "model"))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("model", help="IF canonical building model JSON")
    ap.add_argument("--seed", default=DEF_SEED)
    ap.add_argument("--sketchup", default=DEF_SKETCHUP)
    ap.add_argument("--plugins", default=DEF_PLUGINS)
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args(argv)

    model = json.load(open(args.model, encoding="utf-8"))
    base = sanitize(model.get("proposalNo"))
    os.makedirs(OUT, exist_ok=True)

    # 1. build the neutral spec where build_skp.rb expects it
    spec = skp_build.build(model)
    json.dump(spec, open(os.path.join(HERE, "skp_build.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    prim = len(spec["primitives"])

    # clear prior outputs for this proposal
    for ext in (".skp", ".skb"):
        p = os.path.join(OUT, base + ext)
        if os.path.exists(p):
            os.remove(p)
    for f in os.listdir(OUT):
        if f.startswith(base + "_") and f.endswith(".png"):
            os.remove(os.path.join(OUT, f))

    # 2. write the bootstrap
    if not os.path.isdir(args.plugins):
        sys.exit(f"SketchUp Plugins folder not found: {args.plugins}")
    build_rb = os.path.join(HERE, "build_skp.rb").replace("\\", "/")
    boot = os.path.join(args.plugins, "maimaar_oneshot.rb")
    log = os.path.join(args.plugins, "maimaar_oneshot.log")
    if os.path.exists(log):
        os.remove(log)
    open(boot, "w", encoding="utf-8").write(BOOTSTRAP.format(build_rb=build_rb))

    # 3. launch SketchUp on the seed (bypasses the Welcome dialog so plugins load)
    if not os.path.exists(args.sketchup):
        sys.exit(f"SketchUp not found: {args.sketchup}")
    if not os.path.exists(args.seed):
        sys.exit(f"Seed .skp not found: {args.seed}")
    subprocess.Popen([args.sketchup, args.seed])
    print(f"[generate_from_if] {base}: {prim} primitives; SketchUp launched, building...")

    # 4. poll: wait for the .skp, then for all scene snaps to finish writing
    skp = os.path.join(OUT, base + ".skp")
    want = len(spec.get("scenes", [])) or 8

    def snap_paths():
        return sorted(os.path.join(OUT, f) for f in os.listdir(OUT)
                      if f.startswith(base + "_") and f.endswith(".png"))
    t0 = time.time()
    while time.time() - t0 < args.timeout:
        if os.path.exists(skp) and os.path.getsize(skp) > 0 and len(snap_paths()) >= want:
            time.sleep(1)
            break
        time.sleep(3)
    snaps = snap_paths()
    if not os.path.exists(skp):
        sys.exit(f"[generate_from_if] TIMEOUT after {args.timeout}s — see {log}")
    print(f"[generate_from_if] DONE\n  model: {skp}\n  snaps: {len(snaps)}")
    for s in snaps:
        print("   ", s)
    print(json.dumps({"skp": skp, "snaps": snaps, "primitives": prim}))


if __name__ == "__main__":
    main()
