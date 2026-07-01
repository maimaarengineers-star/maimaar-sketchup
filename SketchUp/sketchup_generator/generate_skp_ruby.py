"""
generate_skp_ruby.py — trigger the PURE-RUBY generator (maimaar_skp.rb) on an IF model
and return the .skp + 9 snaps. This is what the Draftsman portal's /model.skp route calls.

Pipeline: write a one-shot bootstrap that sets MAIMAAR_MODEL and loads maimaar_skp.rb ->
launch SketchUp 2021 on the seed -> poll out/ for <proposalNo>.skp + the 9 PNG snaps.

Usage:
  python generate_skp_ruby.py <building_model.json> [--timeout 220]
Prints a JSON line: {"skp": "...", "snaps": [...]}.
"""
import os, sys, json, time, argparse, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SKETCHUP = r"C:\Program Files\SketchUp\SketchUp 2021\SketchUp.exe"
PLUGINS = os.path.expandvars(r"%APPDATA%\SketchUp\SketchUp 2021\SketchUp\Plugins")
SEED = os.path.join(HERE, "seed_template.skp")
RECOVERED = os.path.expandvars(r"%LOCALAPPDATA%\SketchUp\SketchUp 2021\SketchUp\working\SKETCHUP\RecoveredFiles")

BOOTSTRAP = '''# AUTO one-shot: run the pure-Ruby generator then self-delete.
MAIMAAR_LOG = File.join(File.dirname(__FILE__), 'maimaar_oneshot.log')
MAIMAAR_MODEL = {model!r}
File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}} loaded") }}
UI.start_timer(4, false) do
  begin
    load 'D:/maimaar-os/sketchup_generator/maimaar_skp.rb'
    File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}} OK") }}
  rescue => e
    File.open(MAIMAAR_LOG, 'a') {{ |f| f.puts("#{{Time.now}} ERROR #{{e.message}}") }}
  ensure
    begin; File.delete(__FILE__); rescue; end
  end
end
'''


def sanitize(s):
    return "".join(c if (c.isalnum() or c in "-_") else "_" for c in str(s or "model"))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("--timeout", type=int, default=220)
    args = ap.parse_args(argv)

    model = json.load(open(args.model, encoding="utf-8"))
    base = sanitize(model.get("proposalNo"))
    os.makedirs(OUT, exist_ok=True)

    # clear prior outputs for this proposal + stale recovery/bootstrap state
    for f in os.listdir(OUT):
        if f.startswith(base + ".") or f.startswith(base + "_"):
            try: os.remove(os.path.join(OUT, f))
            except OSError: pass
    if os.path.isdir(RECOVERED):
        for f in os.listdir(RECOVERED):
            try: os.remove(os.path.join(RECOVERED, f))
            except OSError: pass
    log = os.path.join(PLUGINS, "maimaar_oneshot.log")
    if os.path.exists(log):
        os.remove(log)

    model_fwd = os.path.abspath(args.model).replace("\\", "/")
    open(os.path.join(PLUGINS, "maimaar_oneshot.rb"), "w", encoding="utf-8").write(BOOTSTRAP.format(model=model_fwd))

    subprocess.Popen([SKETCHUP, SEED])
    skp = os.path.join(OUT, base + ".skp")
    want = 9
    t0 = time.time()
    while time.time() - t0 < args.timeout:
        snaps = [f for f in os.listdir(OUT) if f.startswith(base + "_") and f.endswith(".png")]
        if os.path.exists(skp) and os.path.getsize(skp) > 0 and len(snaps) >= want:
            time.sleep(1); break
        time.sleep(3)
    snaps = sorted(os.path.join(OUT, f) for f in os.listdir(OUT) if f.startswith(base + "_") and f.endswith(".png"))
    if not os.path.exists(skp):
        sys.exit("TIMEOUT — see " + log)
    print(json.dumps({"skp": skp, "snaps": snaps}))


if __name__ == "__main__":
    main()
