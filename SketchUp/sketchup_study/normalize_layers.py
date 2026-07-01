"""
normalize_layers.py — collapse the 1283 raw layer names from skp_database.json into
canonical PEB component categories, so we can see the *real* component vocabulary
(drafters spell the same tag many ways) and pick a clean standard for generation.
"""
import os, json, re
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
db = json.load(open(os.path.join(HERE, "skp_database.json"), encoding="utf-8"))

# canonical category -> regex of raw-name tokens that mean it (checked in order)
CANON = [
    ("MAIN_FRAME (MS: cols+rafters)", r"^m\.?s$|main ?frame|steel ?frame"),
    ("COLUMN",            r"column|col\b"),
    ("RAFTER",            r"rafter|beam(?! ?pipe)"),
    ("PURLIN",            r"purl|girt"),
    ("SHEETING",          r"sheet|cladd|roof ?sheet|wall ?sheet"),
    ("DECK_PANEL",        r"deck|sandwich|panel"),
    ("DOOR",              r"\bdoor|shutter|roller"),
    ("WINDOW",            r"window|glaz"),
    ("GLASS",             r"glass|glaz|curtain ?wall"),
    ("GUTTER_DOWNPIPE",   r"gutter|downpipe|down ?pipe|pipe|rain"),
    ("BRICK_MASONRY",     r"brick|masonr|block ?wall|wall(?! ?sheet)"),
    ("RCC_CONCRETE",      r"rcc|concrete|slab|column ?ped|pedestal|footing|foundation|civil"),
    ("STAIR",             r"stair|ladder|step"),
    ("HANDRAIL",          r"hand ?rail|railing|hnadrail|hanrail|balustr"),
    ("MEZZANINE",         r"mezz"),
    ("CRANE",             r"crane|trolley|trolly|hoist|runway|gantry"),
    ("ROOF_MONITOR_VENT", r"monitor|moniter|ridge ?vent|ventilat|turbine|exhaust|louver|louvre"),
    ("CANOPY_FASCIA",     r"canopy|fascia|facia|parapet"),
    ("CHECKERED_PLATE",   r"checker|chacker|chackered|ckr|chequer|cheq"),
    ("BASE_BOLT",         r"bolt|anchor|base ?plate"),
    ("SOLAR",             r"solar|pv\b"),
    ("EQUIPMENT_MACHINE", r"machine|equipment|ahu|dryer|extractor|tank|silo|chiller"),
    ("SKYBRIDGE",         r"sky ?bridge|bridge|walkway"),
    ("VEHICLE_PEOPLE",    r"\bcar\b|vehicle|truck|people|person|human|figure|sumele|tree|plant"),
    ("EXISTING",          r"existing"),
    ("ANNOTATION",        r"title|text|dim|label|plan\b|area\b|greeting|north|logo|tag\d"),
    ("DEFAULT_LAYER0",    r"^layer0$|^tag1$|^untagged"),
]
_compiled = [(c, re.compile(p, re.I)) for c, p in CANON]


def classify(name):
    n = name.strip()
    for cat, rx in _compiled:
        if rx.search(n):
            return cat
    return None


buckets = {}   # cat -> {count, rgb Counter, examples set}
unmatched = Counter()
for name, info in db["aggregate"]["layers"].items():
    cat = classify(name)
    cnt = info["count"]
    if cat is None:
        unmatched[name] = cnt
        continue
    b = buckets.setdefault(cat, {"count": 0, "rgb": Counter(), "examples": Counter()})
    b["count"] += cnt
    if info["common_rgb"]:
        b["rgb"][tuple(info["common_rgb"])] += cnt
    b["examples"][name] += cnt

ordered = sorted(buckets.items(), key=lambda kv: -kv[1]["count"])
print(f"{'CANONICAL CATEGORY':<32}{'uses':>7}  {'rgb':<16} top raw spellings")
print("-" * 100)
out = {}
for cat, b in ordered:
    rgb = b["rgb"].most_common(1)[0][0] if b["rgb"] else ()
    ex = ", ".join(f"{n}({c})" for n, c in b["examples"].most_common(5))
    print(f"{cat:<32}{b['count']:>7}  {str(tuple(rgb)):<16} {ex}")
    out[cat] = {"uses": b["count"], "common_rgb": list(rgb),
                "spellings": dict(b["examples"].most_common(20))}

um = unmatched.most_common(40)
print(f"\nUNMATCHED raw layers: {len(unmatched)} distinct, {sum(unmatched.values())} uses")
for n, c in um[:40]:
    print(f"   {n} ({c})")

json.dump({"canonical": out, "unmatched_top": dict(um)},
          open(os.path.join(HERE, "layer_canonical.json"), "w", encoding="utf-8"),
          indent=2, ensure_ascii=False)
print("\nsaved layer_canonical.json")
