"""
build_parts_db.py — turn extracted model geometry (geom_out/*.geom.json) into a COMPREHENSIVE
PEB parts/section LIBRARY. Special focus (per Nasir): CONNECTION PLATES (column/rafter end,
haunch, splice, base, ridge), PURLIN/GIRT CLIPS, BOLTS, BRACES and ACCESSORIES, plus the
primary I members and Z purlins/girts. Note: purlins & girts BYPASS the frame (run
continuous, attached by clips).

Outputs:
  parts_database.json  — per-category aggregate stats
  parts_library.json   — distinct part "shapes" (clustered by section/length) with counts
"""
import json, glob, os, statistics as st
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
GEOM = os.path.join(HERE, "geom_out")


def classify(s0, s1, L):
    """s0<=s1 cross-section (mm), L length (mm). Order matters (most specific first)."""
    if s1 is None or L is None:
        return "other"
    a, b = s0, s1
    if a < 30 and b < 60 and L < 140:
        return "bolt_fastener"
    if a < 6 and (b > 300 or L > 1500):
        return "sheeting_panel"
    if a <= 14 and b <= 320 and L <= 450:
        return "clip_bracket"                       # purlin/girt clips, small brackets
    if a <= 32 and 120 <= b <= 1300 and L <= 2600:
        # flat plate; base plate if squarish & mid-size
        if 280 <= b <= 750 and 280 <= L <= 800 and (L / max(b, 1)) < 2.2:
            return "base_plate"
        return "connection_plate"                   # end / haunch / splice / ridge / cap
    if a < 45 and b < 45 and L > 2500:
        return "rod_brace_pipe"                     # bracing rod/cable/pipe
    if 140 <= b <= 320 and 40 <= a <= 170 and L > 3000:
        return "purlin_girt_Z"                      # continuous, bypass frame
    if 150 <= a <= 520 and 300 <= b <= 1500 and L > 3000:
        return "primary_frame_I"                    # built-up tapered I (col/rafter)
    if 500 <= L <= 3500:
        return "accessory"                          # gutter/vent/louver/misc fitting
    return "other"


def stats(v):
    v = [x for x in v if x is not None]
    if not v:
        return None
    return {"min": round(min(v), 1), "med": round(st.median(v), 1), "max": round(max(v), 1), "n": len(v)}


def rnd(x, step):
    return int(round(x / step) * step)


def main():
    files = sorted(glob.glob(os.path.join(GEOM, "*.geom.json")))
    cats = defaultdict(lambda: {"defs": 0, "instances": 0, "s0": [], "s1": [], "L": []})
    library = defaultdict(lambda: {"instances": 0, "defs": 0, "models": set()})
    for f in files:
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        model = os.path.basename(f).replace(".geom.json", "")
        for de in d.get("definitions", []):
            sec = de.get("section"); L = de.get("length"); inst = de.get("instances", 0)
            if inst < 2 or not sec or sec[1] is None:
                continue
            s0, s1 = sec[0], sec[1]
            c = classify(s0, s1, L)
            b = cats[c]
            b["defs"] += 1; b["instances"] += inst
            b["s0"].append(s0); b["s1"].append(s1); b["L"].append(L)
            # library cluster: category + rounded section (+ rounded length for long members)
            if c in ("primary_frame_I", "purlin_girt_Z", "rod_brace_pipe"):
                key = f"{c}|{rnd(s0,10)}x{rnd(s1,25)}|L~{rnd(L,500)}"
            elif c in ("connection_plate", "base_plate", "clip_bracket", "bolt_fastener"):
                key = f"{c}|{rnd(s0,2)}x{rnd(s1,10)}x{rnd(L,10)}"
            else:
                key = f"{c}|{rnd(s0,10)}x{rnd(s1,50)}x{rnd(L,250)}"
            lib = library[key]
            lib["instances"] += inst; lib["defs"] += 1; lib["models"].add(model)

    db = {"models_analysed": len(files), "categories": {}}
    for c, b in cats.items():
        db["categories"][c] = {"defs": b["defs"], "instances": b["instances"],
                               "small_mm": stats(b["s0"]), "mid_mm": stats(b["s1"]), "length_mm": stats(b["L"])}
    json.dump(db, open(os.path.join(HERE, "parts_database.json"), "w", encoding="utf-8"), indent=2)

    lib_out = []
    for k, v in sorted(library.items(), key=lambda kv: -kv[1]["instances"]):
        lib_out.append({"shape": k, "instances": v["instances"], "defs": v["defs"], "in_models": len(v["models"])})
    json.dump({"shapes": lib_out}, open(os.path.join(HERE, "parts_library.json"), "w", encoding="utf-8"), indent=2)

    order = ["primary_frame_I", "purlin_girt_Z", "connection_plate", "base_plate",
             "clip_bracket", "bolt_fastener", "rod_brace_pipe", "sheeting_panel", "accessory", "other"]
    print(f"models analysed: {len(files)}\n")
    for c in order:
        if c not in db["categories"]:
            continue
        b = db["categories"][c]
        print(f"== {c:<18} defs={b['defs']:<5} inst={b['instances']:<7} "
              f"small={b['small_mm']and (b['small_mm']['min'],b['small_mm']['med'],b['small_mm']['max'])} "
              f"mid={b['mid_mm']and (b['mid_mm']['min'],b['mid_mm']['med'],b['mid_mm']['max'])} "
              f"len={b['length_mm']and (b['length_mm']['min'],b['length_mm']['med'],b['length_mm']['max'])}")
    print(f"\nlibrary distinct shapes: {len(lib_out)}  (top 5 connection/clip shapes):")
    for s in [x for x in lib_out if x['shape'].startswith(('connection_plate', 'clip_bracket', 'base_plate'))][:5]:
        print(f"   {s['shape']:<46} inst={s['instances']:<6} models={s['in_models']}")
    print("\nsaved parts_database.json + parts_library.json")


if __name__ == "__main__":
    main()
