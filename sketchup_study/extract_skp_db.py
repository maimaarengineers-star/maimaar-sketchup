"""
extract_skp_db.py — headless study of Maimaar's existing SketchUp proposal models.

SketchUp 2021 (.skp v21) files embed a ZIP section (after a small proprietary
header) holding materials, styles, scenes, classifications and a meta blob. The
raw geometry lives in the proprietary `model.dat` (NOT read here), but the ZIP
alone exposes Maimaar's *conventions*:

  - Layer (tag) names + their display colour, via `materials/Layer_<name>/material.xml`
  - Named scenes (the standard view set) via `scene_thumbnails/<Scene>.png`
  - Applied materials / textures, styles, IFC classification presence

This builds a database (skp_database.json) + frequency aggregates so we can later
GENERATE SketchUp models from the IF canonical model with the same conventions.

Run:  python extract_skp_db.py  ["E:\\Maimaar Steel Pvt Ltd\\Proposals"]
"""
import os, sys, io, json, re, zipfile
from collections import Counter
from xml.etree import ElementTree as ET

ROOT = sys.argv[1] if len(sys.argv) > 1 else r"E:\Maimaar Steel Pvt Ltd\Proposals"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "skp_database.json")

MAT_NS = "{http://sketchup.google.com/schemas/sketchup/1.0/material}"


def open_skp_zip(path):
    """Return a ZipFile over the embedded archive in a .skp, or None."""
    data = open(path, "rb").read()
    i = data.find(b"PK\x03\x04")
    if i < 0:
        return None
    try:
        return zipfile.ZipFile(io.BytesIO(data[i:]))
    except Exception:
        return None


def parse_material_xml(b):
    try:
        root = ET.fromstring(b)
        m = root.find(MAT_NS + "material")
        if m is None:
            return None
        g = m.attrib.get
        rgb = None
        if g("colorRed") is not None:
            rgb = [int(g("colorRed", 0)), int(g("colorGreen", 0)), int(g("colorBlue", 0))]
        return {
            "name": g("name"),
            "rgb": rgb,
            "trans": float(g("trans", 1) or 1),
            "useTrans": g("useTrans") == "1",
            "hasTexture": g("hasTexture") == "1",
        }
    except Exception:
        return None


def study_skp(path):
    z = open_skp_zip(path)
    if z is None:
        return {"file": path, "error": "no embedded zip"}
    names = z.namelist()
    layers, materials, scenes, styles = [], [], [], []
    for n in names:
        if n.startswith("materials/") and n.endswith("material.xml"):
            mat = parse_material_xml(z.read(n))
            if not mat:
                continue
            nm = mat["name"] or ""
            if nm.startswith("Layer_"):
                layers.append({"layer": nm[len("Layer_"):], "rgb": mat["rgb"],
                               "trans": mat["trans"], "translucent": mat["useTrans"]})
            else:
                materials.append({"name": nm, "rgb": mat["rgb"], "texture": mat["hasTexture"]})
        elif n.startswith("scene_thumbnails/") and n.endswith(".png"):
            scenes.append(os.path.basename(n)[:-4])
        elif n.startswith("styles/") and n.endswith("style.xml"):
            m = re.search(r"styles/\[?([^/\]]+)\]?", n)
            if m:
                styles.append(m.group(1))
    return {
        "file": path,
        "size": os.path.getsize(path),
        "layers": layers,
        "materials": materials,
        "scenes": scenes,
        "styles": sorted(set(styles)),
        "has_ifc": any("classifications/" in n for n in names),
    }


def find_skps(root):
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if fn.lower().endswith(".skp"):
                yield os.path.join(dp, fn)


def main():
    models = []
    for p in find_skps(ROOT):
        try:
            models.append(study_skp(p))
        except Exception as e:
            models.append({"file": p, "error": str(e)})

    # aggregates
    layer_names = Counter()
    layer_colors = {}   # layer -> Counter of rgb tuples
    scene_names = Counter()
    style_names = Counter()
    mat_names = Counter()
    ok = [m for m in models if "error" not in m]
    for m in ok:
        for L in m["layers"]:
            layer_names[L["layer"]] += 1
            layer_colors.setdefault(L["layer"], Counter())[tuple(L["rgb"] or [])] += 1
        for s in m["scenes"]:
            scene_names[s] += 1
        for s in m["styles"]:
            style_names[s] += 1
        for mt in m["materials"]:
            if mt["name"]:
                mat_names[mt["name"]] += 1

    layer_conv = {}
    for name, cnt in layer_names.most_common():
        rgb, _ = layer_colors[name].most_common(1)[0]
        layer_conv[name] = {"count": cnt, "common_rgb": list(rgb)}

    db = {
        "root": ROOT,
        "model_count": len(models),
        "ok_count": len(ok),
        "errors": [m for m in models if "error" in m],
        "aggregate": {
            "layers": layer_conv,
            "scenes": dict(scene_names.most_common()),
            "styles": dict(style_names.most_common()),
            "materials": dict(mat_names.most_common(60)),
        },
        "models": models,
    }
    json.dump(db, open(OUT, "w", encoding="utf-8"), indent=2, ensure_ascii=False)

    print(f"models: {len(models)}  ok: {len(ok)}  errors: {len(db['errors'])}")
    print("\n== LAYER CONVENTIONS (name  count  rgb) ==")
    for name, info in layer_conv.items():
        print(f"  {name:<28} {info['count']:>4}  rgb{tuple(info['common_rgb'])}")
    print("\n== SCENE NAMES ==")
    for s, c in scene_names.most_common(20):
        print(f"  {s:<20} {c}")
    print("\n== STYLES ==")
    for s, c in style_names.most_common(10):
        print(f"  {s:<35} {c}")
    print(f"\nsaved {OUT}")


if __name__ == "__main__":
    main()
