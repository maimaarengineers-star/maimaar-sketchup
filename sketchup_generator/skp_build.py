"""
skp_build.py — IF canonical building model -> neutral 3D build instructions (skp_build.json)
that the SketchUp Ruby builder (build_skp.rb) turns into a .skp + snapshot images.

Mirrors the drawing_generator split: heavy geometry stays in Python (consistent with the
2D sheets); Ruby is a thin builder that only needs SketchUp to run. Coordinates are in
METRES (Ruby converts with .m). Axes: x = along length, y = across width, z = up.

Tag standard + colours come from the SketchUp study (sketchup_study/SKETCHUP_STUDY.md).

Run:  python skp_build.py [model.json] [-o skp_build.json]
Default model = drawing_generator/sample_model.json
"""
import os, sys, json, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MODEL = os.path.join(HERE, "..", "drawing_generator", "sample_model.json")

# Canonical tags -> {rgb, alpha}. Matches Maimaar's house SketchUp convention (learned by
# reading the real proposal models): PRIMARY rigid frame = RED, secondary purlins/girts a
# distinct colour, sheeting TRANSLUCENT (frame shows through) in different types, masonry
# base band opaque brown. alpha 1.0 = opaque, lower = see-through.
TAGS = {
    "MS-FRAME":        {"rgb": [206, 32, 32],   "alpha": 1.0},   # PRIMARY frame (tapered) - RED
    "PLATE":           {"rgb": [120, 124, 130], "alpha": 1.0},   # connection plates (base/haunch/ridge)
    "PURLIN":          {"rgb": [222, 180, 44],  "alpha": 1.0},   # purlins + girts (secondary) - yellow
    "SHEETING":        {"rgb": [198, 203, 209], "alpha": 0.32},  # WALL sheeting - translucent
    "ROOF-SHEET":      {"rgb": [188, 196, 206], "alpha": 0.30},  # ROOF sheeting - translucent
    "SKYLIGHT":        {"rgb": [225, 238, 248], "alpha": 0.18},  # roof skylight - more translucent
    "GUTTER-DOWNPIPE": {"rgb": [170, 68, 0],    "alpha": 1.0},
    "DOOR":            {"rgb": [70, 72, 78],    "alpha": 1.0},   # opaque dark door leaf
    "WINDOW":          {"rgb": [150, 190, 215], "alpha": 0.45},  # glazed
    "BRICK-MASONRY":   {"rgb": [150, 95, 62],   "alpha": 1.0},   # base masonry/brick band
    "ANNOTATION":      {"rgb": [80, 80, 80],    "alpha": 1.0},
}

# REAL section profiles, CALIBRATED to the existing models (sketchup_study/parts_database.json
# from 12 extracted PP models) + Technical Manual Ch.3/Ch.5. Dimensions in m.
# Primary built-up I: flange ~250-300 (median 300), web depth tapers 300->~1450 (scales with
# span), tf~16, tw~8.  Secondary Z: 200mm deep ("200Z"), flange ~75, gauge ~2mm.
I_FLANGE_W = 0.225        # flange width bf (real median 227)
I_FLANGE_T = 0.016        # flange thickness tf
I_WEB_T    = 0.008        # web thickness tw
Z_DEPTH    = 0.20         # 200Z web depth
Z_FLANGE   = 0.075        # Z flange width (~75 mm)
Z_THICK    = 0.022        # plate thickness shown (real ~2 mm; exaggerated so the Z reads)
PURLIN_SPACING = 1.5      # m
WALL_SURF = ("NSW", "FSW", "LEW", "REW")


def imember(tag, a, b, dA, dB, note=""):
    """Built-up I-section member; web depth tapers dA->dB; constant flanges."""
    return {"kind": "member", "profile": "I", "tag": tag, "a": list(a), "b": list(b),
            "dA": dA, "dB": dB, "bf": I_FLANGE_W, "tf": I_FLANGE_T, "tw": I_WEB_T, "note": note}


def zmember(tag, a, b, note=""):
    """Cold-formed Z-section purlin / girt (constant)."""
    return {"kind": "member", "profile": "Z", "tag": tag, "a": list(a), "b": list(b),
            "d": Z_DEPTH, "bz": Z_FLANGE, "t": Z_THICK, "note": note}


