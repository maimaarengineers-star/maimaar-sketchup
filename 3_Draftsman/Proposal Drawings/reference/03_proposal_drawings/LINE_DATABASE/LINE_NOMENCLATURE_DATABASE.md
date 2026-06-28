# PEB COLUMN-LAYOUT PLAN — LINE NOMENCLATURE DATABASE
### The strict, picture-backed rulebook for the dynamic IF → AutoCAD drawing system

**Source of truth:** the real Mammut parent drawing
`reference/03_proposal_drawings/DXF/MAMMUT_07_Zealcon_MultiArea_Crane.dxf`
(Zealcon Engineering — "Proposed Workshop for Mehar Gas", quote PK-12-082).
Master render: `00_MASTER_real_zealcon_plan.png`. Element close-ups: `pics/`.

> **Rule of the system:** every element below is drawn on a FIXED layer with a FIXED
> colour / linetype / lineweight (the *strict* nomenclature), and POSITIONED dynamically
> from IF data (the *dynamic* geometry). The LISP must obey this table exactly.

> **Note on the real file:** Mammut *drew* much of the geometry on generic layers
> (`DET`, `0`, `REW`) but their template *defines* clean semantic layers
> (`COLUMN`, `CROSS`, `GRID`, `CENTER`, `BORDER`…). We adopt the clean **semantic**
> layer set below (matching `EXTRACTED_LISP_DB.md` + `MAIMAAR_PEB_Standard.lsp`),
> not the as-drawn mess.

| # | Element | Picture | Layer | ACI colour | Linetype | Lineweight | Dynamic rule (from IF) |
|---|---------|---------|-------|-----------|----------|-----------|------------------------|
| 1 | **Grid bubble — number** | `pics/01_grid_bubble_number.png` | `GRID` (outline) + `GRID-TEXT` (number) | green **3** outline, **red 1** number | Continuous | 0.13 | **PENTAGON** (apex toward building, ↓ for top row), r≈600. One per bay station, numbered `1..N` along the top. |
| 2 | **Grid bubble — letter** | `pics/02_grid_bubble_letter.png` | `GRID` + `GRID-TEXT` | green **3** / red **1** | Continuous | 0.13 | PENTAGON apex → (points right). Lettered `A,B…` down the left = width grid lines (A & B walls). |
| 3 | **Grid axis line** | (in 04) | `GRID-LINES` / `CENTER` | green **3** (real) | **CENTER** (dash-dot) | 0.09 | Vertical line at each bay station (1..N) + horizontal at A & B. Stops at the bubble. |
| 4 | **Building outline** | `pics/04_building_outline_columns.png` | `OUTLINE` | white **7** | Continuous | 0.35 | Rectangle (0,0)→(LENGTH, WIDTH) from IF `LENGTH`,`WIDTH`. |
| 5 | **Column** | `pics/04_building_outline_columns.png` | `COLUMN` | **red 1** | Continuous | **0.50 (heavy)** | I-section symbol at every grid intersection on A & B walls (+ interior per `STYPE`). Web depth sized by span (~span/30). |
| 6 | **Cross-bracing** | `pics/05_cross_bracing.png` | `CROSS` | **cyan 4** | **DASHED / HIDDEN** | 0.18 | **SINGLE full corner-to-corner X per braced bay** (NSW corner ↔ FSW corner) — *not* a bowtie. Braced bays = 2nd & 2nd-last (`peb-braced-bays`). |
| 7 | **BRACED BAY label** | `pics/08_braced_bay_text.png` | `SECONDARY` | **magenta 6** | Continuous | 0.13 | Vertical text "B R A C E D   B A Y", centred in each braced bay. |
| 8 | **Dimension chain — length** | `pics/03_dimension_chain.png` | `DIM` | magenta **6** | Continuous | 0.13, **arch tick** arrows | Top chain: per-bay values (`5750 5750 6100…`) + overall note "BUILDING LENGTH: `<L>` CENTER TO CENTER OF STEEL COLUMN". Basis = C/C steel. |
| 9 | **Dimension chain — width** | `pics/10_width_dim.png` | `DIM` | magenta **6** | Continuous | 0.13, arch tick | Left vertical chain: module values (`6200 6200`) + "BUILDING WIDTH: `<W>` C/C OF STEEL COLUMN". |
| 10 | **FALL marker** | `pics/06_fall_marker.png` | `FALL` (symbol) + text | **red 1** symbol, white **7** text | Continuous | 0.13 | Red pentagon-house glyph + vertical "FALL" + small slope arrow. One per roof slope, each end zone. |
| 11 | **Area tag** | `pics/07_area_tag.png` | `AREA` | white **7** box + text | Continuous | 0.13 | Boxed "AREA-0N" at each area centre; red centre-line passes through. One per IF area. |
| 12 | **Crane beam + symbol** | `pics/09_crane_beam.png` | `CRANE` | grey/white | Continuous | 0.13 | Runway line at mid-width + crane bridge symbol + "CRANE RUN: `<span>`" / "`<cap>` Crane". Only if IF has crane. |
| 13 | **Leader labels (MLEADER)** | (in 04) | `LEADER` / `TEXT` | white **7** | Continuous | 0.13, filled arrow | BEARING FRAME BOTH ENDS · CRANE BEAM · RIDGE LINE · CL OF RAFTER · CAGE LADDER · LOW ROOF · HIGH ROOF · NEAR SIDE WALL · LEW · CROSS BRACING (TYP.). Positioned relative to grid/wall. |
| 14 | **Title-block strip** | `pics/11_title_block_strip.png` | `TitleBlock` | white **7**, border **4** | Continuous | border 0.50 | Vertical right-edge Mammut strip: General Notes · design-load table · project/customer/quote — all IF-linked. |
| 15 | **Sheet title** | `pics/12_sheet_title.png` | `TITLE` | **blue 5** | Continuous | — | "COLUMN LAY-OUT PLAN", large, centred under the plan (also echoed in the strip's Drawing Title). |

## Master scales (from the parent DXF header)
- `$LTSCALE = 1200`, `$DIMSCALE = 275`, default text style `romans.shx` (Mammut uses `ROMAND` for some labels).
- Lineweights above follow the canonical clean set in `EXTRACTED_LISP_DB.md` (Mammut's own file plots via pen table, so its per-layer lineweights read as "default").

## Corrections this DataBase forces on the current engine
1. **Grid bubble**: change CIRCLE → **PENTAGON** (green outline, red number).
2. **Cross-bracing**: revert bowtie → **single full corner-to-corner X** per braced bay.
3. **Dimensions**: colour **magenta**, basis text "CENTER TO CENTER OF STEEL COLUMN" / "C/C OF STEEL COLUMN".
4. **Grid lines**: **CENTER (dash-dot)** linetype.
5. **FALL**: red pentagon-house glyph + "FALL" text (engine currently uses big green arrows).
