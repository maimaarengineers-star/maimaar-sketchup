# Maimaar PEB Parts / Section Database (from existing SketchUp models)

Built by reading the REAL proposal models (the ground truth: real tapered I-frames, Z
girts/purlins, clips, connection plates, bolts). This DB calibrates the IF→SketchUp
generator (`../sketchup_generator/`) so generated models match Previous Proposals (PP).

## How it was built
1. `export_geometry.rb` runs inside SketchUp 2021 (auto-launch bootstrap) over a chosen
   set of `.skp`, dumping each model's size, tags, scenes and **component definitions**
   (name, instance count, bbox → cross-section + length) → `geom_out/<model>.geom.json`.
2. `build_parts_db.py` classifies every repeated component by cross-section & length into
   PEB part types and aggregates typical dimensions → `parts_database.json`.

## Sample set — DEEP SWEEP: 180 proposals selected (1 per proposal, 2015-2026, all types);
271 model extracts (many proposals reuse file names so extras were de-dup-named).

## Calibrated sections (mm) — min / median / max across 271 models
| Part | small (flange/thick) | mid (depth/width) | length | Instances | Notes |
|---|---|---|---|---|---|
| **Primary frame — built-up I** | 150 / **227** / 500 | 300 / **600** / 1499 | 3005 / 6248 / — | 11,035 | tapered web; flange ~225, web to ~1500 at knee; len≈bay≈6-7 m |
| **Purlin / girt — Z** | 40 / 143 / 163 | 140 / **201** / 317 | 3048 / 12556 / — | 12,440 | "200Z"; **BYPASS the frame** (continuous, clipped) |
| **Connection plate** | 0 / **25** / 31 | 120 / 302 / 1298 | 120 / 938 / 2576 | **18,011** | col/rafter end, haunch, splice, ridge, cap |
| **Base plate** | 5 / **22** / 32 | 296 / **321** / 700 | 296 / **492** / 780 | 495 | ~320 × 490 × 22 mm typical |
| **Clip / bracket** | 0 / 3 / 14 | 2 / 133 / 312 | 60 / **245** / 427 | 4,396 | purlin/girt clips (thin brackets ~130-310) |
| **Bolt / fastener** | 0 / 5 / 29 | 0 / 14 / 59 | 0 / **27** / 140 | **84,591** | ~M16-M24; head ~14-29 mm |
| **Rod / brace / pipe** | 8 / 25 / 44 | 8 / 29 / 44 | 2729 / 6020 / — | 390 | cable/rod cross-bracing, pipes |
| **Sheeting / panel** | 0 / 0 / 5 | 100 / 1172 / — | 370 / 1905 / — | 2,204 | thin (≤5 mm) |
| **Accessory** | — | — | 500 / 868 / 3494 | 123,550 | gutters/vents/louvers/machines/entourage |

### Connection-plate & clip library (top recurring shapes, thickness×width×length mm)
- `connection_plate 12×270×860` — in 19 models = the STANDARD rafter/column moment end-plate
- `connection_plate 16×150×600`, `connection_plate 6×390×900`
- `base_plate ~22×321×492`
- `clip_bracket 2×?×260`, `clip_bracket 6×30×320` — purlin/girt clips
- bolts: head/dia ~14-29 mm (M16-M24), typical length ~27 mm shown
Full clustered list (3,090 distinct shapes) in `parts_library.json`.

### KEY RULE — secondaries bypass the frame
Z purlins & girts run **continuous past the frames** and attach via **clips** (not framed
in between columns/rafters). The generator should draw purlins/girts as continuous lines
over the full bay run with clip components at each frame crossing.

### Generator calibration applied (sketchup_generator/skp_build.py)
- Primary I: flange `I_FLANGE_W=0.25`, `tf=0.016`, web `tw=0.008`; web depth: ends 0.35 m,
  **knee = clamp(span × 0.040, 0.45, 1.6)** (31 m span → 1.24 m, matches HICO/Millat).
- Z purlin/girt: depth `0.20` (200Z), flange `0.075`, gauge shown `0.022` (real ~2 mm).
- Bay spacing comes from the IF grid (real models median 7.05 m).

## Standard tag/colour convention (house style)
Primary frame = RED (tapered I); purlins/girts = YELLOW (Z); sheeting = translucent
(roof/wall/skylight types) + masonry base band; connection plates = grey (base/haunch/ridge).

## Coverage & next step toward "comprehensive"
This is calibrated on 12 models. To make the DB exhaustive across ALL building types &
sizes, re-run `export_geometry.rb` in batches over more models (the bootstrap takes any
list of `.skp`; ~12 models extract in ~30 s). Suggested expansion: 50-100 models spanning
years 2015-2026 and every structure type (clear-span, multi-span, mezzanine, crane,
canopy, multi-storey, hangar). `build_parts_db.py` re-aggregates automatically.

## Files
- `geom_out/*.geom.json` — per-model raw geometry extract (+ `batch.log`)
- `parts_database.json` — aggregated section/part DB (machine-readable)
- `export_geometry.rb` — the SketchUp extractor (batch via `MAIMAAR_GEOM_LIST`)
- `build_parts_db.py` — the classifier/aggregator