def _num(v, d=0.0):
    try:
        return float(str(v).strip())
    except (ValueError, TypeError, AttributeError):
        return float(d)


def seg(tag, a, b, w, h, wB=None, hB=None, note=""):
    """A (possibly tapered) prismatic member. Section at end a = (w,h); at end b = (wB,hB).
    For constant members omit wB/hB."""
    return {"kind": "member", "tag": tag, "a": list(a), "b": list(b),
            "wA": w, "hA": h, "wB": (w if wB is None else wB), "hB": (h if hB is None else hB),
            "note": note}


def face(tag, poly, note=""):
    return {"kind": "face", "tag": tag, "poly": [list(p) for p in poly], "note": note}


def plate(tag, poly, thick, note=""):
    """A flat steel plate: polygon extruded by `thick` (m) along its normal. Used for
    base plates, knee haunch gussets and the ridge plate (genuine PEB connections)."""
    return {"kind": "plate", "tag": tag, "poly": [list(p) for p in poly], "thick": thick, "note": note}


def _openings(area, ox, oy, L, W, eave, grids):
    """Place wall doors/windows + roof skylights as faces just outside the cladding."""
    prim = []
    plc = area.get("placements") or []
    if not plc:
        return prim, []
    side_grids = {g["id"]: float(g["pos"]) for g in grids.get("length", [])}
    end_grids = {g["id"]: float(g["pos"]) for g in grids.get("width", [])}
    OFF = 0.06  # m, sit opening slightly proud of the wall so it reads in snaps

    # surface -> (span, gridmap, builder(start_along, w, z0, z1) -> poly)
    def nsw(s, w, z0, z1):
        return [(ox + s, oy - OFF, z0), (ox + s + w, oy - OFF, z0),
                (ox + s + w, oy - OFF, z1), (ox + s, oy - OFF, z1)]

    def fsw(s, w, z0, z1):
        return [(ox + s, oy + W + OFF, z0), (ox + s + w, oy + W + OFF, z0),
                (ox + s + w, oy + W + OFF, z1), (ox + s, oy + W + OFF, z1)]

    def lew(s, w, z0, z1):
        return [(ox - OFF, oy + s, z0), (ox - OFF, oy + s + w, z0),
                (ox - OFF, oy + s + w, z1), (ox - OFF, oy + s, z1)]

    def rew(s, w, z0, z1):
        return [(ox + L + OFF, oy + s, z0), (ox + L + OFF, oy + s + w, z0),
                (ox + L + OFF, oy + s + w, z1), (ox + L + OFF, oy + s, z1)]

    surfaces = {"NSW": (L, side_grids, nsw), "FSW": (L, side_grids, fsw),
                "LEW": (W, end_grids, lew), "REW": (W, end_grids, rew)}

    for surf, (span, gmap, mk) in surfaces.items():
        items = [p for p in plc if str(p.get("surface", "")).upper() == surf]
        # expand each placement to qty instances; split gridded vs distributed
        gridded, free = [], []
        for p in items:
            w = _num(p.get("width")) / 1000.0
            h = _num(p.get("height")) / 1000.0
            sill = _num(p.get("sill")) / 1000.0
            if w <= 0 or h <= 0:
                continue
            typ = str(p.get("type", "")).lower()
            tag = "DOOR" if any(k in typ for k in ("door", "shutter", "roller", "sliding")) else "WINDOW"
            qty = max(1, int(_num(p.get("qty"), 1)))
            gf = str(p.get("gridFrom", "")).strip()
            for _ in range(qty):
                (gridded if gf in gmap else free).append((p, w, h, sill, tag, gf))
        # gridded openings keep their grid position
        for (p, w, h, sill, tag, gf) in gridded:
            s = gmap[gf] + _num(p.get("offset")) / 1000.0
            s = max(0.15, min(s, span - w - 0.15))
            z1 = min(sill + h, eave - 0.1)
            prim.append(face(tag, mk(s, w, sill, z1), p.get("type", "opening")))
        # free openings distributed evenly across the wall
        n = len(free)
        for i, (p, w, h, sill, tag, gf) in enumerate(free):
            s = span * (i + 1) / (n + 1) - w / 2.0
            s = max(0.15, min(s, span - w - 0.15))
            z1 = min(sill + h, eave - 0.1)
            prim.append(face(tag, mk(s, w, sill, z1), p.get("type", "opening")))

    # roof skylights: translucent strips along the ridge run (one row each slope)
    roof = [p for p in plc if str(p.get("surface", "")).upper() == "ROOF"
            and "sky" in str(p.get("type", "")).lower()]
    return prim, roof


