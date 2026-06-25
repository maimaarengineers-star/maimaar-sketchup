# Maimaar SketchUp Generator (IF → .skp + snaps)

Auto-generates a **SketchUp model + snapshot images** from the Inquiry Form's canonical
building model — the 3D counterpart to `drawing_generator/` (IF → DXF). The draughtsman
then opens the `.skp`, fine-tunes (member profiles, openings, finishes) and produces the
final PD + SketchUp views.

**Purpose (Nasir, 25-Jun-2026):** after the IF is filled, the system generates the
SketchUp model + snaps; the draughtsman generates the PD & SketchUp and does the fine
tuning. This module covers the auto-generation half.

## Architecture (two parts, mirrors drawing_generator)
1. **`skp_build.py`** (headless) — reads the IF canonical model (same `sample_model.json`
   the DXF generator uses) and writes **`skp_build.json`**: a neutral list of 3D
   primitives (members + faces) in **metres**, plus the canonical tag/colour standard,
   scene list and style. Heavy geometry stays in Python (consistent with the 2D sheets).
2. **`build_skp.rb`** (runs inside SketchUp 2021) — reads `skp_build.json`, creates the
   tags + colours, builds frame members as solids and sheeting as faces, sets up the 8
   standard scenes, **exports snapshot PNGs**, and **saves the `.skp`** into `out/`.

`preview_3d.py` renders the build spec to an isometric PNG with matplotlib, so geometry
is verifiable **without** SketchUp (same philosophy as the DXF previews).

### House convention (learned by reading the real models in E:\...\Proposals)
- **Primary rigid frame = RED**, and **tapered** (deep at the eave knee, tapering to base
  and to ridge — the "cigar" rafter / tapered column profile).
- **Purlins & girts = secondary**, YELLOW.
- **Sheeting is TRANSLUCENT** (the red frame shows through) in different types: wall
  sheeting, roof sheeting, skylight (more translucent), with a masonry/brick base band.
- **Connection plates are genuine** — base plates at every column foot, knee haunch
  gussets at the eaves, ridge plate at the apex. Rule ported from the PD/AutoCAD section
  module (`drawing_generator/generate.py` draw_section: ht/rd/cb depths, ep=22mm end
  plate, haunch_plate + ridge plate + base plates).

Tags (`../sketchup_study/SKETCHUP_STUDY.md` + the convention above): `MS-FRAME` (red,
tapered primary), `PLATE` (connection plates), `PURLIN` (yellow secondary), `SHEETING` /
`ROOF-SHEET` / `SKYLIGHT` (translucent), `DOOR`, `WINDOW`, `BRICK-MASONRY`, `ANNOTATION`.
Each tag carries `{rgb, alpha}` (alpha<1 = translucent sheeting).

## Coordinate system
Metres. `x` = along length, `y` = across width, `z` = up. Frames sit at the length-grid
positions; rafters run eave→ridge→eave at `roof.ridgePos`/`roof.peakHeight`.

## Run
**One command (IF → .skp + 8 snaps), production entry point:**
```
cd sketchup_generator && python generate_from_if.py <building_model.json>
```
This builds the spec, writes the one-shot bootstrap, launches SketchUp 2021 on the bundled
`seed_template.skp`, waits, and returns the `.skp` + 8 PNG paths (JSON on the last line).
The IF web app produces `<building_model.json>` via services/drawingData (same JSON the 2D
drawing_generator uses) — a web route just shells out to this script.

**Spec only (headless check, no SketchUp):**
```
python skp_build.py [model.json]      # -> skp_build.json
python preview_3d.py                  # -> preview_3d.png
```
**Model + snaps (needs SketchUp 2021):** open SketchUp and in the Ruby Console:
```
load 'D:/maimaar-os/sketchup_generator/build_skp.rb'
```
→ `out/<proposalNo>.skp` + `out/<proposalNo>_<scene>.png` (8 snaps).

### Fully automated launch (no GUI clicks) — how the web app will trigger it
SketchUp's Welcome dialog blocks extension loading, so launch it **with a `.skp` file**
to bypass it, and drop a **one-shot bootstrap** in the Plugins folder that auto-runs the
builder then self-deletes. Proven flow:
1. `python skp_build.py <model.json>` → `skp_build.json`
2. copy any small `.skp` to a throwaway seed path (the builder calls `entities.clear!`
   first, so the seed content is discarded)
3. write a bootstrap to
   `%APPDATA%\SketchUp\SketchUp 2021\SketchUp\Plugins\maimaar_oneshot.rb` that does
   `UI.start_timer(4,false){ load '.../build_skp.rb' }` then `File.delete(__FILE__)`
   (NB: no constant assignment inside the timer block — Ruby "dynamic constant" error)
4. `Start-Process SketchUp.exe -ArgumentList '"<seed.skp>"'`
5. poll `out/` for the `.skp` + PNGs.

This was validated on `MSPL-26-042` (HICO Foods, 31×66 m): 9 frames, 8 snaps in ~10 s.

## Section database (from D:\Design Manual — the existing DB)
Read the real framing rules from the manuals:
- **Technical Manual.pdf** Ch.3 Standard Primary Framing (p91-98) — built-up **tapered
  I-section** rigid frames + base plates, tabulated by building width × eave height.
- Ch.5 Secondary Framing (p117-126) — **Z-sections** (purlins/girts), **C-sections** at
  endwalls; thicknesses 1.5/1.8/2.0/2.5 mm; ASTM A607/A653 Grade 50.
- **mammut design manual.pdf** Ch.16 Purlins & Girts (p701+) — cold-formed Z/C details.
Manuals are >100MB so the Read tool can't open them directly; render pages with PyMuPDF
(`fitz`) to PNG (poppler/pdftoppm is NOT installed). Member section dims now model these:
built-up I (flanges + tapering web) for primary, Z for purlins/girts (see `skp_build.py`
I_FLANGE_*/I_WEB_T, Z_DEPTH/Z_FLANGE/Z_THICK).

## Status (25-Jun-2026) — v5 COMPLETE (IF-ready)
One command turns an IF model into a `.skp` + 8 snaps. Components produced:
- RED built-up **tapered I-section** primary frame (web depth scales with span)
- **Z-section** purlins + girts (yellow) that **BYPASS** the frame (continuous, proud) with
  **CLIPS** at every crossing
- **ENDWALL framing** — intermediate endwall columns (from `endwallColPos`) + endwall girts
- real bolted **END-PLATES** at knees + ridge, calibrated **base plates** (320×490×22),
  representative **bolts** at base/knee/ridge
- **eave gutters** + corner **downpipes**
- **masonry base band** from `finish.blockWallHeight`; **doors/windows/skylights** from IF
  placements; TRANSLUCENT sheeting (roof on purlins / wall / skylight)
All sections calibrated to `../sketchup_study/parts_database.json` (271 real models).
Validated on MSPL-26-042 (HICO) + real_4734.
## Next (optional refinements)
- Roof monitor / ridge vent, mezzanine deck, crane runway — per IF `components` (wire like
  the others when those fields are populated).
- Multi-span interior columns (currently single-ridge gable); crane brackets.
- Web route: call `generate_from_if.py` from the server on an inquiry and return the files.
- Multi-area / multi-building tiling (uses building `layout` offsets; scaffolded).
- Camera framing per scene (match Maimaar's standard 6–8 view angles) + the house style.
- Web route: write `skp_build.json` for an inquiry, trigger the headless SketchUp run,
  return the `.skp` + snaps to the draughtsman (parallels the DXF/LISP route).
