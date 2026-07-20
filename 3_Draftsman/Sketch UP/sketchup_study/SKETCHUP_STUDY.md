# Maimaar SketchUp Model Study — Database for Future 3D Generation

**Goal:** study Maimaar's existing SketchUp (`.skp`) proposal models to learn the
house conventions, so Maimaar OS can later **auto-generate SketchUp models from the
Inquiry Form** — the 3D counterpart to the IF→DXF drawing generator
(`drawing_generator/`). The same canonical building model feeds both.

**Source:** `E:\Maimaar Steel Pvt Ltd\Proposals` (all years, 2015→2026).

## Method (headless — no SketchUp needed)
SketchUp 2021 `.skp` files start with a short proprietary header, then embed a **ZIP**
(`PK..`). The raw geometry lives in the proprietary `model.dat` (not parsed), but the
ZIP exposes conventions directly:
- **Layer/tag names + display colour** — `materials/Layer_<name>/material.xml`
- **Named scenes** — `scene_thumbnails/<Scene>.png`
- **Materials / textures, styles, IFC classification**

Scripts: `extract_skp_db.py` (walks the tree → `skp_database.json`), then
`normalize_layers.py` (collapses raw names → canonical categories → `layer_canonical.json`).

## Corpus
- **2,302** `.skp` files found; **2,176 parsed**; **126 errors** (older pre-2021 format
  with no embedded ZIP — these need SketchUp/SDK to read).
- **1,283 distinct raw layer names** → collapse to **~27 canonical PEB categories**.

## Key findings
1. **No enforced layer standard.** The same component is spelled many ways — `MS`/`ms`/
   `M.S`/`Ms`; `PURLIN`/`purlin`/`Purline`/`Purlins`/`PURLINS`; `Gutter`/`Gutters`/
   `Gutter and Pipes`/`EAVE GUTTER`. Casing, plurals, abbreviations all vary by drafter.
   → The generator should **impose one clean canonical tag set** (below).
2. **Colour-by-tag is the norm.** Each model carries `Layer_<name>` materials so the
   model reads by colour. Dominant colours per component are consistent enough to adopt.
3. **Steel frame = one tag "MS"** (columns + rafters together, 1,004 uses) far more often
   than split `COLUMN`/`RAFTER` tags — drafters model the rigid frame as one MS group.
4. **Scenes are generic** (`Scene 1..N`), typically **6–8 per model** (the standard view
   set exported as `01.jpg…08.jpg`). Naming carries no semantics — order is the view set.
5. **Style:** `Architectural Design Style` dominates (1,357 models). That is the house look.
6. **Decoration entities exist** (people `Sumele`, cars, trucks, trees) — entourage for
   presentation, not structure. The generator can skip these or add a small fixed set.

## Canonical layer/tag standard (proposed for the generator)
Adopt these tags + colours (most-common observed RGB). One tag per real component class.

| Canonical tag | Meaning | RGB | Raw uses |
|---|---|---|---|
| `MS-FRAME` | rigid frame: columns + rafters (steel) | 119,119,153 | 1004 |
| `PURLIN` | purlins + girts (secondary steel) | 0,153,135 | 1169 |
| `SHEETING` | roof + wall cladding sheets | 102,68,0 | 1186 |
| `DECK-PANEL` | decking / sandwich panels | 0,153,135 | 319 |
| `GUTTER-DOWNPIPE` | eave gutter + downpipes | 170,68,0 | 977 |
| `DOOR` | doors / roller shutters | — | 395 |
| `WINDOW` | windows | — | 172 |
| `GLASS` | glazing / curtain wall (translucent) | 119,119,153 | 111 |
| `BRICK-MASONRY` | brick / block walls | 153,0,255 | 718 |
| `RCC-CONCRETE` | RCC columns/beams/slab/footings/civil | 102,68,0 | 212 |
| `STAIR` | stairs + ladders | — | 359 |
| `HANDRAIL` | handrails / railing | 119,119,153 | 172 |
| `CHECKERED-PLATE` | chequered plate flooring | — | 106 |
| `MEZZANINE` | mezzanine framing/deck | — | 78 |
| `CRANE` | EOT crane, trolley, runway | 0,153,135 | 71 |
| `ROOF-MONITOR-VENT` | roof monitor, ridge vent, turbo/exhaust, louvers | 0,153,135 | 215 |
| `CANOPY-FASCIA` | canopy, fascia, parapet | 0,153,135 | 84 |
| `BASE-BOLT` | anchor bolts / base plates | — | 45 |
| `SOLAR` | solar PV array | 204,68,0 | 50 |
| `EQUIPMENT` | client machines/AHU/tanks (reference) | — | 168 |
| `EXISTING` | existing building (reference, greyed) | — | 97 |
| `ENTOURAGE` | people / cars / trees (presentation) | — | 55 |
| `ANNOTATION` | titles / dims / north / logo | — | 396 |

Also seen unmatched but worth tags: `JOIST` (truss/joists), `STEEL-TUBE`/`C-CHANNEL`
(secondary), `PARTITION`, `LIFT`, `PLATFORM`, `CABLE-TRAY`, `MESH`.

## Gap & next step
The ZIP gives **tags, colours, scenes, styles, materials** — enough to set up a generated
model's organization and look. It does **not** give **geometry** (member sizes, grid,
frame profiles) — that is in `model.dat`. Two ways to close the geometry gap:

1. **Ruby export from SketchUp 2021** (recommended): a script run inside SketchUp opens a
   `.skp` and dumps outliner / component definitions / instances / per-tag bounding boxes
   to JSON. This reverse-documents how a real model is *built* (group hierarchy, repeats
   per bay, transforms) — the blueprint for the generator. Needs the app (GUI), batchable.
2. **Generate from the IF canonical model directly** (the end goal): build a
   `sketchup_generator` that, like `drawing_generator`, reads the IF building model and
   writes a `.skp` (via the SketchUp Ruby API or a `.skp` writer) using the standard above.

**Recommended order:** (a) write the Ruby exporter, run it on ~10 representative models to
capture the build pattern; (b) design `sketchup_generator` from the IF model using this
tag standard; (c) wire a web route like the DXF path.

## Files
- `extract_skp_db.py` — headless ZIP harvester → `skp_database.json` (per-model + aggregates)
- `normalize_layers.py` — raw→canonical layer mapping → `layer_canonical.json`
- `skp_database.json` — full database (2,302 models)
- `layer_canonical.json` — canonical category rollup with colours + spellings
