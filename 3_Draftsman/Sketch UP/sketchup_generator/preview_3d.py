"""
preview_3d.py — render skp_build.json to isometric PNG(s) with matplotlib, so the 3D
massing is verifiable WITHOUT SketchUp (same philosophy as drawing_generator's PNGs).
This is a check, not the deliverable; the real model/snaps come from build_skp.rb.

Run:  python preview_3d.py [skp_build.json]
"""
import os, sys, json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "skp_build.json")
spec = json.load(open(SPEC, encoding="utf-8"))
tags = spec["tags"]


def _tag(tag):
    t = tags.get(tag, {"rgb": [120, 120, 120], "alpha": 1.0})
    return t["rgb"], t.get("alpha", 1.0)


def rgb(tag):
    c, _ = _tag(tag)
    return (c[0] / 255, c[1] / 255, c[2] / 255)


VIEWS = [("ISO-FL", 22, -60), ("ISO-FR", 22, -120), ("FRONT", 5, -90), ("TOP", 89, -90)]
fig = plt.figure(figsize=(16, 11))
for i, (name, elev, azim) in enumerate(VIEWS, 1):
    ax = fig.add_subplot(2, 2, i, projection="3d")
    for p in spec["primitives"]:
        col = rgb(p["tag"])
        if p["kind"] == "member":
            a, b = p["a"], p["b"]
            depth = max(p.get("dA", 0), p.get("dB", 0)) or p.get("d", 0.15)
            lw = (1.0 + 4.0 * depth) if p["tag"] == "MS-FRAME" else 1.0
            ax.plot([a[0], b[0]], [a[1], b[1]], [a[2], b[2]], color=col, lw=lw)
        else:  # face / plate — keep cladding faint so structure stays visible
            poly = p["poly"]
            if p["tag"] == "PLATE":
                a = 0.95
            elif p["tag"] in ("DOOR", "WINDOW", "SKYLIGHT"):
                a = 0.6
            else:
                a = 0.12
            pc = Poly3DCollection([poly], alpha=a, facecolor=col, edgecolor=(0, 0, 0, 0.25))
            ax.add_collection3d(pc)
    bb = spec["meta"]["bbox"]
    ax.set_xlim(0, bb[0]); ax.set_ylim(0, bb[1]); ax.set_zlim(0, max(bb[0], bb[1]))
    try:
        ax.set_box_aspect((bb[0], bb[1], max(bb[2], bb[0] * 0.3)))
    except Exception:
        pass
    ax.view_init(elev=elev, azim=azim)
    ax.set_title(name); ax.set_axis_off()

m = spec["meta"]
fig.suptitle(f"{m.get('proposalNo','')}  {m.get('customer','')} — {m.get('project','')}  (3D massing preview)", fontsize=13)
out = os.path.join(HERE, "preview_3d.png")
fig.tight_layout(); fig.savefig(out, dpi=110)
print("wrote", out)