def build_area(b, area, ox=0.0, oy=0.0):
    r = area["resolved"]
    m = r["metrics"]
    W = float(m["width"]); L = float(m["length"])
    eave = float(m["eaveHeight"])
    peak = float(r["roof"].get("peakHeight") or m.get("peakHeight") or eave)
    ridge_y = float(r["roof"].get("ridgePos") or W / 2.0)
    xs = [float(g["pos"]) for g in r["grids"]["length"]] or [0.0, L]
    prim = []

    # tapered I web depths CALIBRATED to parts_database.json: ends ~300-350 mm; knee scales
    # with the SPAN (real: 31 m span -> ~1.25 m knee; matches HICO/Millat). Clamped 0.45-1.6 m.
    span = W
    d_base = 0.35
    d_apex = 0.35
    d_knee = min(1.6, max(0.45, span * 0.040))

    def Z_at(y):
        if ridge_y <= 0 or ridge_y >= W:
            return eave
        return eave + (peak - eave) * (y / ridge_y if y <= ridge_y else (W - y) / (W - ridge_y))

    # rigid frames: built-up TAPERED I-section columns + rafters (primary, red)
    for x0 in xs:
        x = x0 + ox
        # columns: I web depth d_base at base -> d_knee at eave
        prim.append(imember("MS-FRAME", (x, oy + 0, 0), (x, oy + 0, eave), d_base, d_knee, "column"))
        prim.append(imember("MS-FRAME", (x, oy + W, 0), (x, oy + W, eave), d_base, d_knee, "column"))
        # rafters: I web depth d_knee at eave -> d_apex at ridge (each slope)
        apex = (x, oy + ridge_y, peak)
        prim.append(imember("MS-FRAME", (x, oy + 0, eave), apex, d_knee, d_apex, "rafter"))
        prim.append(imember("MS-FRAME", apex, (x, oy + W, eave), d_apex, d_knee, "rafter"))

        # --- genuine connection plates (rule from PD/AutoCAD section module) ---
        tp = 0.014                      # end-plate / gusset thickness (real ~12-16mm)
        bpw, bpd, bpt = 0.32, 0.49, 0.022   # base plate ~320 x 490 x 22 (from parts DB)
        # base plates at both column feet (horizontal plate, anchor-bolt footprint)
        for yc in (0.0, W):
            prim.append(plate("PLATE",
                [(x - bpw / 2, oy + yc - bpd / 2, 0.0), (x + bpw / 2, oy + yc - bpd / 2, 0.0),
                 (x + bpw / 2, oy + yc + bpd / 2, 0.0), (x - bpw / 2, oy + yc + bpd / 2, 0.0)],
                bpt, "base-plate"))
        # knee haunch gusset (triangular, in the frame plane) at each eave corner
        g = d_knee * 1.25
        prim.append(plate("PLATE", [(x, oy + 0, eave), (x, oy + 0, eave - g),
                                    (x, oy + g, eave)], tp, "knee-gusset"))
        prim.append(plate("PLATE", [(x, oy + W, eave), (x, oy + W, eave - g),
                                    (x, oy + W - g, eave)], tp, "knee-gusset"))
        # ridge connection plate (vertical, at the apex between rafter ends)
        prim.append(plate("PLATE", [(x, oy + ridge_y - 0.18, peak - d_apex),
                                    (x, oy + ridge_y + 0.18, peak - d_apex),
                                    (x, oy + ridge_y + 0.18, peak),
                                    (x, oy + ridge_y - 0.18, peak)], tp, "ridge-plate"))

    x0, xL = xs[0] + ox, xs[-1] + ox

    # purlins on each slope
    def slope_ys(start, end):
        ys, y = [], start
        step = PURLIN_SPACING if end > start else -PURLIN_SPACING
        while (step > 0 and y < end) or (step < 0 and y > end):
            ys.append(y); y += step
        ys.append(end)
        return ys
    for y in slope_ys(0.0, ridge_y) + slope_ys(W, ridge_y):
        z = Z_at(y)
        prim.append(zmember("PURLIN", (x0, oy + y, z + 0.12), (xL, oy + y, z + 0.12), "purlin"))

    # wall girts on NSW/FSW
    gz = PURLIN_SPACING
    while gz < eave:
        prim.append(zmember("PURLIN", (x0, oy + 0, gz), (xL, oy + 0, gz), "girt"))
        prim.append(zmember("PURLIN", (x0, oy + W, gz), (xL, oy + W, gz), "girt"))
        gz += PURLIN_SPACING

    # opaque cladding faces
    prim.append(face("ROOF-SHEET", [(x0, oy + 0, eave), (xL, oy + 0, eave),
                                    (xL, oy + ridge_y, peak), (x0, oy + ridge_y, peak)], "roof-L"))
    prim.append(face("ROOF-SHEET", [(x0, oy + ridge_y, peak), (xL, oy + ridge_y, peak),
                                    (xL, oy + W, eave), (x0, oy + W, eave)], "roof-R"))
    prim.append(face("SHEETING", [(x0, oy + 0, 0), (xL, oy + 0, 0),
                                  (xL, oy + 0, eave), (x0, oy + 0, eave)], "NSW"))
    prim.append(face("SHEETING", [(x0, oy + W, 0), (xL, oy + W, 0),
                                  (xL, oy + W, eave), (x0, oy + W, eave)], "FSW"))
    for x, nm in ((x0, "LEW"), (xL, "REW")):
        prim.append(face("SHEETING", [(x, oy + 0, 0), (x, oy + W, 0),
                                      (x, oy + W, eave), (x, oy + ridge_y, peak),
                                      (x, oy + 0, eave)], nm))

    # openings (doors/windows) + roof skylights
    opn, roof_sky = _openings(area, ox, oy, L, W, eave, r["grids"])
    prim += opn
    for p in roof_sky:
        w = _num(p.get("width")) / 1000.0 or 1.0
        qty = max(1, int(_num(p.get("qty"), 1)))
        for i in range(qty):
            sx = L * (i + 1) / (qty + 1) - w / 2.0
            sx = max(0.5, min(sx, L - w - 0.5))
            # one panel each slope, near the ridge
            yA = ridge_y * 0.5
            prim.append(face("SKYLIGHT", [(x0 + sx, oy + yA, Z_at(yA) + 0.12),
                                          (x0 + sx + w, oy + yA, Z_at(yA) + 0.12),
                                          (x0 + sx + w, oy + ridge_y - 0.3, peak + 0.12),
                                          (x0 + sx, oy + ridge_y - 0.3, peak + 0.12)], "skylight"))

    return prim, (L, W, eave, peak)


