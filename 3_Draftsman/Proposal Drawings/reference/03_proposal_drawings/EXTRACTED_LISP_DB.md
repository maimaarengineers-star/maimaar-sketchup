# Extracted LISP Presentation Database (from previous records)

This is the hard-extracted drawing standard that the AutoLISP engine uses to
generate live AutoCAD drawings. Every value below was parsed directly from the
LAYER tables (DXF group codes 2 / 62 / 370) and entity-lineweight usage of the
**best competitor exemplars**, then encoded into `engine/MAIMAAR_PEB_Standard.lsp`
(`*PEB-LAYERS*`, `*PEB-COLORS*`, `*PEB-TEXT-HEIGHTS*`, `*PEB-HATCH*`) and the
dimension setup in `engine/MAIMAAR_PEB_Plan.lsp` (`setup-maimaar-dim`,
`peb-dim-set-vars`).

## Source exemplars (the "best of" the archive)
`reference/03_proposal_drawings/DXF/proposals/` :
- **Template A — "Izhar clean"** (cleanest layer/colour/lineweight discipline):
  `10`, `12`, `14`, `18` (Building No.1 / Cooling Pads / Pearl&Khas). 46-layer canonical set.
- **Template B — "Mammut / Karren"** (heavy presentation, richest sheets):
  `33` (Options), `35` (Big-Bird). Heavy RED columns + orange RCC poché.
- **Grid sub-scheme:** `15` (Roshan) — thin 0.09 grid/column sub-layers.

Maimaar's own 17 records (`DXF/maimaar/`) are PDF-import garbage (210+ junk layers)
→ used for CONTENT reference only, never for the style DB.

## Key extracted facts (lineweights are DXF code 370 = mm×100)
- **Pervasive working line = 0.09** (code 9) — the dominant entity lineweight across
  the clean exemplars (e.g. file 14: `9` used 2384×). Most geometry sits at 0.09.
- **BORDER = 0.50** (cyan ACI 4 in Mammut; Maimaar keeps a white/branded frame at 0.50).
- **COLUMN (plan):** Template A = blue ACI 5 @ 0.05 (thin); **Template B = RED ACI 1 @ 0.50**
  (heavy) — **owner-approved heavy red columns adopted.**
- **RCC poché `HATCHR` = ACI 32 (orange) @ 0.30** (exemplar-exact, files 33/35).
- **CROSS bracing = ACI 82 @ 0.13, HIDDEN linetype** (files 10/12/14/18).
- **GRID = green ACI 3**; grid centre-lines / sub-scheme @ 0.09 (Roshan).
- **STEEL RAFTER = brown ACI 22**, ByLayer/thin. **CENTER lines = grey ACI 252, CENTER ltype.**
- **DIM/TEXT** thin (≤ 0.13); dims drawn predominantly at 0.09–0.13.

## Encoded layer table (engine `*PEB-LAYERS*` — name · ACI · linetype · mm)
BORDER 7/Cont/0.50 · TITLEBLOCK 1/0.35 · TB-HEADER 1/0.50 ·
GRID 3/0.13 · GRID-LINES 8/DASHDOT/0.09 · GRID-TEXT 1/0.09 · COLUMN-HATCH 8/0.09 ·
STRUCTURE 7/0.25 · **COLUMNS 1/0.50** · COL-CENTER&CL 1/CENTER/0.09 · BOLTS 7/0.09 ·
PLATES 7/0.35 · FRAME 7/0.50 · FRAME-FILL 8/0.09 · RIDGE 5/HIDDEN/0.18 · RAFTER 8/HIDDEN/0.09 ·
PURLINS&GIRTS 6/0.13 · SHEETING 5/0.09 · CLADDING 5/0.18 · COL-OUTER 4/DASHDOT/0.09 · GUTTER 4/0.18 ·
DIMENSIONS 3/0.13 · ARROWS 3/0.13 · TEXT 7/0.13 · AREA-MARK 8/0.09 ·
BRICK-WALL 30/0.25 · RCC-COLUMN 8/0.35 · GROUND 7/0.50 · GROUND-HATCH 8/0.09 ·
**HATCHR 32/0.30** · HATCH 8/0.05.

## Dimensions (special care — owner request)
- **Text:** `DIMTXT 500` (plots ~2.1 mm @1:240 … ~4.2 mm @1:120) — legible, never bulky.
- **Arrows:** **architectural TICK** via `DIMTSZ 170` (the clean structural-dim slash),
  NOT a 600-tall filled head. Value sits ABOVE a continuous dim line (`DIMTAD 1`).
- Spacing chains print the IF grouping verbatim (mm); overall dims carry the basis text.

## Columns — size matching Maimaar (IMPLEMENTED)
Plan main-column web depth is **Maimaar-typical BY SPAN**: `peb-col-web-depth` ≈
span/30, rounded to 50 mm, clamped 400..1000 (`*PEB-COL-WEB*`). It drives both the
drawn column symbol (`draw-I-column-lengthwise`) and the sidewall inset
`colOff = web/2` (outer flange flush on the grid). Refine to exact estimation
sections later when an estimation run feeds the frame.

## How it's used
Load order **Standard → Section → Plan → Cover**; `peb-std-setup` lays the layer/colour/
lineweight DB (code-370 written into each LAYER record). All sheets (cover, plan,
section, and the new elevations / roof plan / typical details) draw on these layers, so
the whole set is consistent and plotter-perfect. Re-extract with the parser in the
session scratchpad if the archive grows.