def build(model):
    prims = []
    bb = [0, 0, 0]
    for b in model["buildings"]:
        layout = {la["na"]: la for la in b.get("layout", {}).get("areas", [])}
        for area in b["areas"]:
            la = layout.get(area["areaNo"], {})
            ox, oy = float(la.get("x", 0)), float(la.get("y", 0))
            p, dims = build_area(b, area, ox, oy)
            prims += p
            bb[0] = max(bb[0], ox + dims[0]); bb[1] = max(bb[1], oy + dims[1])
            bb[2] = max(bb[2], dims[3])
    return {
        "meta": {"proposalNo": model.get("proposalNo"), "customer": model.get("customer"),
                 "project": model.get("project"), "units": "m", "bbox": bb},
        "tags": TAGS,
        "style": "Architectural Design Style",
        "scenes": ["ISO-FL", "ISO-FR", "ISO-BL", "ISO-BR", "FRONT", "SIDE", "BACK", "TOP"],
        "primitives": prims,
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("model", nargs="?", default=DEFAULT_MODEL)
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "skp_build.json"))
    args = ap.parse_args(argv)
    model = json.load(open(args.model, encoding="utf-8"))
    spec = build(model)
    json.dump(spec, open(args.out, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    members = sum(1 for p in spec["primitives"] if p["kind"] == "member")
    faces = len(spec["primitives"]) - members
    opn = sum(1 for p in spec["primitives"] if p["tag"] in ("DOOR", "WINDOW", "SKYLIGHT"))
    print(f"{args.out}: {len(spec['primitives'])} primitives "
          f"({members} members, {faces} faces, {opn} openings); bbox {spec['meta']['bbox']}")


if __name__ == "__main__":
    main()
