# PD RULEBOOK — the organized single source for Proposal Drawings

**What this is.** Every rule that governs Proposal Drawings (PD), organized into one
numbered hierarchy, with the **BSF ↔ PD sync contract** as a first-class section. This is
the authoritative rulebook. Two backing docs hold the granular detail this rulebook points
to — don't restate them, link them:
- **`PD_MASTER_REFERENCE.md`** — the LSP code/function index + the full per-key **trigger
  matrix** (every BSF field → key → bridge line → engine reader → sheet → status) + the
  coverage ledger.
- **`DRAWING_CONTENT_RULES.md`** — the per-sheet element-ownership matrix.

**Terms.** **IF** = Inquiry Form · **BSF** = Building Specification Form (the single source
of truth — a second front-end view over the same inquiry/building/area DB rows the IF
writes) · **PD** = Proposal Drawings. **Read any "BS" as BSF.**

**Status.** 21-Jul-2026, code-grounded (file:line). Supersedes `PD_GLOBAL_RULES.md`.

### The pipeline (one picture)
```
 IF / BSF form ─ writes DB ─►  services/drawingData.ts ─ writes ─►  MAIMAAR_PEB_*.lsp ─►  DXF/DWG/PDF
 (inquiry/building/area rows)   serialise · ×1000 mm · tick-gate      peb-v3-to-legacy →
        │                        · silent defaults · instance-cap     MSPL-Get-* → drawers
   ONE truth (DB row)           PEB_Data_B<n>_A<m>.txt (flat KEY=value)
```

---

## 1. FOUNDATIONAL RULES (PD ↔ the other modules)

**1.1 — BSF is the single source of truth; PD only derives.** The BSF is not a separate
store; it is a view over the same DB rows the IF writes. The row is the truth. PD never
recomputes, re-defaults, or infers geometry — it draws what the row says. *(drawingData.ts:688-696)*

**1.2 — The BSF tick is THE gate.** Only components/sections ticked in the BSF are
serialised and drawn. Unticked = excluded, never deleted. *(sectionSelection.ts; drawingData.ts:693)*

**1.3 — One bridge, one exporter.** The only sanctioned path from BSF to engine is
`drawingData.generate()`, which replaced the legacy `Maimaar_PEB_Input.xlsm`. No hand-made
data files, no second serialiser. *(drawingData.ts:1-4, 676-991)*

**1.4 — PD is geometry-only.** Prices and QE weight never cross into the drawing.
Commercial header fields (currency, payment, validity, delivery, sales rep) ride the data
bundle as title-block text but PD does not draw them. *(drawingData.ts:179-186)*

**1.6 — THE GOLDEN RULES FOR PLACING A DRAWING ON A LAYOUT.**

> *"make the Golden Rules for Place of Drawings in the layouts — 1 - Only one relevant drawing
> must go in one layout, 2 - Drawings must be placed in the center of the Box, 3 - Right Side
> Title Block must have the Information about that Page Drawings."* — owner, 30-Aug-2026

Stated by the owner as **primary rules**, so they sit here and not among the drafting rules: they
outrank them, and they are the acceptance test every sheet must pass before anyone looks at the
drawing on it.

**1.6.1 — ONE RELEVANT DRAWING PER LAYOUT.** A layout shows its own sheet and NOTHING ELSE.
Every sheet is drawn into ONE shared, tiled model space, so a viewport is a *window* onto it: it
cannot exclude a neighbour that overlaps it. "Its own frame" is therefore a property of the
TILING, not of the layout, and only measuring catches a breach — which is how the COVER came to
be inside `PRO-01 COLUMN LAYOUT PLAN` on MSPL-26-278.

**1.6.2 — CENTRED IN THE BOX.** The view centre equals the sheet's own bbox centre, and the
viewport rectangle sits at the drawing box's centre (115.32, 105). Both, always.

**1.6.3 — THE RIGHT-HAND TITLE BLOCK DESCRIBES THAT SHEET.** Every field in the strip is either
**true of this sheet** or **not printed**. The drawing title, its PRO number and its scale come
from the same three values the layout itself was built from — never a default, never the previous
sheet's. See **4B.54**, which is this clause applied to the bands.

**How they are enforced.** 4B.28 says how to PROVE 1.6.1 and 1.6.2, and 4B.29 gives the placement
arithmetic; 4B.7 is 1.6.3's older, narrower ancestor (*the table must not contradict the drawing*).
What was missing until 30-Aug is that nobody ran the proof — a rule that is true and unenforced is
worthless. The render now records what each sheet DREW (`_bbox.txt`) and what each tab actually
SHOWS (`_vpview.txt`, DXF groups 12/45 read back off the finished viewport), `checkGoldenRule`
measures both, and a DWG that breaks either is left on disk to be looked at but is **NOT filed into
the proposal folder** — filing is what turns a bad render into something a customer sees.

**1.5 — One area = one file; one building = one drawing.** Serialiser emits
`PEB_Data_B<building>_A<area>.txt`; a building's areas tile into one drawing; each building
is its own DXF/DWG. Identity lives in the filename + `[META]`. *(drawingData.ts:734-778)*

---

## 2. THE BSF ↔ PD SYNC CONTRACT

**2.1 — Units: metres in, millimetres out.** The BSF/IF stores metres; the wire is always
mm. The bridge multiplies every length and spacing ×1000. Pass-through exceptions: stair
widths, crane loads, free-text ("As per Design"). *(drawingData.ts:31-98)*

**2.2 — Slope is a `rise:run` ratio, never degrees** (`1:10`, `1:20`). *(engine SLOPE via peb-slope-to-denom)*

**2.3 — Ridge offset is measured from the NSW; blank = centred.** Butterfly/canopy valley
uses `BP_CANT_SPAN` instead of the ridge offset. *(drawingData.ts:218-226)*

**2.4 — "Blank" ≠ "0".** `0` = "none"; blank = "engine default". Not interchangeable —
the distinction changes the drawing. *(drawingData.ts:48-50)*

**2.5 — Wall codes are fixed:** NSW = near (bottom, y=0) · FSW = far (top) · LEW = left-end
(x=0) · REW = right-end. Every per-wall family (`OW_ FA_ RX_ CN_`) keys off these four.

**2.6 — Booleans are the literal strings `Yes` / `No`** (not 1/0). *(yn(), drawingData.ts:36-41)*

**2.7 — The wire is flat `KEY=value`, order-agnostic.** The reader skips blank lines, `;`
comments and `[SECTION]` headers — only key names matter, order is irrelevant.
*(peb-v3-read-file, Section.lsp:57-74)*

**2.8 — The engine re-translates before drawing.** `peb-v3-to-legacy` rewrites raw BSF keys
(`HD_/BP_/DL_/PN_/OW_`) into legacy names (`PROJECT/LENGTH/WIDTH/STYPE/CLEARHEIGHT/…`) and
passes `PL* BR* RM* CR*` through verbatim. Full translation table → `PD_MASTER_REFERENCE.md §2.2`.

**2.9 — Silent defaults can print un-entered values.** A blank BSF field can be defaulted
twice (bridge, then engine) and still print a confident value. If it must be right on paper,
set it in the BSF. Load-bearing ones: MZ_JOIST 1250, ST_WIDTH 1200, CR_CAP 10, DL_LIVE 0.57,
DL_RAINFALL 120, wind 135, slope 1:10, seismic 2b, design code MBMA 2006. Full list → `PD_MASTER_REFERENCE.md §4d`.

**2.10 — The raw data bundle is admin-only.** Users get finished DXF/DWG/PDF; only admins
pull the raw `.txt` bundle for debugging. *(sales.ts:514/536/557/581)*

---

## 3. WITHIN-PD DRAWING-GENERATION RULES

**3.1 — The shipped proposal set is EXACTLY three sheets: Cover · Column Layout Plan ·
Cross-Section.** Framing and elevations are removed from the shipped set; their engines are
complete and runnable on demand but excluded from `peb-all-sheets`. *(Standard.lsp:415)*

**3.2 — Load order: Standard → Section → Plan → Cover.** Standard loads first (primitive
library + standards + orchestrator) and draws nothing itself. *(Cover.lsp:11-15)*

**3.3 — The Column Layout Plan is the master grid.** Numbers run along the length (bays),
letters across the width (frames). Every sheet derives from the same data with the same
algorithms so grids register. Move a bubble on the CLP and it moves everywhere.

**3.4 — Every element belongs to exactly one sheet** (no element on two sheets). Summary:
- **Column Layout Plan** — grid, columns, bracing, all structural footprints (mezz/crane/
  partition/stairs/canopy/roof-ext/fascia/monitor), wall-opening footprints, dimensions.
- **Roof Plan** — ridge/valley, gutters/downspouts, purlins, **and all roof accessories**
  (skylights/vents — moved off the CLP, enforced Plan.lsp:1561).
- **Wall Elevations** — wall cladding, clad openings, girts, wall condition, wall bracing.
- **Framing Elevations** — bare steel + base plates (NO cladding — the discriminator).
- **Cross-Section** — frame profile, connection plates, the **full sheeting/insulation spec**,
  heights, mezz/crane-in-section.
- **Cover** — title/index + LIST OF DRAWINGS.
- **Deliberate shared exception:** the FALL/slope glyph is drawn identically on both the CLP
  and Roof Plan by one shared routine (owner 7-Jul) — intentional, not duplication.
- Full ownership matrix → `DRAWING_CONTENT_RULES.md §7`.

**3.5 — Structure type is a short STYPE code** (from the frame-code map): CS clear-span ·
SS single-slope · MS multi-span · LT lean-to · MG multi-gable · FR flat · F2 flat G+1
(auto when a flat roof has a mezzanine) · RC roof-on-RCC · ACS/AMS arched · BF butterfly/
falcon · CC cantilever canopy · PP petrol-pump. **"Poultry" is a reference example, not an
STYPE.** *(Section.lsp:117-147, 7324)*

**3.6 — Components are STYPE-independent overlays, dispatched by toggle**, in a fixed order
(mezzanine before stairs so `ST_IN_MEZZ` can anchor): **canopy → mezzanine → stairs →
roof-ext → fascia → monitor → partition → crane**; roof accessories are dispatched by the
Roof engine, never the Plan. *(peb-draw-components, Plan.lsp:2079)*

**3.7 — ALL text is `romand.shx`; dimension arrowheads are OPEN** (owner 19-Jul). The
Arial/`romans.shx` literals in Standard.lsp are overridden at runtime — ignore them; only
the bold company name is Arial. *(Plan.lsp:3901-3904)*

**3.8 — Dimensions are standardised:** DIMTXT/DIMASZ 600, DIMEXE/DIMEXO 100, DIMGAP 10,
whole millimetres (DIMDEC 0). Text ladder SMALL 50 / DIM 56 / ANNOT 300 / HEADING 320 /
LABEL 400 / TITLE 450. *(Standard.lsp:121, 150)*

**3.8b — Dual display is UNIVERSAL: every dimension shows BOTH mm & ft-inches** (e.g.
`60957 [200'-0"]`), on EVERY sheet. The Section is always dual (`dim-mm-ft` → `DIMALT`
architectural feet-inches). The Column Layout Plan matches it: `*PEB-DIM-DISPLAY*` defaults
to `MMFT`, and both the labelled dims (`peb-fmt-value`) and the bay/module chains
(`peb-fmt-group`) read that one global (owner 21-Jul, Plan.lsp:3643). Only an explicit
`BP_DIM_DISPLAY = "Only Ft"` forces ft-only; `mm` / `mm & Ft` / blank all render BOTH.

**3.9 — Layers come from the Rule Book CSV**, not the fallback. `PEB_LAYERS.csv →
_PEB_LAYERS_generated.lsp` overrides Standard.lsp when reachable. Fixed conventions: columns
red 0.50, grid grey centre 0.09, ridge blue hidden 0.18, RCC hatched ACI32, bracing cyan
dot 0.18, working line 0.09. Hatch: RCC→AR-CONC, brick→AR-B816, existing/future→ANSI31.

**3.10 — Connections = two solid plates, no bolt circles.** Each plate 30 mm, 1.5 mm seam,
extending 100 mm past both flanges (length ≥ web+200); gussets solid-filled within that
100 mm. *(*PEB-CP-THK/GAP/EXT*, Section.lsp:3665-3667; see 4B.52 for a column in the middle of the frame)*

**3.11 — Purlins and sheeting follow the real rafter line — never flat.** A purlin at each
eave and under every gutter; interior purlins 1.25–1.50 m; canopy/arched purlins full 200Z15.
Default cladding when blank = 0.50 mm AZ 150. *(Section.lsp rules 0, 9)*

**3.12 — Steel member sizes come from the compiled Rule Book**, not magic numbers: column
depth = span/27, flange 0.4×D, web 0.026×D, etc. *(*PEB-RULES*, _peb_rules.lsp)*

**3.13 — Width has a fixed steel-line correction:** internal frame geometry = input width −
470 mm (sheeting line → steel line). *(Section.lsp:7317)*

**3.14 — The engine accepts v3 files only** and hard-aborts otherwise. *(MSPL-Read-Data, Section.lsp:663)*

**3.15 — Output: DXF (dev) / DWG (prod); multi-page PDF via plot-and-merge** (`C:MSPLPDF`,
`merge_pdfs.js`).

---

## 4. HEALTH / COVERAGE RULES (so nothing is missed to trigger)

**4.1 — Dead triggers (emitted by the bridge, no engine reader — grep-verified):**
- **`RM_CONSTRUCTION_TYPE`** — ✅ **FIXED 21-Jul**: the bridge now emits `RM_CONSTR` to match
  the engine reader (Section.lsp:6707), restoring the roof-monitor construction type.
- **`BP_VALLEY_HEIGHT`** — 0 engine refs. Reclassified to §4.2: the estimator enters a valley
  height, so it should be *wired into the butterfly geometry*, not silently dropped.

**4.2 — Should-draw-but-doesn't (review):** `BP_COL_WEB_STYLE` (drawing always tapers even
if "Straight Web" is chosen), `BP_EXT/INT_BASE_COND` (pinned-vs-fixed base plate not drawn),
`BP_EAVE_TYPE`/`BP_GABLE_TYPE`. Decide: honour in the drawing, or drop the field.

**4.3 — Read-without-writer:** the engine reads `BP_GROUND_CH`/`BP_FIRST_CH` (F2 double-storey)
and `MZ_OFFSET_FROM/TO` that the bridge never emits → silent engine default. Wire if exactness matters.

**4.4 — Maintainer rules.** (a) **Universal-core rule:** the data reader, `MSPL-*` accessors,
frame-code map and BSF→legacy translation must behave identically for every sheet. They are
currently **copied** into Plan.lsp AND Section.lsp and **have already drifted** — until the
shared-`_peb_core.lsp` refactor lands, any edit to one MUST be mirrored in the other. Audit +
canonical union + extraction spec → `PD_MASTER_REFERENCE.md §6`. (b) Standard.lsp's fallback
layers/fonts are superseded at runtime — not the source of truth. (c) Roof/Elevation/Framing
are excluded from `peb-all-sheets` — wire in only on an owner call. Full coverage ledger
(dead/defaulted/unemitted, with every field) → `PD_MASTER_REFERENCE.md §4`.

---

## 4B. PRESENTATION RULES (how a sheet must LOOK)

Established 26-Aug-2026 from an owner review of MSPL-26-271. Section 3 governs what
is drawn; this section governs how it reads on the paper. Every rule here exists
because the sheet failed it.

### 4B.1 Scale text from the SHEET, never from the building
`*PEB-TEXT-SCALE*` drives text, dimension text and grid-bubble size. It must be
derived from the widest drawing **on that sheet**, not from the building's longest
dimension:

| sheet | scale from |
|---|---|
| end-wall set (LEW/REW) | `WIDTH` |
| side-wall set (NSW/FSW) | `LENGTH` |
| all four on one sheet | the larger of the two |

*Why:* it used to be `max(LENGTH, WIDTH)/45000` regardless of the wall shown, so the
end-wall sheet of a 122 x 30 m shed got text sized for 122 m on a 30 m elevation —
bubbles ~4x oversized, bay figures colliding into `6,0966,096`, and because ZOOM
Extents must then fit that text, the frame itself was squeezed small. One cause,
three complaints. (`peb-draw-elev-set`)

### 4B.2 Never pre-multiply a text height by the text scale
`txt`, `txt-bold` and `txt-rom` **already** multiply the height by `*PEB-TEXT-SCALE*`.
Passing `(* 500 *PEB-TEXT-SCALE*)` scales by TEXT-SCALE **squared**. At TS≈1 nobody
notices; at TS≈3 the item comes out 9x instead of 3x. Pass the plain height.
*Symptom:* the wall heading grew with building size until it ran the full width.

### 4B.3 A flange is a flange
Member sizes that do not scale with span must not be derived from ones that do.
Column flange width in elevation: **200 mm end wall, 300 mm side wall** — fixed.
*Why:* deriving it from the web depth drew 506 mm columns on a 30 m building, fatter
than the 200 mm rafter web beside them, which made the rafter look too thin. The
rafter was right; the columns were wrong.

### 4B.4 One box per sheet
The title block already frames the sheet. Nothing else may draw a second rectangle
around the drawing — in particular the `MVIEW` viewport must sit on a **no-plot**
layer (`PEB-VPORT`), so it frames and scales the view without its outline reaching
the paper.

### 4B.5 A dotted linetype must be drawn at TRUE size
Any dashed/dotted line (bracing, ridge line, crane runway) must carry a per-entity
linetype scale of `1/LTSCALE` (DXF group 48). *Why:* the sheet set leaves LTSCALE at
~84 — the PLAN sheet raises it from 1.0 and `peb-std-setup` does not restore it — and
at that scale the CROSS layer's DOT pattern stops rendering, so the wall X-bracing
was drawn correctly and simply never appeared on the plot.

### 4B.6 A label must not land on geometry
A callout placed at a fraction of some dimension must have a fallback for when that
dimension is zero. *Symptom:* `DOWN PIPE` is placed at half the brick height, and a
fully-sheeted wall has `brickH = 0`, so it printed on the FFL line and the ground
hatch.

### 4B.7 The table must not contradict the drawing
A title-block row must carry what its label says. `EAVE HEIGHT` carried
`CLEARHEIGHT` verbatim while the section beside it dimensioned the same number as
CLEAR HEIGHT. An eave height is `clear + haunch depth + purlin depth`
(`peb-tb-eave-height`).

### 4B.8 Every sheet must name a grid line the same way
Plan, section and both elevations letter the SAME merged width grid — width-module
lines plus end-wall columns (`peb-fr-ew-stations`). A clear span reads A..D on all
four sheets, not A/B on some and A..D on others.

---

### 4B.9 The text-height ladder IS the standard — every sheet reads it

`*PEB-TEXT-HEIGHTS*` in `MAIMAAR_PEB_Standard.lsp` is stated in **millimetres of
paper**, not model units. Every view is fitted to about 163 mm of paper width and
`*PEB-TEXT-SCALE*` is `faceMax / 45000`, so a height handed raw to `txt` /
`txt-bold` plots at `h x 163/45000 = h x 0.0036 mm` — the same on a 14 m shed and
a 122 m shed.

| entry | paper | used for |
|---|---|---|
| `SMALL` 550 | 2.0 mm | marks, leader tails, minor notes |
| `DIM` 700 | 2.5 mm | dimension text (also `DIMTXT`, since `DIMSCALE` = `*PEB-DIM-SCALE*`) |
| `ANNOT` 830 | 3.0 mm | nomenclature: RIDGE LINE, VALLEY GUTTER, slope tags, member marks |
| `LABEL` 970 | 3.5 mm | sub-headings |
| `HEADING` 1400 | 5.0 mm | the view heading under each drawing |
| `TITLE` 1650 | 6.0 mm | sheet title |

**Never hard-code a text height on a sheet.** Before this rule only three call
sites in the whole engine used the ladder — every sheet carried its own numbers,
which is exactly why the Roof Framing Plan's heading was a third the size of the
one on the sheet beside it (owner 26-Aug: *"headings and bubbles and other
supporting nomenclature must match with other drawings"*).

### 4B.10 Annotation is sized for PAPER; only crowding is sized for the drawing

Two different masters, and mixing them up breaks the sheet in opposite directions:

* **How big it prints** comes from `*PEB-TEXT-SCALE*`. Leave that invariant alone.
  A first pass at the oversized-bubble complaint capped the radius against the
  *wall height*, which threw the invariant away and plotted a 2.6 mm bubble —
  unreadable (owner: *"it should not be too small or too big"*).
* **Whether it collides** is a **bay fraction**, which is scale-invariant, so it
  reads the same on paper as in the model. That was the real fault on the 122 m
  wall: sixteen bays at 15.8 mm of paper each with a 10.6 mm bubble in every one.

`peb-bub-radius` therefore takes the paper-constant `1100 x TEXT-SCALE` (~8 mm
diameter) and caps it at **30% of the tightest bay**. `peb-fr-dimchain` does the
same for its numbers. Use `peb-min-spacing` to get the tightest bay.

### 4B.11 Overall dimensions carry metres AND feet, on one line

Every sheet that shows an overall extent shows total **length / width / height**
through `peb-dim-mft`, e.g. `121.92 M (400'-0")` (owner 26-Aug). Bay chains stay
in mm per General Note 1 — this is the overall only, which is the number a
customer reads off the sheet.

Draw it with `peb-fr-overall-h` / `peb-fr-overall-v`, **not** `DIMLINEAR`. A
native dim runs its extension lines from the definition points all the way to the
dim line; the overall line sits below the bay chain and the grid bubbles, so on
B-03 that was a pair of 17.5 m verticals straight through both of them. The
hand-rolled bar also matches the bay chain above it by construction.

### 4B.12 The two roof sheets are a matched pair

**Roof Framing Plan** carries the steel: purlins along the length, roof bracing
panelised by the engineering rule, ridge/valley lines, falls.
**Roof Sheeting Plan** carries the cladding: sheeting runs **down-slope** (across
the width, repeating along the length at the panel cover width), the falls tagged
**on top**, and skylights.

The run direction is deliberately perpendicular to the framing plan's purlins so
the two sheets can never be mistaken for one another at a glance.

Skylights, turbo-vents and roof openings come **from the BSF** (`RA_SKYLIGHTS`,
`RA_TURBOVENTS`, `RA_ROOF_OPENING`) via `peb-draw-roof-accessories`. One source, no
second opinion: if the BSF declares none, the sheet draws none. **`RA_SKYLIGHTS` now
reads the `roof_accessory` COMPONENT first** (the column is only a fallback) — see
4B.55 for why the old column-only read let a job be billed for 16 and drawn with 0.
The **roof monitor** is drawn here too, for the same reason (4B.55).

Both sheets belong in the **PDF** set and the **DWG** tab set. They were in the
DWG path only (behind the draft-sheets gate) and the sheeting plan did not exist
at all, so the PDF the customer received had no roof sheet in it.

### 4B.13 ONE fall glyph on every plan-type sheet

`peb-fall-glyph-set` is the single source of truth for the roof fall, and it must be
what draws it on the **Column Layout Plan**, the **Roof Plan**, the **Roof Framing
Plan** and the **Roof Sheeting Plan**. Never let a sheet roll its own.

The Roof Framing Plan and the Roof Sheeting Plan used to call a local `peb-fr-fall` —
a plain line with a two-line **open** arrowhead and a bare `1:10` — so three plan
sheets in the same set showed the same fall three different ways (owner 26-Aug: *"the
same Roof Slope Arrow can be placed for the Roof Sheeting and Roof Framing Plan"*).

The reference sets back the shared glyph, not the local one:

| reference | slope indication |
|---|---|
| MAIMAAR_02 ColdStorage | vertical shaft, **SOLID** filled head, datum tick, text `SLOPE` over `1:07` |
| MAIMAAR_06 KMFoods | same, labelled `SLOPE` |
| REF_09 Roshan | the pentagon glyph `peb-fall-marker` was built from, labelled `FALL` |

All three use a **filled** head and a **labelled ratio**; none uses a bare open arrow.

The glyph reads its ratio from `*PEB-ROOF-SLOPE*`, so a sheet must set that
(`format-slope` on the BSF `SLOPE`) before calling the set. `peb-fall-glyph-set` also
places in **absolute** model coordinates — fine for the roof drawers, which are called
at 0,0 and tiled afterwards by `peb-tile-place`, but it is not `ox`/`oy` aware.

It also skips **braced bays** when choosing where to sit, which is why the glyph never
lands on top of an X-brace.

### 4B.14 EVERY dimension is in MILLIMETRES — feet alongside, never metres

**RULE (owner 26-Aug):** *"ALL DIMENSIONS in all drawings must be in mm not in Meter,
along with Ft wherever required or marked already."*

General Note 1 on every sheet already says ALL DIMENSIONS ARE IN MM, so a metre value
anywhere on the sheet contradicts the sheet's own note. The house format is millimetres,
**comma-grouped**, with feet-and-inches in square brackets:

```
121,920 [400'-0"]          <- overall length
30,480 [100'-0"]           <- overall width
6,096                      <- clear height (no ft needed on a derived value)
```

Use `peb-fmt-value` (honours `*PEB-DIM-DISPLAY*`: `MM` / `MMFT` / `FT`) or `peb-dim-mft`
for an overall dim; both comma-group and both call `peb-mm-to-ft-in`, which carries the
whole-foot rollover so nothing ever prints as `399'-12"`.

**What was wrong.** The overall dims shipped as `121.92 M (400'-0")`, the plan subtitle
read `122 x 30 m`, the brick-height notes read `H=3.05 M`, and the RCC level notes read
`+3.048` — all on sheets whose own note promises millimetres.

**The rule governs DIMENSIONS, not descriptive text.** Two things stay in metres, both
on the owner's call:

* the **plan subtitle** — `122 x 30 m  |  3,716 m2  |  15 BAYS  |  SLOPE 1:10` — is a
  summary *of* the building, not a dimension *on* it. Metres read better there, and it
  is not what a fabricator measures from.
* **area** — `3,716 M2`, and the roof-opening `SQM` note — is not a linear dimension, and
  the proposal itself quotes area (per m² / per sq.ft).

Everything a reader would scale or build from is millimetres.

Do not divide by 1000 to make a drawing label. If a metre value is genuinely wanted for
a customer-facing summary, it belongs in the proposal, not on the drawing.

### 4B.15 ONE answer for the width-grid letter — `peb-width-letter`

**RULE (owner 26-Aug):** *"Sync all the sheeting, especially the grid lines, with each
other."* Every sheet that letters the width asks **`peb-width-letter i nSt`** — never its
own `(chr (+ 65 i))`.

The **Column Layout Plan is the reference**. It letters the width **reversed**: `A` at the
FAR side wall (y = width), the last letter at the NEAR side wall (y = 0). `peb-width-letter`
reproduces that, skips **I** via `peb-grid-letter`, and carries `*PEB-GRID-LET-OFS*` so the
grid continues across areas.

Audited on B-03 (width 30,480) — letter at `y=0` / `y=30,480`:

| sheet | before | after |
|---|---|---|
| Column Layout Plan *(reference)* | F / A | F / A |
| End Wall Framing | F / A | F / A |
| End Wall Sheeting | F / A | F / A |
| Cross Section | **A / F** | F / A |
| Roof Framing Plan | **A / F** | F / A |
| Roof Sheeting Plan | **A / A** | F / A |

Three sheets in one set lettered the same building back to front, and the Roof Sheeting
Plan printed **A at both eaves** because it resolved the merged grid *between* the two
bubbles, so the first one always hit the literal fallback. **Resolve the merged grid
before drawing any letter that depends on it.**

Length numbering uses the matching `peb-fr-grid-label` (see 4B.8), which applies
`*PEB-GRID-NUM-OFS*` so a match-line part keeps its true grid numbers.

**Check it like this** rather than by eye — pull the single-capital texts on a `GRID`
layer out of each sheet's DXF and compare the lowest/highest station:

```
letters = [t for t in dxf_texts if re.fullmatch(r'[A-HJ-Z]', t.s) and 'GRID' in t.layer]
```

### 4B.16 SHEETING PROFILE DETAILS — one page, both panels, sourced numbers

**RULE (owner 26-Aug):** *"There should be one page of detailed sheeting sections — in
case of Standard S Profile its profile details should be shown; in case of seamlock,
BOTH standard for walls and lockseam for roof shown in the same drawing ... for customer
understanding."*

One page per building, drawn by `peb-sheeting-details-from-file`. It always shows the
**ROOF** panel and the **WALL** panel as separate details, so a lock-seam roof over
standard walls stands side by side; when they are the same product the pair confirms it.

**Every dimension is sourced — none invented:**

| what | value | where it comes from |
|---|---|---|
| Standard S profile | 35 mm rib, 250 mm pitch, 1000 cover | the BSF's own option name, `panelDefaults.js`: *Standard S Profile 35-250* |
| Lock seam | 460 mm effective cover, concealed clip fixing, no face screws | `estimation/quickest/cladding.ts` — 1219 coil slit to 2 × 610, roll-formed to 460; the same figure the estimate prices |
| material / thickness / finish / colour / type | per panel | `PN_ROOF_*` and `PN_WALL_*` off the BSF |

The seam **height** is not carried anywhere in the system, so the seam is drawn to shape
and deliberately left **undimensioned** rather than given a made-up number. The sheet
also carries *"PROFILE SHOWN INDICATIVE — PANEL SUPPLIED PER THE APPROVED DESIGN."*

**Scale.** A ~1000 mm detail needs the small end of the ladder, so `peb-std-scale` now
carries 1, 2, 5 and 10; the sheet sets its own `*PEB-TEXT-SCALE*` (`1000/45000`) because
the usual `faceMax/45000` floored at 0.80 would put 660 mm lettering on a 1000 mm detail.
Keep the whole sheet inside roughly 1000 × 900 so it plots at 1:10 or better.

### 4B.17 A heading is capped by the drawing it titles

`peb-th 'HEADING` is paper-constant (5.0 mm). That is right for a short title and says
nothing about a long one: *"FSW – FAR SIDE WALL SHEETING"* is 28 characters and ran to
roughly half the wall's own width, so the title competed with the drawing (owner 27-Aug:
*"proportionally size is too much"*).

Use **`peb-head-h text faceLen`** for any view heading. It keeps the paper size and caps
it so the heading stays inside ~34% of the drawn width, with a floor at 45% of the ladder
so it can never collapse. Short headings are untouched — `ROOF FRAMING PLAN` was already
inside the cap. Same principle as 4B.10 for bubbles: **size for paper, cap for crowding.**

### 4B.18 A long sheet is cut on a MATCH LINE — roof plans AND side walls

Extends 4B.13. `parts` is computed per building from its own length/width — 1 under 3:1,
2 up to 6:1, 3 beyond — and drives the **roof framing**, **roof sheeting**, **side wall
framing** and **side wall sheeting** sheets. End walls are the building's WIDTH and
already fit, so they stay whole.

Three things the split must get right, each of which was got wrong first:

1. **`*PEB-TEXT-SCALE*` follows the PART, not the building.** Sized from the whole thing,
   a half-sheet carries full-size text; the heading then overhangs the drawing and, being
   the widest thing on the sheet, drives the plot extents and throws away the scale the
   split just won.
2. **Slice BEFORE the mirror** (4B.15's outside-view rule). Slicing in model order keeps
   `pi0`/`pi1` meaning the same physical bays whichever way the wall is later flipped.
3. **Keep the FULL station count** (`pnTot`) before slicing. The "is this edge a cut?"
   test needs the wall's total, not the part's — using the part's count silently drew no
   match line at all.

Measured on B-03: side-wall sheets 51%/54% blank → 20–40%, at 1:350 instead of ~1:600.

### 4B.19 The COLUMN LAYOUT PLAN splits too — and the WIDTH grid never does

4B.18 cut the roof plans and the side walls. The plan is the same 4:1-geometry problem
(B-03 sat at **1:800 and 57% blank**, the worst main sheet in the set), so it takes the
same cut — but it is the hardest of the three, because unlike the elevations it owns the
width grid, the bracing bays, the area marks, the FALL glyphs, the north arrow and the
load table.

Two things are specific to the plan:

1. **Only the LENGTH is sliced. The WIDTH grid is not.** `peb-width-letter` must still see
   the full width station list or the letters change between parts — a 4B.15 regression
   dressed up as a new bug. B-03 reads **A..G on both parts**.
2. **The sub-title still describes the WHOLE building.** `pFullLen` / `pFullBays` are
   captured before the slice, so part 1 of 2 still reads `122 x 30 M | 3,716 M2 | 15 BAYS`
   while its own dimension line reads the part's `65,091 [213'-7"]`. The owner's ruling
   (26-Aug): *"keep the plan sub-title same as before as it is not part of the drawings."*

Grid NUMBERS stay TRUE across parts via `pOfs` — B-03 reads 1..9 then 9..16, sharing the
cut station. Measured: **1:800 → 1:450**, and the set goes 14 sheets → 15.

### 4B.20 Two labels that have to be told where the dimensions live

Both were found by the 27-Aug audit, both are the same mistake: a label positioned by a
constant that happened to be clear on the fixture it was tuned against.

* **`BEARING FRAME / BOTH ENDS`** was moved inside the building to `(2600*DS, wid + 2200*TS)`
  to get it off the vertical width dim — and landed on the TOP dim stack instead, because
  `yBayDim = wid + 1050*DS` and `yOvrDim = wid + 2100*DS`. It now sits **outside-left and
  above the FSW line**. That lane is clear at every size for a structural reason: the
  length chains are CENTRED so their text never reaches the far left, and the width chains
  live at `y ∈ [0,wid]`, so nothing but a witness line crosses `y > wid` out there.
* **The `CLEAR HT.` area tag** cleared the filled AREA band by ~0.9 mm on the plotted A4 —
  a hairline that reads as a collision. Raised from `0.80*aTxH` to `1.35*aTxH`. Do **not**
  raise it a full line; that lands on `RAFTER` (the note at the tag says so, and it is
  still true).

**The rule:** before you place a label by constant, look up what the dimension ladder
already put there — `dimGap`, `topGap`, `yBayDim`, `yOvrDim`, `gridY2` are all named and
all derive from the scale. A constant that ignores them is a collision waiting for a
different building size.

### 4B.21 A finished drawing files itself into the project's folder

Owner, 27-Aug: *"make the rule to copy the actual drawings of a real project at the
location where I defined — like 271-26-MSPL in
`D:\Sales Department\MSPL\Proposals\2026\271-29-MSPL_Mr. Waqar`."*

`archiveToProposalFolder` (`services/drawingRender.ts`) writes the merged PDF and the
combined DWG into that folder as well as returning them to the browser.

**The folder name is NOT derivable from the proposal number, so it is never constructed.**
`D:\Sales Department\MSPL\Proposals\2026\271-29-MSPL_Mr. Waqar`."*
the middle number is not the year and the customer's name is appended by hand. The rule
therefore SEARCHES `D:\Sales Department\<DIVISION>\Proposals\<YEAR>\` for a directory
whose name starts with the serial followed by a **non-digit** (so `271` never matches
`2710`), and writes only on **exactly one** match. Zero matches means the folder has not
been made yet; several means the serial is ambiguous. In both cases it files nothing and
returns `null`, because guessing here puts a customer's drawings in another customer's
folder. Filing failure never fails the render. Base overridable via
`PROPOSAL_ARCHIVE_BASE`.

**Consequence worth knowing:** renumber an inquiry and the folder stops matching until it
is renamed to the new serial.

### 4B.22 ONE acad session cannot draw TWO Column Layout Plans

Splitting the plan (4B.19) gave the set two plan sheets — and the render then came back
with **only the cover and plan 1 in it**, no error anywhere. acad sat at ~5% CPU until the
600 s timeout killed it, and the merged PDF was silently 2 pages instead of 15.

Isolated to the minimum — two plan sheets back to back in one session, no `peb-add-layout`
and no plot involved — and **the second `peb-plan-part-from-file` never returns**. What it
is NOT, each ruled out by experiment:

* not part 2's geometry — drawing **part 1 twice** wedges identically;
* not the `UNDO BEGIN`/`END` group — commenting the pair out changes nothing;
* not `CMDECHO` / `OSMODE` left dirty by `C:PEB-PLAN` (it exits with `CMDECHO 1`);
* not a modal dialog — the process has no message box open;
* not slowness — it is still wedged after **15 minutes**;
* and plan part 2 **alone** in a fresh session draws in 27 s.

The tail of `peb-plan-from-file` completes (traced), and then acad simply never returns to
its `Command:` prompt, so script playback stops.

This is the same accumulation `renderPdf` already guards against one level up: *"a single
session that draws every sheet ... degrades badly as the drawing accumulates ... a fresh
session per group never accumulates."* So the remedy is the one already proven here rather
than a deeper hunt inside 5,000 lines of LISP: **`splitScrIntoSessions` starts a NEW acad
session rather than draw a second plan in the current one**, with a 12-sheet cap per
session as a general guard. The split is applied to the FINISHED script at sheet
boundaries the emitters mark (`;;__SHEET__|<kind>`), so no sheet's content changes — a
session boundary costs only an acad start.

**If you add another sheet type that turns out not to survive repetition, mark its kind and
add it to the same rule.** And note the shape of this failure: a wedged session produces a
SHORT PDF, not an error. Always count the sheets.

### 4B.23 Tile only against a model space that actually holds something

`peb-plan-from-file` decided whether to tile the new sheet from `(entlast)` — which sees
the WHOLE database, **paper space included**. The PDF pipeline plots one sheet at a time:
`ERASE _ALL` → draw → `peb-add-layout "PLn"` → plot → `-LAYOUT _Delete PLn`. The deleted
layout can leave an entity behind, so `(entlast)` came back non-nil on a model space that
was in fact EMPTY, `EXTMAX` still described the PREVIOUS sheet, and part 2 was moved
**98 m to the right of nothing**.

Test the space you actually tile in — `(ssget "_X" '((410 . "Model")))` — not the database.
`peb-tile-place` is now also wrapped in `vl-catch-all-apply` here, as it already was at
every other `*-from-file` entry point: a tiling failure must not take the finished drawing
down with it.

### 4B.24 The DETAILS sheet shows ONLY what this project actually buys

Owner, 27-Aug: *"only those details must be there which are being used for that particular
project. For example show the profile of lockseam only if it is used in roof, similarly for
sandwich panels — otherwise there will be confusion in scope of work."*

This is a **commercial** rule, not a presentation one. A proposal drawing is part of an
offer. A lock-seam section on a building quoted with standard sheeting, or a sandwich panel
next to a single-skin price, is a scope argument waiting to happen at handover — and the
customer will be holding our own drawing.

**The rule:** every panel on the DETAILS sheet is switched on by a BSF field that says the
thing is in this building. Nothing is drawn "for completeness", and nothing is drawn
because it usually applies.

Already enforced for the sheeting panels in `peb-draw-sheeting-details`:

* `lockR` / `lockW` — a lock-seam section only where THAT face's profile is lock seam.
* `sand` — a sandwich section needs `PN_*_TYPE` to say SANDWICH **and** a core thickness > 0.
* a `profile|type|thickness|material` signature decides same-ness: when roof and wall are the
  same product there is ONE panel titled "ROOF & WALL SHEETING", not two identical ones.

**Extend it to every new panel.** Gutter and downpipe off `gutterType` / `downpipeType`;
skylight off `skylight` / `RA_SKYLIGHTS`; ventilator off `turboVents`; louvre off
`louverType`; liner + insulation off the liner fields. If the field is empty, the panel does
not exist — and the remaining panels grow to fill the sheet (4B.23), rather than a gap being
left where the customer can wonder what was removed.

**The known hole — do not let a fallback become a claim.** The sheeting detail picks its
shape by substring (`LOCK`, `SEAM`, `SANDWICH`) against the BSF's profile text. The
vocabulary is small today (`Standard S Profile` variants and `Lock Seam Profile (roof
only)`), so it works. But an unrecognised profile falls through to the STANDARD S section —
i.e. it draws a definite, wrong product rather than nothing. Under this rule that is the
worst possible failure. If a new profile is ever added to `panelDefaults.js`, either teach
the detail its shape or make it refuse to draw; never let it guess.

### 4B.25 Where the DETAILS sections come from — trace, don't invent

4B.24 says only draw what this project buys. Its twin: **draw it the shape it really is,
or say that you haven't.** Every section on the DETAILS sheet now records its source.

| section | source | status |
|---|---|---|
| Eave gutter | `Jobs59-MSPL_PAECO\Approval drawing\Eave Gutter9-MSPL_Eave Gutter.pdf` | **traced** — 165 base, 203 deep, 3 m. **Thickness is 0.50 mm, NOT the 1.2 on that sheet — see 4B.51.** |
| Lock seam | `Jobs59-MSPL_PAECO\…\Pdf.pdf`, panel "LOCK SEAM SHEET PROFILE" | **traced** — 470 cover, pan 92·10·145·10·91, seams at 119°/148° |
| Sandwich panel | `Jobs584-MSPL_AZ Engineering\…\Pdf.pdf` (same on 202, 205) | **traced** — 920 = 5×184, rib 32×32, flat 106, 16 lap |
| Standard S profile | — | **stylised shape, real dimensions** |
| Valley gutter | — | **not drawn** — stated line only |

**The owner's own filing is the reference library.** He said it: *"check the approval
drawing pdf, it always have the sheeting profile."* Every MSPL approval sheet carries the
panel sections in a right-hand column beside the eave gutter and the skylight — which is
the column this DETAILS sheet is converging on. Look there before drawing anything.

**Two things that are deliberately NOT traced, and why:**

* **The S profile.** ~3,500 approval PDFs across 2024–25 were searched. The profile panels
  that exist are SANDWICH (20), LINER (18), LOCK SEAM (16), SKYLIGHT (9) — the
  **non-default** products. The standard S profile is only ever *named*, never sectioned,
  because it is the house default. There is nothing to trace. Its dimensions (35 rib, 250
  pitch, 1000 cover) are real and are what the sheet labels; only the rib shape is
  stylised, and the code says so. A roll-former datasheet is the source if an exact
  section is ever wanted.
* **The valley gutter.** Only multi-gable jobs take one (owner), and no dimensioned valley
  profile exists in the Jobs tree — only a BOQ of valley trims (job 171). A valley building
  therefore gets an honest line, never the eave section substituted for it.

**The rule:** a section is either traced from a real MSPL drawing, or it is stylised under
correct dimensions and said to be, or it is not drawn. Never a confident guess — on a
proposal drawing the customer is holding, a wrong shape reads as a commitment.

### 4B.26 A balanced file is not a working one — check DEFINED vs CALLED

Replacing a block of LISP by matching "from this defun to the next one" is how three
helpers (`peb-sd-poly`, `peb-sd-eave-gutter`, `peb-sd-known-p`) were deleted on 28-Aug:
they happened to sit between `peb-sd-sandwich` and `peb-sd-panel`, inside the span being
swapped.

**Nothing complained.** The paren-balance check passed — deleting whole `defun`s leaves a
file perfectly balanced. AutoLISP then unwound silently at the first missing call and the
DETAILS sheet plotted as an empty A4 with a correct title block. No error, no warning, a
sheet that looks deliberate.

So balance is necessary and not sufficient. The check that catches it is trivial: collect
every `(defun peb-…)` and every `(peb-… ` call across the engine, and diff them. Run it
after any structural edit:

```
node lispcheck.js MAIMAAR_PEB_*.lsp
→ defined 511 peb-* functions, 283 distinct calls
```

One legitimate hit to expect: `peb-dim-v-native` is called in `MAIMAAR_PEB_Elevation.lsp`
behind `(if (boundp 'peb-dim-v-native) …)` — a deliberate optional call that no-ops when
the helper is absent. Anything **not** guarded that way is a real blank-sheet bug.

**And when replacing a span, anchor on the END of what you mean to replace, not on the
start of the next thing you happen to see.**

**The mirror-image failure, found 31-Aug, and now checked.** Deleting a block from *inside* a defun
can take that defun's own closing parens with it. The function then **swallows every function after
it**: `lispcheck` still lists them as defined — it reads text, not structure — while AutoLISP leaves
them undefined. Deleting a dimension block from `peb-draw-monitor` took the `))` that closed its
`progn`+`if`, and the **skylights, defined 1,100 lines further down, silently stopped existing**. The
sheet rendered: correct border, correct title block, main sheeting, grid, falls — and no skylights
and no monitor. Nothing errored.

A paren count does not find this. It gives one number for a 9,000-line file and cannot say which
function is wrong. `lispcheck.js` now walks every TOP-LEVEL `(defun` and checks it closes **before
the next one starts**, and names the pair:

```
UNCLOSED DEFUN -- it eats the functions after it:
  MAIMAAR_PEB_Plan.lsp:3493  peb-draw-monitor  swallows  peb-draw-partition
```

Nested helper defuns (`tb-get` inside `peb-titleblock-mammut`, `aLn` inside `C:PEB-PLAN`) are
legitimately enclosed by their parent, so only column-0 defuns are compared. The check was verified
by re-injecting the real bug into a copy and confirming it fires.

### 4B.27 Text: one ladder, real bold, and clearances derived from the text

Owner, 28-Aug: *"correct the text issue as it is very important in aesthetic and
professional look of the drawings."* Three separate faults sat behind that.

**1. Every text height comes from `*PEB-TEXT-HEIGHTS*`.** 80 calls were hard-coded — Plan
33, Section 33, Roof 13, Elevation 1 — mostly 190–430, i.e. **0.7–1.6 mm on A4** when the
ladder's floor is `SMALL` 550 (2.0 mm). So `VALLEY GUTTER` and `FALL` printed at a third
the size of `EAVE GUTTER` and `PURLIN` sitting beside them: same class of label, three
different sizes on one sheet. Now 141 ladder-sized calls and **zero** hard-coded.
`textaudit.js` measures it — run it after any text change.

**2. `txt-bold` was a no-op.** `Standard.lsp` states the rule — *"Bold headings = heavier
PEN on romand, not Arial-bold"* — because ALL drawing text is `romand.shx` and an SHX font
has no bold cut. But `txt-bold` only switched TEXTSTYLE to `PEB-TITLE`, and **`PEB-TITLE`
is `romand.shx`, exactly like `PEB-BODY`**. Every "bold" heading on every sheet had been
plotting at the same 0.13 mm as its body text. It now sets `CELWEIGHT 30` and restores it.
*If you add a heading, `txt-bold` is what makes it one.*

**3. THE CLEARANCE RULE — this is the one that keeps biting.**

> A gap that exists to clear TEXT must be computed **from that text's height**, never from
> a number that happened to suit one size.

Both slope drawers placed labels by offsets baked off the old 220 text — `190·s`, `220·s`,
`240·s` are all echoes of it. The height moved onto the ladder; the offsets stayed behind;
the digits landed on the roof sheeting. Same fault in the section's dim columns: the gap
between `BRICK MASONRY` and `CLEAR HEIGHT` exists to clear two **rotated 2-line** texts, so
it is `2.8 × DIMTXT` (two lines plus a gap) — not the `4.0` it was, which spent **2,400 mm,
17% of a 13,720 building**, on white space.

**And a symbol must survive its own geometry.** The slope was a denominator under the
horizontal leg plus a loose `1` beside the vertical leg. At 1:10 that leg is a tenth of the
run, so the `1` had nothing to sit against and the pair read `110`. It is now a single
`1:10` callout placed **above** the triangle, where there is open air at any pitch.

### 4B.28 Every sheet gets a layout, and the layout must be PROVEN to frame it

**Owner, 28-Aug:** *"All Drawings are not placed each page in the layout — only few pages
are placed in the layout. Also the Drawings are not centrally placed in the middle of
layout box — Develop a Rule for It."*

Both complaints were ONE fault, and neither was what it looked like. No sheet was missing:
all ten layouts existed, each with its viewport, each viewport correctly sized and correctly
positioned on the page. What was wrong was where the viewports were **looking**.

**THE RULE**

> A layout's viewport must be verified to be showing its OWN sheet — by number, after the
> fact. Never assume the view was set, because in headless AutoCAD every way of setting it
> fails silently, and one of them fails *destructively*.

**The check.** Read DXF group 12 (view centre) from every layout's viewport. Each must equal
its own sheet's bbox centre. **Identical view centres across layouts is the signature of the
failure** — on B-01 all ten read `229401,11763`, the extents centre of the whole tiled model,
so each tab showed whatever sat at that one spot: two or three sheets looked fine, the rest
came out blank or half off the box. Group 45 (view height) was correct and different on every
tab throughout, which is exactly why the fault was so easy to misread as "missing pages".

**Why it is hard, and what does not work.** A viewport's view can only be changed from
*inside* it, so the viewport must be made current. Headless acad refuses:

| Route | Result |
|---|---|
| `vla-put-ViewCenter` | throws, even once the viewport is current |
| `entmod` of groups 12 / 45 | returns `nil` — both are read-only on a viewport |
| `vla-put-ActivePViewport`, `setvar CVPORT` | *"Error setting current viewport"*, *"variable setting rejected"* |
| `vla-put-CustomScale` | **works** — which is why the height looked right while the centre stayed wrong |

**The cause.** `MSPACE` will not enter a viewport that is flagged *on but fully off screen*
(group 68 = `-1`), and a viewport is off screen when **paper space itself is not looking at
it**. Layouts inherit whatever paper view the previous one left, so this alternated between
sheets for no reason to do with their contents — which is what made it read as random.

**The fix — one line, before the viewport is created:** zoom PAPER space to the whole A4
(`ZOOM W (0,0)→(297,210)`) *before* `MVIEW`. Group 68 then comes up `2` on every sheet and
`MSPACE` steps in. Only then is `ZOOM Center` safe.

**And it must be a verified entry, not a hopeful one.** `peb-vp-enter` returns T only if
`CVPORT` really equals the viewport's own group 69, and the caller zooms ONLY on T. This
matters because the silent failure was also destructive: a `ZOOM` fired while still in paper
space blows the A4 up to model coordinates, so the tab opens apparently empty — that was the
second half of "only a few pages are placed in the layout". The pages were there; the paper
view was 80 m wide.

**Order of the view settings:** centre first (`ZOOM Center` sets centre and height together),
`CustomScale` second — scaling about a centre keeps the centre, so the title block's 1:S is
the scale actually plotted. `DisplayLocked` last, because the DWG goes to a customer who will
scroll it.

### 4B.29 Placement by size — the frame's aspect decides everything

**Owner, 28-Aug:** *"make the universal rules for placement of Drawings based on the sizes."*

**THE FRAME.** A4 landscape, minus 6 mm margin, minus the title strip (63.36 mm) and its
3 mm gap, leaves a drawing box of **218.64 × 198 mm — aspect 1.104**. Every sheet is placed
in that box and nothing else.

**THE FOUR PLACEMENT RULES** (in the order they are applied):

1. **Pad.** Take the drawn bounding box and add 3% all round. `vla-GetBoundingBox` reports
   each entity's own extent, but rotated MTEXT, grid bubbles and edge labels put ink slightly
   past it; without the pad the outermost annotation is shaved by the viewport edge.
2. **Scale = exact fit, rounded UP.** `sc = ceil(max(padW/218.64, padH/198))` — tenths below
   1:20, whole units above. Rounding up guarantees it never overfits; rounding to a whole
   unit keeps a readable scale in the title block and gives away at most 0.5% at 1:200.
3. **The viewport takes the DRAWING's aspect, not the box's** — `padW/sc × padH/sc`. A fixed
   A4-shaped viewport would show extra model in the slack direction, and in the combined DWG
   that means the neighbouring tiled sheet bleeds in.
4. **Centre it.** The viewport is centred on the box centre (115.32, 105) and the view is
   centred on the drawing's own bbox centre. Both, always — see 4B.28, which is about proving
   the second one actually happened.

**THE LAW THAT FOLLOWS — and this is the rule he asked for.**

> How full a sheet looks is decided **entirely by how far the drawing's aspect sits from the
> frame's 1.104**. Not by the building's size, and not by the scale.
>
> **weaker fill = min(A, 1.104) / max(A, 1.104)**,  where A = the padded drawing's width÷height.

This is the fill at the **exact** fit, so it is a ceiling: rounding the scale up (rule 2) then
costs a little more — 0.06% at 1:779, 0.8% at 1:98, most on a detail sheet at 1:9. Measured
across all 27 engineering sheets of MSPL-26-270 (B-01, B-02, B-03) the two agree to within
that rounding. B-03's plan has A = 2.21, so 1.104/2.21 = **49.9%**, which is what the DWG
contains. The binding direction always reaches ~100%; the other one cannot be improved by
rescaling, because scale moves both directions together.

**SIZE BANDS.** With `r` = weaker fill:

| `r` | drawing aspect A | verdict | action |
|---|---|---|---|
| ≥ 80% | 0.88 – 1.38 | good | one sheet |
| 60–80% | 0.66 – 1.84 | acceptable | one sheet |
| **< 60%** | **> 1.84 or < 0.66** | **more than a third of the sheet is empty, and the scale is needlessly small** | **split the drawing across sheets** |

A long building loses twice over: half the paper AND half the scale. B-03's plan prints at
1:779; split in two it would print near 1:390 — the same drawing at double the size.

**THE SPLIT TRIGGER MUST BE MEASURED ON THE DRAWN EXTENT, NOT THE BUILDING.** The 400 ft rule
(4B.19) tests the building's own length. But the sheet is sized by the *bbox*, and dimension
strings, grid bubbles and wall labels sitting outside the steel add roughly a third to it —
B-03's building is under 400 ft, so it never splits, yet its plan bbox is 165 m wide and the
sheet fills 49.9%. Length is a proxy; aspect is the thing that actually governs the page.

**Audit it:** `node scripts/auditSheetFill.js <bbox.log>` (CRM repo) prints aspect, scale and
both fills for every sheet a render captured; feed it a `PEB_DEBUG_BBOX` log. Its arithmetic
is the same as `peb-add-layout`'s and was checked against the viewport dimensions AutoCAD
actually stored.

### 4B.30 One frame is the goal — and splitting into one frame cannot beat it

**Owner, 28-Aug:** *"Even if you split the plan, it should come in one frame (Try) to
develop such rules."*

Tried, and the geometry says it cannot help in the range that matters. Recorded so nobody
spends a day rediscovering it.

Take a drawing of aspect `A` and cut it into `N` equal strips **stacked inside one frame**.
Each strip is `W/N` wide, the stack is `N·H` tall, so:

> **stacked aspect = A / N²**

The reachable aspects are therefore `A`, `A/4`, `A/9` — never anything between. For B-03's
plan, `A = 2.21`: one frame gives 2.21 (fill 49.9%), stacking two strips gives 0.55
(fill 50.1%). **Identical**, because 2.21 and 0.55 sit the same distance either side of the
frame's 1.104 — their product is 1.22, and 1.104² = 1.219.

So stacking only helps when `A/4` lands inside the good band, i.e. **A > 2.6**. Between
1.84 and 2.6 there is a genuine dead zone that no single-frame arrangement improves.

Unequal strips can hit any aspect between `A/2` and `A/4`, but that games the measurement
rather than the sheet: making one strip nearly the whole length leaves the second row almost
empty, so the *bounding box* reports a good aspect while the paper is still half blank.
Fill must be judged on ink, not on the box.

**What this leaves.** Three levers, and only three:

| lever | fill on B-03's plan | cost |
|---|---|---|
| leave it | 49.9% at 1:799 | none |
| two **pages** (each its own frame, aspect A/2) | ~99% at ~1:400 | one extra sheet per split drawing |
| a **wider frame** — title strip along the bottom, box 285 × 135.6, aspect 2.10 | ~95% at ~1:390 | changes the sheet layout |

Two pages and a wider frame are worth about the same. The owner has twice chosen fewer
sheets (*"otherwise there will be too many drawings"*), so **the split trigger stays on
building length at 400 ft (4B.19) and is NOT driven by aspect** — an aspect trigger would
add pages, which is the thing being avoided. The wider frame is the only lever that both
keeps one page and fills it; it is not built, because it changes the presentation standard.

### 4B.31 Grid bubbles: size them to READ, then stagger — never shrink to fit

**Owner, 28-Aug:** *"Grid No.'s and Bubbles in B-03 are not coming in front of post columns
and are more than columns."*

B-03's width grid is the frame lines merged with the end-wall posts:
`{0, 6096, 12192, 15240, 18288, 24384, 30480}`. Every gap is 6096 except two of **3048**,
where the interior frame line at 15240 falls between two posts.

The old rule sized every bubble at `0.48 × the tightest gap in EITHER direction`. On B-03
that is radius 1463 where the building's own text scale asks for 1950 — and it still left
only 122 units between neighbours, **0.16 mm of paper at 1:779**. C, D and E printed as one
merged blob: unreadable, and impossible to count against the columns they belong to.

> **THE RULE.** A grid bubble is sized to be READ — `720 × TEXT-SCALE`, which plots at the
> same size on every sheet because the sheet is auto-fitted. When the grid is too tight to
> hold readable bubbles side by side, **stagger alternate bubbles outward onto a second (or
> third) row**. The stem still runs to the true grid line, so every bubble stays in front of
> its own column. Never shrink a bubble to make room.

Shrinking is the wrong lever twice over: it makes the letters smallest on exactly the big
buildings whose sheets are already at 1:800, and it never actually buys clearance, because
the bubble and the gap shrink together — 48% of a tight gap is still touching.

Two supporting rules fell out of it:

* **Measure the two directions separately.** They shared one `minSp`, so a tight WIDTH grid
  shrank the bay NUMBERS along the top as well, for no reason of their own.
* **Everything outboard of the bubbles moves with the stack** — the FSW label, the LEW
  labels and the symmetric side margin all clear `(rows-1) × step`, or the stagger simply
  collides with the next thing out.

**And a trap worth its own line.** `peb-plan-from-file` declares **`rem` as a local
variable** (the length still to be divided among the bays). Inside that defun `(rem a b)`
therefore evaluates a NUMBER as a function — `; error: bad function: 15240.0` — the plan
unwinds silently, and the sheet comes out as a bare building outline with no dimensions, no
bubbles and no title block. Use `peb-bub-row`, not `rem`. **Never call a built-in that this
file also uses as a variable name** (see 4B.26: the failure has no error on the sheet, only
in the log).

### 4B.32 Mezzanine joists are FLUSH with the main beams, never stacked on them

**Owner, 29-Aug:** *"Joists do not rest above the main beams, joists are flushed with Main
beams. Joist top and main beams top is the same."*

The joists sit **inside the main beam web**, their top flanges level with the main beam's top
flange. One shared plane carries the decking; the corrugation trough lands on that plane.

**THE CONSEQUENCE, and the reason this is worth a rule.** The structural floor zone is

> **max(beam depth, joist depth) + slab**  — NOT beam + joist + slab.

Get that wrong and you over-estimate the floor build-up by a whole joist depth, which reads
as a clear height that will not fit and sends you back to the client to change a tender
dimension that was never in trouble. Worked on MSPL-26-271 (Rainbow): an 8.33 m mezzanine
beam at ~L/20 is ~415 mm, joists within that same depth, plus a 125 mm slab ≈ 540 mm — well
inside the tender's 3 ft (914 mm) between the 16 ft clear height and the 19 ft top of slab.
Summed as if stacked it comes to ~955 mm and looks like it does not fit.

**Already built — do not "fix" it.** `draw-floor-buildup` in `MAIMAAR_PEB_Section.lsp`
implements this: the joist top flange is drawn at the beam top flange line, the joist bottom
flange 300 mm below it inside the web, and the 45 mm decking trough rests on the shared flush
top. The comment there says so in as many words.

### 4B.33 A canopy may end mid-bay — carry it on a beam between the two columns

**Owner, 29-Aug:** *"in case there is no column at the position of canopies end, there will be
a beam connecting b/w the [columns] and the canopy rafter will be cantilever & connected with
beam b/w the both columns."*

A canopy has no columns of its own — it cantilevers off the main frame rafters, with purlins
running along it. So the obvious assumption is that a canopy must start and stop **on frames**,
and that a run which does not divide by the bay spacing has to be squared up to whole bays.

**That assumption is wrong, and it must not drive a canopy's length.** Where the end of a
canopy falls between frames, a **beam spans between the two adjacent main-frame columns**, and
the terminal canopy rafter cantilevers off that beam. The canopy is then free to be whatever
length the architecture wants.

**Consequences to carry:**

* **Never round a canopy to whole bays to make it "fit".** The client's dimension governs.
  MSPL-26-271 (Rainbow) has two entrance canopies at **62'-1" = 2.45 bays**; both keep that
  length, and each has one mid-bay end.
* **Each mid-bay end is a beam spanning one bay between columns** — real steel that no canopy
  field captures, because the canopy component only carries projection, run and grid range.
  Count them: one per mid-bay end, so a canopy landing on frames at both ends needs none, and
  one floating in the middle of a wall needs two.

### 4B.34 Width chains are written from grid A DOWNWARD — the engine reverses them

**Owner, 29-Aug:** *"we always measure the modules from A to downward"* — and, of his own
entry, *"no my dimensions were correct."*

**THE CONVENTION.** Every width chain — the width module and both end-wall column chains — is
written **from grid A downward**, and **A is the FAR side wall**, the top of the plan. That is
how the tender is drawn, how the estimator measures, and how the BSF is filled.

**THE ENGINE DOES THE OPPOSITE**, and must reverse to match. `widthPts` starts at `0.0` and
accumulates `MODULE1, MODULE2 …`, and `y = 0` is the **NEAR** side wall. So the first term of a
written chain lands at the BOTTOM unless something turns it round.

> Everything that builds stations across the width goes through **`peb-width-order`** (a list)
> or **`peb-width-stations`** (an expression). LENGTH chains are untouched — grid 1 is the left
> end in both conventions.

**WHAT IT LOOKED LIKE.** The building was drawn **mirrored across its width**: on
MSPL-26-271 the mezzanine and both entrance canopies appeared against the wrong side wall.

**WHY IT SURVIVED YEARS.** *A symmetric chain reversed is itself.* `2@15240` mirrors to
`2@15240` and looks perfect. MSPL-26-271 is the first job with UNEQUAL width modules
(`2@16662.40 + 16395.70 + 13874.12`), so it is the first time the mirror could be seen.

**THE GUARD, and it is the cheap one:** re-render a SYMMETRIC building and require it to come
back byte-identical. A correct reversal cannot change a symmetric building. Waqar's B-03 is
the standing case.

**MISSING ONE SITE IS WORSE THAN MISSING ALL OF THEM.** The plan's own end-wall stations were
left unreversed at first, so the two width chains ran in OPPOSITE directions; their shared
lines stopped coinciding and every one of them doubled into two grid letters — A..M for a
nine-line grid. Sites that must reverse: the module branch, `peb-main-column-ys`,
`peb-count-wgrid`, the multi-gable widths in **both** Plan and Section, the plan's end-wall
stations, `peb-fr-ew-stations`, the end-wall elevation, and `peb-mezz-col-ys`
(both `MZ_COL_SPACING` and its auto-divide `MODEXPR`).

**Two companions found with it:**

* **A BARE term must still be scaled.** `scaleSpacing` only matched `n@x`, so a single bay
  written without the `n@` — `"2@16.6624 + 16.3957 + 13.87412"`, which the BSF accepts and the
  owner typed — reached the engine in METRES: 13.87412 arrived as 13.87 mm. The engine then
  rescales the chain to close on the width, so ONE unscaled term drags every station with it.
  It printed `1@14 + 1@16396 + 1@16662 + 1@30523`.
* **Merge grid stations at 5 mm, not 1 mm.** Two chains spanning the same width are entered
  independently and each is rounded to whole millimetres on export, so the same physical line
  can arrive a couple of mm apart. The test was `< 1.0`, which exactly 1 mm fails. No two real
  columns are 5 mm apart.

### 4B.35 A sheet shows a component where the PLAN puts it — never by its own heuristic

**Owner, 29-Aug:** *"Section Must Match with Column Layout Plan"*, after
*"Mezzanine Section is not matching with Plan"*.

This is 4B.8 (*every sheet letters the same grid*) one level up: **placement, not just naming.**

> A sheet that draws a placed component — mezzanine, canopy, crane, platform — derives its
> extent from the SAME shared function the Column Layout Plan uses. It never re-derives one.

`peb-draw-mezz-section` had its own: a flat 6% inset off each wall, narrowed only by `MZ1_WID`
— a key the CRM has never emitted, so that branch was dead and the 6% always won. It drew ~88%
of the width, centred, whatever the BSF said, while the plan placed the deck hard against the
FSW. Its stub columns were re-derived too, by subdividing each frame gap at ~6 m, so they did
not stand where the Mezzanine Floor Plan drew them either.

Now: `peb-mz-width-band` for the extent and `peb-mezz-col-ys` for the columns — the plan's own
functions.

**A GLOBAL IS NOT A CHANNEL BETWEEN SHEETS.** `peb-mz-width-band` reads `*PEB-WGRID-YS*`, which
only the PLAN drawer writes and nothing ever clears. `buildPdfScr` emits every area's plan
before any section, so a multi-area job would resolve one area's section against ANOTHER
area's grid — and silently. Seed it from the sheet's own `peb-fr-ew-stations` first, and
unconditionally, so the band agrees with the letters printed beside it.

### 4B.36 The mezzanine sheet shows the WHOLE floor plate — void crossed and named

**Owner, 29-Aug:** *"where there is no mezzanine show the void with crosslines & text"*, and
*"we need to Drawings Beams and Joist Layout Plan as well for Mezzanine Floor"*.

The sheet used to draw only the deck, so a partial mezzanine came out as a rectangle floating
on an empty page — nothing said how much of the building it covered or which end it sat at.
MSPL-26-271's deck is 49.7 m of a 63.6 m width; the missing 13.9 m simply was not drawn.

> Draw the building outline, then every part of it the mezzanine does NOT cover: crossed
> diagonals plus a text label. Up to four bands — either side of the deck across the width,
> either end along the length — each skipped when empty, so a full-footprint mezzanine draws
> exactly as it always did.

**Two placement traps, both found by looking at the sheet:**

* **A minimum size, or the column inset becomes a "void".** The deck stops at the column FACE,
  so between it and the wall line there is half a column web — ~350 mm on the sides the
  mezzanine genuinely reaches. Crossed and labelled, that sliver reads as a missing strip of
  floor that does not exist. The threshold is **1500 mm**: a real void is a bay, not a flange.
* **The label goes near the BOTTOM of the band.** The two diagonals meet at the centre, so a
  centred label is struck through by both. The top is no better — the sheet's own caption
  ("MEZZANINE FLOOR-n LAYOUT PLAN (LEVEL …)") sits directly under the deck, i.e. across the
  top of the void band.

**ROMAND has no em-dash.** `"VOID — NO MEZZANINE"` plotted as `VOID ? NO MEZZANINE`. Use a
plain hyphen in anything the SHX fonts render.

**Beams and joists are already on this sheet** — `peb-draw-mezz-floor-plan` draws main beams,
joists and secondary joists as their top flange to scale, each on its own layer, with the joist
rule following the floor system. A separate Beams & Joist Layout sheet would duplicate them;
if more is wanted it is member tags and spacing dimensions ON THIS SHEET, not a second sheet.

### 4B.37 The CROSS SECTION is viewed from the other side — grid A on the LEFT

**Owner, 29-Aug:** *"Section should be shown from other side by rotating it and keep the Grid
Line A on Left Side"*, *"start the Grid from A to J then"*.

The section is built in the PLAN's own width direction: section `x = 0` is the NEAR side wall
(plan `y = 0`, the NSW). But the plan letters the width from the FAR side wall — `peb-width-letter`
maps station `i` to letter `nSt-1-i`, so **grid A is the FSW**. The section therefore came out
lettered **J..A left-to-right**: the same building, read back to front against every other sheet
in the set.

**Mirror `cols` and `ridges`, once, at the `compute-section-layout` call site — nowhere else.**
Every piece of section geometry is derived from those two lists: frame outline, interior columns,
purlins, the module dimension chain, the grid bubbles. Mirroring there flips all of it together
and nothing can be missed.

The two alternatives are both worse:

* **Mirroring the finished sheet** (a `MIRROR` on everything drawn since the sheet mark) flips
  the title block and the section's data table with it, and `MIRRTEXT 0` keeps each string
  readable but keeps its *handedness* — left-aligned notes walk back INTO the frame.
* **Mirroring inside each drawer** is a dozen separate chances to miss one. That is exactly how
  the width chain came to be half-reversed — see **4B.34**, where one un-reversed site produced
  thirteen grid letters for a nine-line grid.

**Mirroring about the building's own centre leaves the bounding box identical**, so the frame,
the tiling (`peb-tile-place`) and the A4 viewport fit are all unaffected — the sheet fill does
not move.

**From that line down, x is SECTION space. Anything consulting a PLAN-space list un-mirrors at
the point of use** — and there are exactly two:

* **Grid letters.** `peb-sec-grid-letter` matches `cx` against the merged width grid
  (`peb-fr-ew-stations`, plan space), so the call passes `(- wid cx)`. `peb-width-letter` then
  still returns A for the far side wall — which the mirror has just placed on the left.
* **The mezzanine band.** `peb-mz-width-band` and `peb-mezz-col-ys` both answer in plan
  coordinates. Keep the plan-space pair (`pb0`/`pb1`) for the column-station call, and carry the
  band across as `x0 = wid - pb1`, `x1 = wid - pb0` — **the two ends swap**: the far edge of the
  band becomes its near edge.

**The crane code was already written for this.** Its comment reads *"section grid letter A =
LEFT col = cols[0]"* — it had assumed the corrected orientation all along, and was quietly wrong
until this rule landed.

### 4B.38 A mezzanine is read on TWO clear heights — under it and over it

**Owner, 29-Aug:** *"Show the dimensions from FFL to Bottom of Mezzanine Beam (Clear Height) and
Also Show the Height from FFL of Mezzanine to Bttom of Rafter at Haunch as well."*

The section already dimensions the BUILDING's clear height on the outside. What it never showed
is the pair the mezzanine itself creates, and those are the two figures a customer actually buys
a mezzanine on: the headroom **under** the deck and the headroom **over** it.

**Both are taken from geometry the mezzanine drawer has already built, never re-derived** — that
is 4B.7 applied inside a single function:

* **Under** = `MZ1_CH_FFL_BEAM`, the beam bottom the whole floor build-up was stacked from.
* **Over** = top floor's slab top → `H - ht`. `H` is the rafter TOP at the haunch and `ht` the
  haunch depth, so `H - ht` is the underside — **the same expression `C:PEB-SECTION`'s own CLEAR
  HEIGHT dimension uses**. One definition of the haunch, used twice, so the two can never drift.
  `peb-draw-mezz-section` takes `H` and `ht` as arguments for this reason rather than reading
  the height keys again.

**They stand on the mezzanine's FREE edge, inside the void the floor does not cover** — so they
cross neither the floor build-up nor the outside dimension columns, which on this sheet already
carry BRICK MASONRY and CLEAR HEIGHT. A mezzanine covering the full width leaves no void, so
they fall back to just inside the band.

The over-height is **suppressed below 300 mm** — a deck near the eave has no meaningful headroom
to print, and a near-zero dimension with two arrowheads is noise.

### 4B.39 The mezzanine sheet carries the MEZZANINE's data, not the building's

**Owner, 29-Aug:** *"on Mezzanine Floor plan, title block have all the information related to
Mezzanine like live load, & other load and details"*, *"as overall buildings are already at have
the information and column layout plan."*

The roof and frame live loads, wind, exposure, snow and seismic belong to the **building**, and
the Column Layout Plan and the Cross Section already print them. Repeating them on the mezzanine
sheet told the reader nothing about the floor the sheet is about.

`peb-titleblock-mammut` dispatches on `tbKind`, derived from the drawing title. A **MEZZ** kind
now sits between SECTION and FRAMING and prints **MEZZANINE DESIGN DATA**: floor area, dead /
live / collateral load, slab thickness, F.F.L, the two clear heights (4B.38), joist spacing, and
the floor system spelled out. Every row is a stated BSF field (`MZ1_*`), so the panel quotes the
estimate rather than restating the roof.

### 4B.40 An encircled column is a MEZZANINE-ONLY column

**Owner, 29-Aug:** *"the internal columns of mezzanine which are coming till only mezzanine
bottom will have a circle bubble around the columns"*, *"It will differentiate b/w the columns of
main building and additional columns which are only required for mezzanine."*

The Mezzanine Floor Plan drew **every** column as the same tube circle, so a full-height main
frame column and a stub that stops at the beam soffit were indistinguishable — and the count of
NEW steel is the whole point of the sheet.

A column is MAIN when its **width station** is one the main frame already stands on: `x` is always
a bay line on this sheet, so the width station decides. `peb-main-column-ys` is the same list the
mezzanine stub placer uses to avoid doubling a column, so the two cannot disagree about which
columns are new. Same convention the Column Layout Plan overlay already uses (owner 10-Jul).

**With no main list, encircle nothing rather than everything.** An unmarked sheet is recoverable;
a wrongly marked one is quoted from. And the circle gets a legend row — an unexplained symbol is
decoration.

#### 4B.40a WHY THE QE AND THE PD DISAGREE ON PURPOSE (owner, 1-Sep-2026)

They count different things, and both are right:

> *"In QE, since we do NOT have the formula to strengthen main building columns in case of taking
> the mezzanine, that is the reason we take complete columns and then validate by SAP at a later
> stage. But PD must not add additional columns for mezzanine and will use the existing main
> building columns. However, those columns which are additional for mezzanine till mezzanine
> bottom will be shown in PD."*

* **QE bills a full mezzanine column at EVERY station, including the ones standing on a building
  column.** That is not a double-count to be fixed — it is the allowance for strengthening the main
  column that now carries a floor, and the engine has no formula for that uplift. SAP settles the
  real member at design stage. On MSPL-26-279 that is 60 columns / ~17 t / ~Rs 7 M, deliberately.
* **PD draws the building as it will be BUILT:** the existing PEB column carries the mezzanine beams
  and joists, so no second column is drawn beside it. Only a genuinely ADDITIONAL column — one that
  exists solely for the mezzanine and stops at the beam soffit — is drawn, and it is bubbled.

So a change on one side must NOT be propagated to the other "for consistency". The owner reverted
exactly such a propagation on 1-Sep-2026 (*"QE will not changed / only PD"*) after an endwall rule
change moved the estimate by Rs 732,841 and put 216 other areas on the changed branch.

**Practical consequence for anyone editing this:** a PD-only column rule belongs in the PD's own
input builder (`services/drawingData.ts`) or in these .lsp files — NEVER in
`public/modules/sales/geometryRules.js` or `services/estimation/geometryDivision.ts`, which the
estimate reads.

### 4B.41 Inside a mezzanine, interior bracing is FULL-HEIGHT PORTAL

**Owner, 29-Aug:** *"in the Mezzanine Area, all internal bracings will be Full height Portal"*,
and on seeing the sheet: *"internal bracing is still showing cross … should be full height
portal."*

**This is physics, not preference**, which is why it overrides the entered bracing type rather
than asking for a second field: a cross brace on an interior column line runs its diagonals
through the plane of the mezzanine floor. The floor is there; the diagonal cannot be. A portal
frame carries the same load in the plane of the columns and leaves the floor clear.

**Derived from the BSF, never stored.** The footprint is already stated — `MZ_WIDTH_GRID_FROM/TO`
through `peb-mz-width-band` (the same function the plan, the section and the mezzanine sheet place
the deck with) plus `MZ_GRID_BAY_FROM/TO`. An "interior bracing = portal" field would be a second
place to say what `MZ_TOGGLE` already says, and the two would drift.

**It is per column line, not per building.** On MSPL-26-271 the mezzanine is the full length but
only A→G of a nine-line width grid, so lines out in the void bay keep the entered type. A blanket
override would portal bracing that has no floor anywhere near it.

### 4B.42 Members are drawn at their REAL flange width

**Owner, 29-Aug:** *"Main Beams top flanges are shown very thick and Joist are shown very very
thin … But actually there small difference - For Example if the Main Flange is 300mm-350mm,
joists are 150-200mm normally"*, and *"Main Beams Flanges & Joists i meant to say."*

The mezzanine floor plan drew its members at half-widths of 250 / 180 / 120 — an invented ~2.5×
exaggeration of an invented 200 / 150 / 100. That put the drawn ratio at **1.39 : 1** where the
real one is close to **2 : 1**, so the beam read as a solid bar and the joist as a hairline beside
it: the difference in the wrong place and the wrong size.

**REVISED 29-Aug.** The first pass drew 325 / 175, read off *"300-350 … 150-200"*. The owner then
settled the typical section: *"also make the size of main beams as 200 and joist 150 Typically."*
So the drawn top flanges are **main beam 200, joist 150, secondary 100**.

At 200 against 150 the two members are only 0.42 and 0.32 mm apart on the plotted sheet, so the
**width can no longer carry the distinction on its own — the LINE WEIGHT does**, which is the house
rule regardless ("material = line thickness"), set per layer in `PEB_LAYERS.csv`: beam 0.40, joist
0.30, secondary 0.18.

**The legibility floor is a rule, not a fudge.** Every sheet is auto-fitted to A4, so a fixed model
width plots *smaller* the bigger the building, and past a point a 150 mm joist flange closes to a
single line and stops reading as a member at all. The floor is expressed in `*PEB-TEXT-SCALE*` —
the engine's "constant on paper" unit — and **tuned so the TRUE size wins at this building**
(93 m, scale 2.07: floor 87 / 66 / 46 against true 100 / 75 / 50). It only takes over on buildings
big enough that the true width would vanish.

### 4B.43 A detail too small to read at building scale belongs on the DETAILS sheet — PARKED

> **PARKED 29-Aug.** *"Mezzanine Floor Detail is not the one we developed last time. for the
> time being remove it."* The build-up below was reconstructed from the cross section's own
> layering; it is **not** the detail already developed for this floor, which has not been found.
> Shipping a second, different detail of the same floor is the exact contradiction **4B.7**
> exists to prevent, so the call is switched off (`mzOnSd nil`) and `peb-sd-mezz-floor` left in
> place, ready for the real geometry. The DETAILS sheet reverts to what it was. **The rule below
> still stands** — it is the placement that is right and the drawing that is wrong.

**Owner, 29-Aug:** *"Also we developed the Sectional Details of Mezzanine Floor Showing the
Concrete Etc."*

It had been developed — inside the cross section, at building scale, where a 125 mm slab on a
45 mm deck plots at a third of a millimetre. Drawn, and unreadable. The DETAILS sheet is where a
thing too small to read at building scale gets shown at its own scale, and half of that sheet was
empty.

The cut runs **across the joists**, so joists appear as cut I-sections and the main beam — which
runs perpendicular to them — as the deeper section at the left. Joist tops are FLUSH with the beam
top (**4B.32**).

**Every dimension is the BSF's, not a house constant:** slab from `MZ<n>_FLOOR_THK`, beam depth
from the two stated levels exactly as the cross section derives it (**4B.7**), so the detail, the
section and the mezzanine sheet cannot disagree about the same floor. The sheet heading drops to
clear it, for the same reason the second column made it drop before.

### 4B.44 A canopy appears on the WALL ELEVATION, not only on the plan

**Owner, 29-Aug:** *"Also pls draw the canopies"*.

Canopies reached the Column Layout Plan and stopped there — `Framing.lsp`, `Elevation.lsp` and
`Section.lsp` had no canopy handling at all. On MSPL-26-271 that meant two 62'-1" entrance
canopies over the customer's front door were absent from the very sheet a customer looks at to
see the front of their building.

In elevation a canopy is its **fascia**: a band at the canopy level running the canopy's length,
with its soffit line under it. The projection is toward the viewer and cannot be drawn, so it is
stated in the label — that is what "PROJ." means.

**The view is from outside, so the station list has already been mirrored for FSW and LEW**
before the canopy is placed (4B.-mirror note in `peb-draw-framing-elev`). A plan grid `g` sits at
position `n-g` in the mirrored list, and an offset measured from the start grid runs the other
way. Getting this wrong puts a canopy over the wrong door on exactly the two walls that carry
them.

Level comes from `CN_<W>_<n>_EAVE_HT` when entered; otherwise the canopy hangs off that wall's
own eave. Length is honoured from the anchor (**4B.33**) rather than stretched across whatever
grid range it happens to sit in.

### 4B.45 A column symbol and its bubble must BOTH read

**Owner, 29-Aug:** *"It is shown in the column layout plan but these are too small"*, and
*"appareantly we must see the I and there should be small gap and then bubble must come"*, and
*"Circle bubble will come on mezzanine columns on Ground Floor Plan & Mezzanine Floor Plan. I
symbol will be shown in the circle."*

The mezzanine stub column is sized off the **mezzanine** spacing — 8.3 m / 35 ≈ 240 mm deep —
because that is its real section, correctly lighter than the main frame. But 240 mm on a 93 m
building auto-fitted to A4 plots at about **four tenths of a millimetre**, and the bubble at
0.72 D lands inside the linework. Neither the I nor the gap survives.

**A member is drawn at its real size (4B.42). A SYMBOL is drawn to READ (4B.31).** This is a
symbol — a mark saying *this column is new* — so it gets a legibility **floor** expressed in
`*PEB-TEXT-SCALE*`, the engine's constant-on-paper unit, and a **cap at three quarters of the
main column** so the hierarchy can never invert: the stub must still look lighter than the frame
column beside it.

**The bubble is sized off the I it encircles, not off a constant.** The I-section is `D` deep by
`0.40 D` wide, so its half-diagonal is `0.539 D`; a radius of `0.78 D` leaves a clear gap all the
way round — the "small gap" the owner asked for, at any building size.

Both sheets now use the same symbol: `draw-I-column-lengthwise` for the body, encircled when the
column exists only for the mezzanine. The Mezzanine Floor Plan previously drew every column as a
plain tube circle, showing neither the section nor the distinction — a main frame column and a
stub that stops at the beam soffit were the same dot. **One convention across both sheets**, so a
reader moving between them is not learning two.

### 4B.46 On the plan a canopy is a BOX with its name in it

**Owner, 29-Aug:** *"Just show the rectangular box and write canopy … that's all"*, and *"you may
write height also of canopy in plan"*, and *"in plan 2 Canopies should be shown each of 18.92m one
for Exit and one for Entrance"*.

It was a **dotted** outline with the word parked at 0.72 along the wall — dodging the CLP's other
annotation rather than sitting in the thing it names. A dotted line reads as *not built yet* next
to the solid steel around it, and a label outside its own box belongs to nothing.

A **solid rectangle with the name centred in it** is unambiguous at any scale, and is all the
Column Layout Plan owes a canopy: no fall arrow, no projection or coverage dimensions — those are
the canopy's own detail, and this sheet is about columns.

**PURPOSE comes from the BSF, never from the position.** A building can carry several canopies on
one wall and they are not interchangeable to the reader — the entrance is the one the customer
walks in through. The engine cannot know which end is the front door, and a house rule like *grid
1 is always the entrance* would be wrong on the next job. A `purpose` field on the canopy
component (Entrance / Exit / Entrance & Exit / Loading / Shelter) is emitted as
`CN_<W>_<n>_PURPOSE` and printed in brackets after the name; blank prints just "CANOPY".

The height is `CN_<W>_<n>_EAVE_HT` — the same field the wall elevations place the fascia from
(**4B.44**), so the plan and the elevation cannot quote different levels for the same canopy.

### 4B.47 Doors are DRAWN, not only quoted — one shutter per bay

**Owner, 29-Aug:** *"Show the Sutter Doors b/w the Columns"*, *"Auto-Shutter Door"*, *"one shutter
per bay, 7m x 3.5m, both entrance and exit"*.

Doors reached the **proposal** (`proposalData`) and the **estimate** (`mapComponents`) but never
the drawing — there was not one door key in `drawingData.ts`. A building could be quoted with four
auto shutters across its front and drawn with a blank wall, and nothing in the set would show the
disagreement.

**One door per BAY**, centred between its two columns, because a shutter spans column to column: a
three-bay doorway is three shutters, not one 23 m door. The CRM expands the grid range to one
indexed instance per bay (`DR_<W>_<n>_GRID_FROM/TO`), so the engine never guesses how many leaves
a range means.

**`placeGridFrom` accepts a LIST of ranges** — `"1-3, 11-13"` is two doorways, one at each end of
the wall, which is exactly the shape a Cash & Carry has and cannot be said with a single from/to
pair.

**The width is CLAMPED to the clear bay.** An entered 7,000 in a 7,734 bay is a real door; the same
7,000 typed against a 6 m bay is a typo, and drawing it would put a door through the columns either
side. Clamping shows the mistake at its true size instead of hiding it.

**The view is from outside**, so the station list is already mirrored for FSW/LEW — plan grid `g`
sits at position `n-g`. Getting that wrong puts the entrance door at the far end of the building.

**Doors are gated by `sec1:acc`** like every other accessory (the standing rule: only what is
ticked reaches the draughtsman). An untickd accessories section is why a door can be specified and
still not drawn — check the tick before hunting the engine.

> **Debugging note, worth keeping.** A probe that loads the engine but never calls `peb-std-setup`
> has no standard layers, so the first `(setvar "CLAYER" "TEXT")` throws and the enclosing loop
> silently stops after ONE iteration — with correct geometry for that one item. It looks exactly
> like a broken loop and is not. Any harness that calls a drawer directly must run `peb-std-setup`
> first.

### 4B.48 A mezzanine stub column is NOT braced — and that is a decision, not an omission

**Owner, 29-Aug:** *"I think better not to provide the bracing for those columns which are coming
till mezzanine as it may not even required? what do you advise"* — and the advice was: **he is
right, do not brace them.**

**Why.** A mezzanine stub column stops at the beam soffit and carries only floor load. It is a
**gravity column — a leaning column** — and takes no part in the lateral system. The RC slab on
profiled deck is a genuine **rigid diaphragm**: it collects the floor's inertia and delivers it to
whatever it is tied to, which is the main frame columns on the width grid. So there is already a
complete load path without a single brace on a stub line:

> slab → main frame columns → interior **portal** frames across the width (**4B.41**) and wall
> bracing along the length → foundations.

**Bracing them would be worse than redundant.** Steel you brace, you stiffen; steel you stiffen
attracts load. Bracing the stub lines pulls the diaphragm's force distribution onto arbitrary
interior lines that were never meant to carry it, away from the frames sized for it.

**Three things must be true, and they are design-stage checks, not proposal-stage ones:**

1. **The slab must actually tie to the main columns** — shear connectors or edge angles on the
   width grid. A mezzanine detailed as a free-standing platform on its own columns needs its own
   lateral system, and this rule reverses.
2. **The main frames must carry the mezzanine's seismic mass.** On MSPL-26-271 that is roughly
   4,500 m² at 3 kN/m² dead plus 6 kN/m² live, sitting 5.8 m up, in Zone 2B. That demand is
   exactly what the interior portal frames under the deck exist to take.
3. **Leaning-column P-Δ.** The stubs have axial load and no lateral stiffness, so their gravity
   amplifies drift demand on the frames that do resist. SAP sizes for it. *Unbraced* is not *free*
   — the load moves next door.

**This is NOT a softening of 4B.41.** That rule is about the **full-height interior columns**,
which ARE part of the lateral system and where a cross brace is physically impossible because the
floor is in its plane. Different columns, different reason, both still true.

**Implementation: nothing was removed, because nothing ever braced them.** The drawing braces
`widthPts` — the main frame column lines — and the estimate loops `Nspans - 1`, the same set.
Mezzanine stub stations are in neither. This rule therefore records an **absence**, which is
precisely why it needs writing down: the next person to look at an unbraced mezzanine column line
will otherwise read it as something the engine forgot.

### 4B.49 Do not publish a number DESIGN will set — and LOAD the file to prove it parses

**Two separate lessons from one change, 29-Aug.**

**(a) The joist spacing comes off the sheet.** Owner: *"do not show the joist spacing, spacing
remains as per design."* The joists are still **drawn** on a spacing — they have to be drawn
somewhere — and the estimate still **prices** one. But the sheet must not **print** the number: a
proposal drawing that states 1,250 c/c is read as a commitment, and the spacing is settled at
design/SAP against the real floor loading. The notes now read *"SPACING AS PER DESIGN"* and the
JOIST SPACING row is gone from the MEZZANINE DESIGN DATA panel (**4B.39**).

Same reasoning already applied to the mezzanine column **section size** (owner 12-Jul). The
principle: **what the drawing states, it owes.**

**(b) `lispbalance` CANNOT prove a file parses — only AutoCAD can.**

This edit dropped a `(strcat …)` wrapper from two labels but kept its closing paren, leaving two
extra right parens in `MAIMAAR_PEB_Plan.lsp`. Every static check passed:

* `lispcheck.js` — clean (it only compares defined vs called names);
* `lispbalance.js` — reported a *positive* depth, because it counts parens inside string literals
  and this file legitimately contains `"(TYP.)"`, `"[208'-8\"]"` and similar;
* a hand-written string-and-comment-aware counter — also reported positive depth, and *"never
  negative"*.

AutoCAD said `extra right paren on input` and **refused to load the file at all**. Every drawer in
it would have been undefined — which by **4B.26** renders as a blank sheet, silently.

> **The check that counts is `(vl-catch-all-apply 'load (list "<file>"))` in a headless AutoCAD,
> asserting the result is not `vl-catch-all-error-p`.** Run it after every engine edit, before any
> render. A paren counter is a hint; a successful load is proof.

### 4B.50 The proposal sheet shows the COVER WIDTH — the folds belong to the approval drawing

**Owner, 29-Aug, in order:** *"you have not developed the New Seam Lock Sheet - Details"* → the
fold-by-fold detail was built → *"do not show detailed dimensions but only the covered width of the
sheet"*, *"just match the sample and only show the main main dimensions"*, *"not much more"*.

**The settled answer: profile matching his section, `470 COVER`, nothing else.**

**Why the reversal is right.** 470 is the figure a customer prices and a draughtsman lays out from.
The folds — 92/10/145/10/91, 155, the 15/10/25 seams, 32/23, 32/22, 119° and 148° — are
**roll-forming** dimensions, settled by the mill. Printing them on a proposal invites a discussion
the proposal is not the place for, and commits Maimaar to figures the mill owns. Same judgement
already applied to the mezzanine column **section size** (owner 12-Jul) and the **joist spacing**
(**4B.49**): *what the drawing states, it owes.*

**`peb-sd-lockseam-dims` is left in place, not deleted.** It is correct, it is traced from the
owner's own DXF, and it is the **approval-drawing** detail. It waits for the sheet that wants it;
deleting it would only mean building it again. Everything below still applies when that sheet
exists.

---

#### The detail itself (retained, currently not called)

**Owner, 29-Aug:** *"SeamLock Sheet Profile.PNG, also update this"* … and then, after the outline
was re-traced: *"you have not developed the New Seam Lock Sheet - Details."*

He was right, and the distinction is the rule. Re-tracing the **outline** was half the job: his
section is a **detail** — every fold dimensioned, both seam angles called out. An outline carrying
one "470 COVER" bar tells a fabricator nothing he can roll from, and the DETAILS sheet exists to
carry exactly that.

**SUPERSEDED SAME DAY — the owner sent `Drawing9.dxf`, his own section.** The geometry is now
lifted straight out of it: the LWPOLYLINE's 35 vertices, a **closed outline carrying the sheet's
own 0.5 mm material thickness** rather than a single centre line, which is why each run appears
twice — once on each face.

**Take the source, not a photograph of the source.** The pixel trace was good — 486.0 × 64.9 with
rib centres at 155.1 against the actual 485.5 × 65.5 at exactly 155.000 — but "good" is not a
basis for a fabrication detail. Ask for the CAD file.

**The ribs are ARC BULGES, and ignoring them silently flattened the pan.** Vertices 17/19 carry
`bulge = -0.5` (group 42) — a 10-wide arc rising 2.5 mm. The first pass read only the 10/20 pairs,
so the profile drew with a dead-flat pan and no ribs at all: a valid-looking section of the wrong
product. They are tessellated into chords, which plot identically at sheet scale and cannot break.

**The dimensions are HIS roundings of HIS steel.** His pan measures 91.356 / 10.000 / 145.000 /
10.000 / 91.356 and he dimensions it 92 / 10 / 145 / 10 / 91. Anchoring the bars on his vertices
means each one spans the steel it labels (**4B.7**) with the number he uses for it.

**The stated chain proves itself.** 92 + 10 + 145 lands the two rib **centres** exactly 155 apart —
and 155 is the one dimension the owner's section calls out independently. Two figures from
different parts of the drawing closing on each other is what makes it a trace and not a guess. The
same check runs at the other end: the male seam box sits 470→486 so it laps exactly over the next
panel's 0→16 hook, and 16 is the hook's own width.

**`%%d`, never a degree glyph.** The SHX fonts have no degree character and a literal ° plots as
`?` — the same trap the em-dash set in **4B.36**. `txt` upper-cases its string, so it reaches
AutoCAD as `%%D`; the control codes are case-insensitive, so both render.

**Dimension the FIRST module only.** Both modules are drawn so the seam joint reads, but
dimensioning both would print every figure twice across a 940 mm strip. A detail is dimensioned
once and repeated for context.

> **`T` cannot be a local.** The first version named its three helper lambdas `D`, `V` and `T`;
> `T` is the AutoLISP TRUE constant and binding it fails with *"incorrect object to bind: T"* —
> caught only because the drawer was probed, since the enclosing `vl-catch-all-apply` swallows it
> into a silently missing detail. Same class as the `rem` trap already recorded.

## 5. THE DOC SET (how the four files relate)
| File | Holds | Read it when |
|---|---|---|
| **PD_RULEBOOK.md** (this) | Every rule, organized; the BSF↔PD contract | You want the law — what must/mustn't happen |
| **PD_MASTER_REFERENCE.md** | LSP code/function index · full per-key trigger matrix · coverage ledger | You need to know what a specific field/key does end-to-end |
| **PD_BSF_SYNC_MECHANISM.md** | The zero-conflict mechanism: key contract · drift guard · shared core · default policy · realtime · gap register | You want to guarantee BSF and PD can never drift, or to fill a gap |
| **DRAWING_CONTENT_RULES.md** | Per-sheet element-ownership matrix | You need to know which sheet owns an element |


### 4B.51 The gutter is 0.50 mm — a traced sheet gives you the SHAPE, not the house spec

> *"Gutters thickness is 0.50mm by default"* — *"not 1.20mm"* — owner, 30-Aug-2026

The DETAILS sheet printed **`1.2 mm PPG.L`** under both the eave gutter and the valley
gutter. That number was never a Maimaar standard: it was read off the ONE approval drawing
the profile was traced from (job 59, PAECO) and carried onto every proposal since, which is
how a single job's detail becomes a company-wide claim nobody chose.

**The house default is 0.50 mm PPG.L**, and it is now printed on both gutters
(`peb-draw-sheeting-detail`, `MAIMAAR_PEB_Framing.lsp`).

**The rule this is an instance of:** 4B.25 says trace the section rather than invent it —
and it is right about GEOMETRY. Geometry is what a traced drawing proves: 165 base, 203
deep, the fold angles. **Material and gauge are a commercial standard, not a shape**, and
they do not travel with the trace. When a traced source carries a spec figure, take the
shape and check the figure against the house standard before printing it — a proposal
drawing is an offer, so a gauge on it is a price commitment (4B.7: the sheet must not
contradict what is being sold).

There is no BSF field for gutter gauge, so 0.50 is a literal in the engine. If a job ever
needs a heavier gutter, that is the moment to add the field — not to edit this string,
which would silently re-commit every other proposal to that job's gauge.


### 4B.52 A column in the middle of the frame TAKES the connection — the rafter does not

> *"Whenever the Column is in the Middle of the Frame — then Remove the Connection Plates b/w the
> Rafters & Give Connection Plate b/w top of the column to Bottom of the Rafter"*
> — owner, 30-Aug-2026, with `Multi-Span_Middle Column.PNG`

**THE RULE**

> Where a column stands under the rafter, the connection is **column-top → rafter-soffit** — the
> two solid 30 mm plates of 3.10. There is **no rafter-to-rafter plate** over that column. The
> rafter runs continuous across it.

**Half of this already worked, which is why it was missed.** `draw-ms-interior-plates` and
`draw-mg-ridge-col-plates` have drawn the column-top pair for a long time. What no one had done
is the *other* half of the sentence — remove the rafter plate — because
`draw-rafter-stiffeners` places its plates **by distance along the rafter** (knee end, ridge
start, apex, a splice every 12 m) and knows nothing about columns. Only the apex pair was
suppressed, by a flag `apexHasCol` set from `(< (abs (- col (/ wid 2.0))) 1.0)`.

**On MSPL-26-278 that flag could not possibly be true.** Measured off the sheet:

| | |
|---|---|
| building width (`BP_WIDTH`) | 30,480 ← what `wid/2` was tested against |
| **steel** width | 30,010 ← `BP_WIDTH_MOD_REF` = *Out to out of Steel Column* |
| ridge / apex | **15,005** = centre of the *steel* width |
| interior column (grid D) | **14,770** |

Three different numbers. So a rafter-to-rafter pair was planted at 15,005 — **235 mm from the
middle column's centreline** — with its four gussets, which is what he photographed.

**THE FIX IS THE QUESTION, NOT THE TOLERANCE.** Stop asking *"is this the apex?"* and ask what
the rule asks: **is there a column under this plate?** `peb-plate-over-column-p` tests each plate
station against the interior columns, each carrying its own clearance = *half its web +
`*PEB-CP-EXT*`* — so a plate is dropped exactly when it would land inside that column's own
connection zone, at the apex or anywhere else. `peb-interior-col-clearances` builds the list from
the SAME column list the plates are drawn from (Multi-Gable re-derives `haunchCols` un-mirrored —
mixing the two spaces would silently suppress nothing; see 4B.37).

`msApexX` still exists, because a column truly under the apex takes the *ridge-column* detail
rather than the generic one — but it now tests against the real ridge, not `wid/2`.

**Verified by measurement, not by eye** (`scripts/renderOneSheet.js … --dump`): the pair at
14,974.3/15,005.8 × 5,770.5–6,742.0 and its four gussets are gone; the column-top pair at
14,518.2–15,021.8 (column + 100 mm each side, immediately under the soffit at 5,867.2) remains;
the eave knee plates and the 12 m mid-span splices at 4,478 and 10,510 are untouched — 60
plate entities became 54, and only those six moved.

### 4B.53 The slope callout keeps clear of the PEAK LINE

> *"Also Fix the Slope Location Issue as well."* · **"Alway keep away from the Peakline"**
> — owner, 30-Aug-2026

**THE RULE**

> The `1:NN` slope tag sits at the middle of its half-rafter and **never near the ridge**. Its
> clearance from the peak line is a quarter of the half-span, and never less than a glyph and a
> half — a floor, not a suggestion.

**The cause was two references for one tag.** The tag's **Y** already knew that a Multi-Span
rafter is continuous over its interior columns and therefore rises from the OUTER eave — its own
comment says so. The tag's **X** took the midpoint between the nearest **columns**. On 278 the
interior column is at 14,770 and the ridge at 15,005, so the "half rafter" the X measured was
**235 mm** long and the callout landed **41 mm from the peak line**.

It gets worse with more columns, and this is why it is a rule and not a nudge:

| interior columns | tag distance from the ridge (30.5 m wide) |
|---|---|
| 2 | 2.5 m |
| 3 | 1.9 m |
| 1, with a ridge offset | on the peak |

**Fixed by giving the tag ONE reference** — the same outer stations its height already used
(Multi-Gable keeps its valleys, where the rafter really does start) — **plus a hard clearance
floor** in `*PEB-TEXT-SCALE*` units, so no future change to the midpoint rule can walk it back.
Measured on 278: from 14,963.7 (41 mm off the peak) to **7,578.7 and 22,431.3 — 7.4 m clear on
both sides**, symmetric.

This is the third pass over this callout: 4B.27 fixed the glyph that read `110`, then 75 %-from-
eave became 50 %-of-half. Both were placements. This one is a *clearance*, which is why it holds.


### 4B.54 The title-block band is about the sheet it is on — or it is the wrong band

> *"Right Side Title Block must have the Information about that Page Drawings"* — owner, 30-Aug-2026
> (rule **1.6.3**)

**THE RULE**

> The band in the right-hand strip belongs to the drawing on that sheet. A sheet that matches no
> band gets one written for it — it does not fall through to another sheet's.

`peb-build-tbdata` was designed to be sheet-agnostic, and says so: *"EVERY sheet gets the SAME
title block … only DRGTITLE differs"* (owner, 7-Jul). Of its ~41 fields exactly one varied. The
only per-sheet behaviour in the whole system is a `wcmatch` on the drawing title inside
`peb-titleblock-mammut`, choosing one of four bands. That was right while the rule was *"the same
block everywhere"*; the owner has now replaced that rule, and 4B.39 had already replaced it once
for the mezzanine.

**What the four-band dispatch was actually printing**

| sheet | matched | band it got |
|---|---|---|
| **DETAILS** | nothing → default | the BUILDING's roof live load, wind speed, seismic zone, rainfall — on a page of panel profiles |
| **ROOF FRAMING PLAN** | `*FRAMING*` | the WALL framing notes |
| **ROOF SHEETING PLAN** | `*SHEETING*` | the WALL cladding notes |

Three new kinds, and the order of the tests is part of the rule: **the specific patterns are tested
before the substring ones, and the ROOF tests anchor on the FIRST word** (`ROOF*`), so
`SIDE WALL SHEETING` can never be caught by them.

* **DETAILS** → `PANEL & TRIM DATA`: the roof and wall panel type, profile and material, and the
  eave — the things that sheet draws — with the gutter at 0.50 mm (4B.51). Written as paragraphs,
  not label/value rows: a profile name is `Standard S Profile 35-250`, and in the narrow value
  column `tb-fith` would shrink it to unreadable.
* **ROOF FRAMING PLAN** → `ROOF FRAMING DATA`: slope, bays, length, width, and purlins deferred to
  the approved design (proposal level — never member sections, the owner's standing rule).
* **ROOF SHEETING PLAN** → `ROOF SHEETING DATA`: the roof panel and its slope, and the fall
  direction deferred to the plan itself.

**And the title must be the SHEET's, not the drawing type's.** In the DWG path the area suffix
(` A1`/` A2`) and the match-line part (` P1`/` P2`) reached the tab name only, never `DRGTITLE` —
so a split or multi-area building printed **byte-identical title blocks on two different
drawings**: correct geometry, and no way to tell the sheets apart from the strip whose job is to
name them. That is 1.6.1 failing inside the title block while the geometry passes. `DRGTITLE` now
carries the full sheet identity; the PDF path always did.

**Still open, recorded so it is not mistaken for finished:** `DRN`/`CHK` print the engine defaults
`M.H`/`YEA` on every sheet of every proposal because `drawingData.ts` sends blanks, and the `DSN`
column has a label and no value cell at all — a labelled empty cell is 4B.7.
### 4B.55 A skylight has a PLACE — and the count must come from where the price comes from

`MSPL-26-269` was billed for 16 skylights and its Roof Sheeting Plan drew none. Nothing errored.

The count had two homes. `drawingData.ts` read the legacy **area column** `skylights`; the BSF saves
it on the **`roof_accessory` component**, which is where the estimator reads it
(`mapComponents.pushAcc('skylight', …)`). So `RA_SKYLIGHTS=0` reached the engine and 4B.12's own
contract — *"if the BSF declares none, the sheet draws none"* — did exactly what it promised. The
sheet was obeying a rule while telling the customer something the price contradicted.

**The count now comes from the component, with the column as fallback, and filling BOTH raises a
warning** rather than a silent pick: the two are billed by different code paths
(`mapComponents` vs `mapArea` → `buildArea.computeSkylights`), so both filled is a double charge.
Same shape as the doors block, same default-OFF Include tick — an untied skylight is neither billed
nor drawn.

**Where a skylight goes: the MIDDLE OF EACH ROOF SIDE, and the MIDDLE OF EACH BAY** (owner,
31-Aug-2026). Not an even grid over the rectangle — that is not a location, and it can drop a panel
onto the ridge line, which cannot be built. `RA_SKY_PER_BAY` turns the placement on; without it the
old even grid runs unchanged, so no existing job's sheet moves.

Sides come from `peb-ridge-y`, never `wid/2` — an off-centre ridge gives two different half widths
and the panels still sit mid-slope on each. Bays come from the **caller's** `bayPts`: the sheeting
plan slices that list and shrinks `len` for match-line parts, so a drawer that rebuilds stations
from `len` puts every panel in the wrong bay on a split sheet. `peb-draw-roof-accessories` and
`peb-draw-monitor` both take it as an argument now for exactly that reason.

Traced, not invented — MSPL **2025/203 DHL Warehouse** approval sheet 19: a 49,370 × 66,845 gable at
1:10 over 8 bays, 16 skylights on a 2 × 8 grid, one per slope per bay.

**Draw the NET opening, not the sheet you buy.** `RA_SKY_L` = 3250 is the overall panel ordered;
`RA_SKY_L_NET` = 3000 is what lets light in, the balance lapped under the roof sheeting. Drawing
3250 would show an opening the building does not get. Same gross-vs-cover split as the sheeting
itself (coil 1200 → cover 1000). Carry both; the BOQ needs the first, the plan needs the second.

Layer **`SKY LIGHT`** (with the space), cyan — the house layer, read out of MSPL-051's own DXF. Fill
is 45° **lines**, never a `HATCH` entity: real hatches do not survive `acad /b`.

**No part numbers at proposal stage.** `SKL-01`, `RS-01`, `LS-01` and the parts table belong to the
approval drawing, where pieces are being fabricated — *"at this stage no need to give the sheeting
and skylight any number"*. One `SKY LIGHT` / `1000 X 3000` callout, the count in house wording
(`16 No. ROOF SKY LIGHT (EACH 3000mm)`), and the note. The one proposal-stage precedent in the whole
archive, `221-24-MSPL.pdf` PRO-04, prints exactly that and nothing more.

**NO skylight-location note on a proposal sheet.** One was traced from PAECO 169 and carried for a
few iterations — *"if the skylight location needs to be changed, it should be done at the time of
approval; otherwise Maimaar Steel Group will not be responsible."* Both halves are gone (owner
31-Aug). The disclaimer half because a proposal drawing does not need a threat, and the whole note
because it is **premature and redundant at this stage**: PAECO 169 is an APPROVAL drawing, where the
location is being fixed and saying so is the point, and this sheet's own General Note 3 already reads
*"PROPOSAL DRAWING IS INDICATIVE ONLY; FINAL DIMENSIONS & LEVELS WILL BE SHOWN IN THE APPROVAL
DRAWING AT THE DESIGN STAGE."* The note belongs on the approval drawing with the rest of what
approval fixes. **Tracing a note from a reference means tracing its STAGE too.**

**And the roof monitor was in the same hole.** The 21-Jul ruling took it off the Column Layout Plan
and sent it to *"the ROOF PLAN (to be built later)"*. That sheet exists (`C:PEB-ROOF`) but sits
behind `PEB_DRAFT_SHEETS` and is absent from the PDF pipeline — so the monitor was declared on the
BSF, drawn on the section, and shown on **no plan the customer ever received**. It is now drawn on
the roof sheeting plan beside the other roof accessories. A sheet gated off for review is not a
home; check what actually ships.

**Verified by measurement, not by eye** — dump the sheet's entities and do arithmetic on them:
16 panels, x-centres = the eight real bay centres (3240 … 57720), y-centres = 7620 and 22860, every
one 1000 × 3000.

**Still open:** the turbo-vent branch hardcodes `ridge (/ wid 2.0)` (`Plan.lsp`), and
`Framing.lsp`'s `PL_ SURFACE=ROOF` marks use `midY` — both put vents on the wrong line when
`BP_RIDGE_OFFSET` moves the ridge. Left alone here because fixing it moves existing sheets.

### 4B.56 Two sheeted surfaces — the sheet's job is to say which is which

A roof monitor is **small frames standing on the existing roof**, carrying a small roof over the
ridge. Its roof sits **0.75 m above** the main sheeting (`RM_HEIGHT` = throat / 2) and **overlaps**
it — passing over it, not lapped into it. The main roof is genuinely cut only at the **throat**;
under the overhang either side it continues.

**So from above there are TWO sheeted surfaces, and they look alike** — both are 1000-cover panel
runs in the same direction. The opening is not visible at all, because the monitor roof covers it.
The drawing's job is therefore **not** to hide one surface, and **not** to draw a hole. It is to
**identify each one**. That is a labelling problem, not a geometry problem — which is the thing three
successive wrong versions of this band all missed.

**Draw:**

* the **main roof** runs at 1000 cover, breaking **only across the throat**;
* the **monitor roof** — a band `throat x 2` wide on the ridge, with **its own ridge and its own runs
  at the same 1000 cover**, because that is what a roof looks like from above;
* **no opening.** It is underneath. A dashed throat was drawn for one iteration and it showed a hole
  the view does not contain. The reference agrees from the other direction: **no MSPL drawing uses a
  dashed monitor boundary in plan** — every one is continuous;
* **no ridge line under the monitor** (owner: *"in case of roof Monitor, i think there is no need of
  Ridge Line"*). The monitor stands on the ridge; there is nothing exposed to draw. The ridge is
  drawn only where the monitor is not — a partial monitor keeps its end stubs, which is exactly where
  the ridge really is exposed. Its label follows the line, or is not printed;
* **two callouts** — `ROOF MONITOR SHEETING` on the band, and the main roof's existing
  `ROOF SHEETING : <profile>` mleader. Placed at different stations so they never collide.

**And NO dimensions on this sheet.** The overall sat at the far left and the throat at the far right —
two numbers for one object **63 m apart**, the overall wedged into a gap smaller than its own text
between the roof outline and the `30,480` width chain (owner: *"the dimensions of roof monitor these
are mingled"*). Deleting them fixes that at the root instead of moving clutter. It is also what the
reference does: KM Foods does not dimension the monitor on the plan at all, and MSPL-032 dimensions
it only on its own dedicated sheet. The numbers still live on the BSF and the cross section.

**OVERALL WIDTH = THROAT x 2** (owner). The sheeting overhangs the opening by half a throat each
side; height is throat / 2. The whole monitor falls out of one number. It had to become a single
derivation: the section fell back to `throat + 1800` and the plan to a flat `3000`, so a job that
left the field blank got a section and a roof plan drawing the same monitor **200 mm apart**, with
nothing saying so. `peb-monitor-band` and `MAIMAAR_PEB_Section.lsp` now both read `throat * 2`.

**ONE source for the footprint.** `peb-monitor-band (data len wid bayPts)` returns
`(x0 x1 yBot yTop throat ridge)` and BOTH consumers call it — the monitor drawer, and the sheeting
loop that leaves the gap. The gap the sheeting stops at *is* the opening the monitor covers. It takes
`bayPts` from the caller for the match-line reason in 4B.55.

**What the reference actually shows** (swept entity-by-entity, 31-Aug — this CORRECTS the 8-Jul note
that recorded "no monitor label, reference-verified"):

| source | plan treatment |
|---|---|
| `MAIMAAR_06_Warehouse_KMFoods.dxf`, sheeting plan | band 1487.7, two CONTINUOUS lines, sheeting butts both edges, band empty, `TEXT` **`ROOF MONITOR OPENING`** inside |
| same, framing plan | same band, `HATCH ANSI33` 1500/0, label as a hatch island |
| MSPL-032 (2021) sheet 06, issued for approval | band ~1600, zero content inside, no label |
| MSPL-032 sheets 07 + 08 | **dedicated `ROOF MONITOR FRAMING PLAN` / `ROOF MONITOR SHEETING PLAN`** — 1000 each side of `℄ OF RIDGE`, `RMS-1` 1000x1000 panels, qty 32 |
| `proposals/30_Proposal Drawings.dxf` | band carrying the SAME roof hatch as the main roof — the monitor's roof shown on the plan, `ROOF MONITOR` leader on the ridge |

So MSPL **does** label it on the plan; the 8-Jul ruling was based on a wrong reading. And MSPL-032
corroborates the geometry: opening 1600, monitor roof 2000, overhang ~200 each side — the same shape
as 1500 / 3000 / 750.

**Where we depart, deliberately.** The majority MSPL convention draws the band as an empty opening,
which dodges the problem: an empty slot never has to distinguish two sheeted surfaces. We draw both
and name both. `proposals/30` draws both and labels only one. Naming both is better than either —
that is the whole of "more beautiful than the references" on this sheet.

⚠ `REF_10_BigBird_Hatchery_RoofMonitor.dxf` is **misnamed** — it contains no monitor at all. It is a
**RIDGE VENT**: discrete 3000 x 1000 double-outlined rectangles, one per bay, cut as islands out of
the roof hatch. A different product. Do not copy it into a monitor.

**ALL sheet text goes in ONE block BELOW the drawing — and below the view heading.** Not on leaders
over it, not tucked under the eave. Measured on 31-Aug: the skylight note printed at y −3422 while
the sheet's own view heading (`ROOF SHEETING PLAN`, ~1,900 tall) spans −5283…−3387 — straight
through each other. There is no room for a note stack between the eave and the heading, so the block
sits under the heading: left-aligned at the building's left edge, even pitch, one rung.

And no leader for the monitor. From a note block below the eave, a leader up to the ridge band
crosses the entire lower roof and every skylight on the way. The band is the only thing on the sheet
drawn at 0.50 — it identifies itself, and the note names it.

**Every height off the ladder (4B.27), never a fraction of `u`.** `peb-th 'ANNOT` for the notes,
`peb-th 'SMALL` for the long one, and that one additionally through `peb-fit-txt-h` against the
building length so it can never grow wider than the thing it belongs to. Ad-hoc heights like
`(/ (* u 0.45) ts)` are how three notes ended up at three different sizes on one sheet.

**NO per-bay dimension chain on this sheet.** It was added to match MSPL 2025/203 sheet 19, which
dimensions every bay — and on that sheet it fits. On A4 at 1:378 it does not: each dim prints
millimetres AND feet, 6,480 mm of bay is ~17 mm of paper, so AutoCAD pushed every text outside its
own arrows and eight of them collided into one smear across the top of the drawing. The overall
chain already carries the grid as `1@6480 + 6@8000 + 1@6480` and the bubbles number it. **A
dimension nobody can read is worse than one that was never drawn** — and "the reference does it"
is not a reason when the reference is at a different scale.

**Still open:** the turbo-vent branch hardcodes `ridge (/ wid 2.0)` and `Framing.lsp`'s
`PL_ SURFACE=ROOF` marks use `midY`, so both put vents on the wrong line when `BP_RIDGE_OFFSET` moves
the ridge. Left alone: fixing it moves existing sheets.


### 4B.57 If it is not in the price, the drawing has to say so

A liner carrying an **OP1–OP10** sales code is quoted **separately** from the base price. Drawn
without a word, the sheet shows a lined roof while the price beside it does not include one — the
customer reads a complete building and a number that does not buy it.

So the panel label carries **`(ADD-ON)`**:

```
ROOF SHEETING  0.50mm AZ 150 (PPGL) + 0.50mm AZ 150 (PPGL) Liner (ADD-ON)
```

**ADD-ON, not "Optional"** (owner 31-Aug). "Optional" describes the decision; "Add-On" describes the
thing. Beside a price, "Optional" can be read as the *price* being optional.

**Tag the ITEM, never the sheet.** A bare "(OPTIONAL)" floating on a drawing reads as though the
BUILDING were optional. It belongs on the label of the thing that is not being bought.

**One edit, both sheets.** `peb-panel-label` (`Section.lsp`) is the single place a panel label is
composed — `peb-build-sheeting-string` in `Plan.lsp` *delegates* to it and only falls back to a
simple label if it is unbound. So the tag was added there once and reaches the Section and the Plan
together. Do not add a second copy to the Plan: that is 4B.55's drift class, and the fallback path
deliberately carries no liner information at all.

Driven by `LN_ROOF_ADDON` / `LN_WALL_ADDON` from `drawingData.ts`, derived from the liner
component's own `salesCode`. Blank or non-OP on every existing record, so no existing drawing moves.

⚠ `addOn` is declared in `peb-panel-label`'s LOCALS. An undeclared symbol in AutoLISP is **global** —
it would have survived between sheets in one render session and tagged a later building's liner that
is in the base price. The bug would have appeared only on the *second* building of a multi-building
set, which is the kind that reaches a customer.

### 4B.58 A roof monitor exists on every sheet that can see it

The monitor was drawn on exactly **two** surfaces — the SECTION (`peb-draw-roof-monitor`,
`Section.lsp`) and the ROOF PLAN (`peb-draw-monitor` / `peb-monitor-band`, `Plan.lsp`). All four
wall elevations read **no `RM_*` key whatsoever**, so a shed carrying a 1500 throat monitor printed
end walls whose roof line ran straight over the ridge as though nothing sat on it (owner 31-Aug:
*"A Huge Bug now. Elevations Do not Show the Roof Monitor Lines"*).

This was never a regression. It had been missing since the monitor was built, and it only became
visible when a job actually carried one.

**The rule: an object added to the model belongs on every sheet whose view contains it.** A monitor
is not a roof-plan feature; it is a part of the building. Adding one to the section and the plan and
stopping there ships a set whose sheets disagree with each other about what is being built.

**ONE derivation, shared.** `peb-fr-mon-geom` (`Framing.lsp`) repeats the section's arithmetic
verbatim so the three surfaces cannot drift:

| | |
|---|---|
| throat | `RM_THROAT_WIDTH`, falling back to `RM_OVERALL_WIDTH` |
| overall | `RM_OVERALL_WIDTH`; blank or `<= throat` → **`throat × 2`** (owner 31-Aug) |
| height | **`throat / 2`** — STANDING RULE R1 |

⚠ **Height is `throat / 2`, NOT `RM_HEIGHT`.** The section ignores that key too. They agree on
today's records (1500 → 750), so reading the key would look correct and would silently diverge the
day someone typed a different number into the field. One monitor drawn to two different heights on
two sheets of one set is the exact failure this shared derivation exists to prevent.

**Seat it on the line that was actually drawn.** The legs are placed with `peb-fr-topy` — *the same
function that drew the roof line on that very sheet* — not with a separately computed roof level. A
second computation can be right in principle and still float the monitor above the rafter or sink it
below, because the sheet's own profile is what the reader sees.

**The two views are different projections, not one drawing twice:**

* **END wall (LEW/REW)** — the **cross-section**: a mini gable straddling the peak, legs at
  `ridge ± throat/2`, its roof overhanging each leg out to `± overall/2`, with eave returns. The
  monitor's end is sheeted closed, so **no vent opening is drawn there**.
* **SIDE wall (NSW/FSW)** — the **length**: a raised band over the ridge spanning grids
  `RM_GRID_FROM..RM_GRID_TO`. **This face is the vent** (owner: *"at peak, the reason of Fumes"*),
  so the throat opening and its bird mesh (`RM_BIRD_MESH`) show here and only here.

Bird mesh is drawn as ticks ~2 m apart, not as a hatch: at 1:378 a true mesh hatch smears into a
solid grey tone and the opening stops reading as an opening.

**Guards, each for a reason:**

* Gables only. `rtype "B"` puts a **valley** at mid-span (`peb-fr-topy`), so a monitor seated there
  would be drawn inside a gutter.
* `overall < 0.60 × faceLen` on the end wall — a monitor as wide as the building is a data error,
  and drawing it would bury the elevation underneath it.
* On a **match-line PART sheet** the stations are a slice with their own local origin, so grid 1 is
  no longer `stations[0]`. There the monitor spans the full drawn face rather than a confidently
  wrong pair of stations.
* The call is wrapped in `vl-catch-all-apply`, like every other optional piece on these sheets. A
  monitor that cannot be drawn must not be able to unwind the whole elevation — which is precisely
  how the end wall was lost once before (see the `rdep` note in `peb-draw-framing-elev`).

All locals are declared. An undeclared symbol in AutoLISP is **global** and leaks between sheets in
one render session — 4B.57 records the same trap.

Verified by measurement on MSPL-26-269 (throat 1500, overall 3000, wid 30480, slope 1:10): legs at
x = 14490 / 15990 (ridge 15240 ± 750), leg height 750, monitor roof 13740→16740 (3000 wide, rise
150 = `overall/2 × slope`), leg top 12415.9 landing exactly on the monitor rafter underside.

#### 4B.58a The monitor needed a roof to stand on — the side elevations had none

Drawing the monitor at its true height on a side wall exposed a second, older gap. **Neither side
elevation drew a roof.** `peb-draw-framing-elev` drew a bare ridge line floating over the wall;
`peb-draw-sheeting-elev` drew nothing above the eave at all. The two sibling sheets did not even
agree on whether the building has a roof.

So the monitor band came out correct to the millimetre and read as a **stray strip**: 1,524 mm of
white space between the wall top and a band of ticks, with nothing joining them. Measurement said
the geometry was right; looking at it said the drawing was wrong. **Both were true** — which is why
the render is checked with the eye as well as with arithmetic.

The projection: viewed square-on to a long wall, the near roof slope projects as a **rectangle**
from eave level to ridge level over the full length, and the gable rake at each end projects as a
**vertical line** — the rake runs away from the viewer, so it foreshortens to a point in plan-x.
Four lines make that band: eave, ridge, and two end edges. The sheets drew one or two of them.

Both side elevations now close the band, so:

| level | PRO-03 | PRO-05 |
|---|---|---|
| eave | 42528.4 | 42528.4 |
| ridge | 44052.4 | 44052.4 |
| monitor eave | 44652.4 | 44652.4 |
| monitor ridge | 44802.4 | 44802.4 |

⚠ **`(setvar "CLAYER" "RIDGE")` must be put back.** The two end edges just below the roof block draw
with **no `setvar` of their own** and inherit whatever is current — they would have silently moved
onto the RIDGE layer, and a layer error prints as a wrong lineweight, not as an error.

⚠ **No line along the bottom of the vent band.** The ridge line already runs the full length at
exactly that Y. A second line there on the OPEN layer is a duplicate entity, not a darker line.
Verified: PRO-05 reports **zero** coincident duplicates.

**This changes both side elevations on every gable job, not only those with a monitor** — they gain
a closed roof band where they previously showed a bare wall. Flagged to the owner as a deliberate
consequence, not a side effect.

#### 4B.58b An outline is not "shown" on a sheeting drawing

`efb2679` put the monitor on all four elevations as an **outline** — legs, gable roof, eave returns,
and the vent opening. The owner's verdict on the sheeting sheets: *"roof monitor is not shown in the
sheeting elevation."* It was drawn. It was in the entity dump. It measured correct. Beside a wall
filled with panel lines, a hollow outline still reads as **nothing being there**.

**A sheeting elevation shows sheeting.** An object that appears on it unsheeted has not been drawn,
whatever the geometry says.

`peb-fr-monitor` therefore takes a **`kind`** argument — `"F"` or `"S"` — passed as a literal by
each drawer, since each one knows which sheet it is. Framing keeps the clean outline; sheeting gets
panel lines. Same split the rest of both drawers already observe.

| | what is drawn | pitch | why that pitch |
|---|---|---|---|
| END, `"S"` | monitor end, **full overall width** | overall/(n+1), n = overall/333 → **300** on a 3000 overall | matches the wall sheeting (`sp 333.0`) on the same sheet |
| SIDE, `"S"` | monitor roof on its slope | **1000** | the roof COVER width `peb-draw-roof-sheeting` uses |
| SIDE, both | the vent opening below it | **1000** | the same stations as the sheeting above it |
| SIDE sheeting sheet | the MAIN roof band | **1000** | it was a bare rectangle on a sheeting drawing |

**Full overall width, extensions included** (owner 31-Aug: *"On both Ends Sheeting are complete
including Both Sides Extensions"*). The end is closed right out to the roof edge, so the 750
extension each side is sheeted too.

This **reverses** the leg-to-leg answer given earlier the same day, and the reversal is the point
worth keeping: the earlier reasoning ("a mini gable frame closes between its legs, so sheeting the
overhang would draw a wall that is not there") was sound in the abstract and simply not how
Maimaar builds them. The owner is the authority on that, not the reasoning.

The bottom of every sheet line is `peb-fr-topy` — the main roof at that x — which is the correct
bound in **both** zones, between the legs and out under the extensions, so one expression covers
the whole 3000. Top and bottom slope at the same rate, so each line is exactly `rmh` (750) tall
right across.

⚠ **Distribute the end sheets, never run a fixed pitch from one edge.** A fixed 333 from the left leg
put the last line 168 from the right leg — half a pitch — and the two printed as a single thickened
line. Spacing `overall/(n+1)` is symmetric about the ridge and clear of both roof edges.

⚠ **One module for the whole monitor.** The opening's ticks were evenly distributed at ~2 m while the
sheeting above ran at a fixed 1 m, so the two bands divided on different lines and stacked as two
mismatched grilles. Both now step `mx0 + n × 1000`, so the monitor divides on one module and reads
as one object.

**The main roof band is now sheeted on the side sheeting elevation, for every gable job** — not only
those with a monitor. Owner's call, 31-Aug.

### 4B.59 The elevations say what they are showing

A round of owner review on 31-Aug, all of it one theme: *"what i want the sync in all the drawings
of the building"*, and *"we should not compromise on Aesthetic"*.

**Every sheet states its own basis.** The elevations printed bare numbers while the plan tagged its
areas and the section spelled the height down the wall — three sheets of one set and only two said
what the number meant.

| | height | overall dim |
|---|---|---|
| plan (PRO-01) | `CLEAR HT.` tag | `BUILDING WIDTH : … O/O STEEL COLUMN` |
| section (PRO-02) | `CLEAR HEIGHT`, rotated | `… O/O STEEL COLUMN` |
| elevations (PRO-03…06) | **`9,140 [30'-0"] C.H`** | **`30,480 [100'-0"] O/O STEEL COLUMN`** |

Three lengths of one fact, because each sheet has different room for it. What they must NOT do is
disagree about **which** basis, so all three read the same keys through the same helpers:
`peb-height-tag-label` / `peb-height-tag-abbr` on `HEIGHT_REF`, and `peb-basis-suffix` on
`LENGTH_REF`/`BAY_REF` for a side wall and `WIDTH_REF`/`WIDTH_MOD_REF` for an end wall — the plan's
own keys (`Plan.lsp:5959, 5982`).

⚠ The `HEIGHT_REF` trap travels with the helpers: **"Clear Height at Eave" contains BOTH "CLEAR" and
"EAVE"**, so CLEAR is tested first in both, or every clear height prints as an eave height.

**An abbreviation must be defined on the drawing that uses it.** Note 7 on both elevation note
blocks: `C.H = CLEAR HT.   E.H = EAVE HT.` — both defined, not just the one in use, so the note does
not change between jobs. `tbKind` FRAMING/SHEETING reaches only the four wall elevations; the roof
sheets match ROOFFRM/ROOFSHT earlier in the same cond.

**Framing shows frame, sheeting shows cladding — in both directions.** Monitor legs draw on the
framing sheets only (a sheeting elevation draws no columns behind its wall sheeting either); bird
mesh draws on the sheeting sheets only. On the framing side elevation the mesh had been 60 ticks
across the top of the wall, reading as a comb.

**Bird mesh is drawn as BOXES.** `WRM` in the QE is *"Galvanized Wire Mesh (1.219m x 30.4m Rolls)"*,
billed by m² — a square mesh. Verticals alone drew slats, which is a different product and one a
bird walks through. One horizontal through the band gives 1000 x 300 boxes: the coarsest grid that
still reads as mesh, because the band is 600 tall = 1.6 mm at 1:375 and a true mesh pitch fills solid.

⚠ **Mesh draws only when `RM_BIRD_MESH` is selected** (owner). Blank draws nothing.

**A label above a peak-mounted part becomes a subtitle.** "ROOF MONITOR" centred above the monitor
landed under the sheet heading — measured, it OVERLAPPED by 79.5 mm on PRO-04, and lowering it to
294 mm clear (1.3 mm on paper) still read as a subtitle of the drawing. **Height alone cannot fix
it**: the monitor stands on the peak and the heading is centred over that same peak, so the label
has to leave the centreline. It is now a leader to the LEFT — the right side already carries the
GIRT TYPE leader.

**A member drawn as one unterminated line is not a member.** Removed from both knees and the peak of
the end-wall framing elevation: the flange braces (a bare diagonal ending in mid-air), the haunch
(a second bare diagonal crossing it, and redundant — the rafter is already a TAPERED double-line
member), and the peak ridge tick (a dashed vertical running the full rise, hanging through the
rafter into the frame). If a brace or haunch is ever wanted back it must be a **closed shape landing
on the members at both ends**.

**Purlins are NOT shown on the side framing elevation, and the reason is arithmetic.** `purlSp 1500`
gives `nRows = fix(0.5 + wid/1500)` = 20 across 30,480, so 10 per slope. On a side elevation purlins
run parallel to the wall and project as **horizontal** lines spread over the roof band's 1,524 mm —
152 mm apart, which at 1:375 is **0.41 mm**, thinner than the plotted lineweight. Ten of them merge
into a grey smear. Sheeting lines pass the same test and are drawn, because they run the other way:
**vertical**, at the 1000 cover width, **2.7 mm** apart. Legibility at the plotted scale is the test,
not whether the part exists.

### 4B.60 A member STOPS at an opening — it is not deleted, and it does not cross

Owner, 3-Sep-2026, in three passes on the same sheet:

> *"main beam should not be removed along GR. 2 & 7"* … *"Beams Must break at the point of
> staircase"* … *"you cut main beam also at the point of staircase"*.

Three notes, one rule: **the member runs its whole line and is BROKEN over the opening.**

The standing rule for a staircase is *remove joists & beams in the staircase void*, and it was
first implemented as a yes/no question — *does this member touch a void* — with the whole member
thrown away on a yes. So a main beam that a 6.6 m stair merely stood across vanished from column
to column: on MSPL-26-279 grids 2 and 7 lost their beam over the full 76 m width. A floor plan
that deletes a primary member is not a drawing of a floor that can stand.

The first correction over-shot the other way and drew the beam straight THROUGH the stairwell,
which is a beam passing through a hole.

> **THE RULE.** Every member — main beam, joist, secondary — is drawn in the runs of its own line
> that are **clear of every opening**. It stops at the opening edge and starts again on the far
> side. Nothing crosses a hole; nothing disappears because of one.

Measured, not judged: `peb-mezz-void-blocks` returns the blocked runs along the member's own axis,
`peb-span-subtract` takes them out of its span, and `peb-mezz-member-broken` draws what is left.
All three member loops in `peb-draw-mezz-floor-plan` go through it, so the whole deck reads one
way. A leftover under a millimetre is dropped rather than drawn as a stub.

The same reading applies to any future opening on this sheet — a lift well, a floor hatch: the
hole interrupts the members where it actually is, and nowhere else.


### 4B.61 A main frame line takes a letter; an infill post takes a prime

**Owner, 3-Sep-2026:** *"Bubble of dimension should be based on post columns & in case the main
columns are not aligned, then use A′, B′ like this."*

The width grid every sheet letters is the **merged** one — the width-module lines (the multi-span
frame columns) plus the end-wall and mezzanine posts between them. Lettering it straight through
gives every station equal billing, so a reader cannot tell a primary frame line from a wind post,
and the two take different connections.

> A station that **is** a width-module line takes a **plain letter**. A post that is **not** takes
> the **primed** letter of the main line above it.
>
> ```
>  A     A′     B     B′     C     C′     D     D′     E     E′     F
>  0   7,620 15,240 22,860 30,480 38,100 45,720 53,340 60,960 68,580 76,200
> ```

The prime carries the distinction without a second bubble shape — a different bubble for a post
would put the set straight back into *"the bubbles are not the same"*.

`peb-width-mark` / `peb-width-marks` (`MAIMAAR_PEB_Plan.lsp`), asked by the column layout plan,
both framing elevations, both sheeting elevations and the cross section. **One producer**: a line
cannot be marked one way on one sheet and another way on the next (4B.8). Skip-I comes free from
`peb-grid-letter`, and A stays at the far side wall (4B.34).

Straight-counting was also plainly wrong before the primes existed: the count included the posts,
so the near wall read **K** on the elevation where the plan said **F**.

---

### 4B.62 One bubble, one arrowhead, one dimension voice

**Owner, 3-Sep-2026:** *"Syn all the bubbles and also dimension follow the dimensions placement
rule in all drawings."* Both audits found the same shape of problem: a written standard, and
almost nothing obeying it.

**Bubbles — six radii became one.** 4B.31's `720 × TEXT-SCALE` is the rule; the engine had
`620×sc` on the mezzanine plan, `1100×TS` capped at 0.30 of a bay on the four framing views,
`380×TS` on the cross section, a `0.48×minSp` shrink on the roof plan, and — worst — the wall
elevations reading `*PEB-BUBRAD*` without ever setting it, so their bubble size was **whatever
sheet rendered before them**. Every sheet now asks `peb-bub-r` (Standard.lsp) and none inherits.
Both shrink rules are gone: crowding is answered by the **stagger**, never by shrinking, because
the bubble and the gap shrink together. The cross section's own plain-circle drawer is retired —
it drew a second kind of bubble into the same set.

**Arrowheads — four sizes and two styles became one.** The cross section drew its dimension heads
as a filled triangle (`PLINE` + `HATCH SOLID`) against the 19-Jul rule, while the *same file's*
monitor dims drew them open. Every dimension arrowhead in the set is now the OPEN `240/85` V.
Leader and callout heads stay **filled** — that is the other half of the rule.

**Feet belong on the OVERALL extent, not on every dimension.** 3.8b reads as "mm + ft-in
everywhere"; 4B.11 and 4B.14 are narrower, and they are right. Putting `[ft'-in"]` on every
dimension of a 6 m-wide view ran the labels into each other, and 4B.14's own example shows a
derived value bare — *"no ft needed"* — because General Note 1 already states every dimension is
in millimetres. Overall length, width, height carry feet. Nothing else does.

**A dimension is not a heading.** The staircase sheet drew its dimensions through `txt-bold` —
PEB-TITLE at heading weight — on an ad-hoc `STAIR-TEXT` layer that is in neither `*PEB-LAYERS*`
nor `PEB_LAYERS.csv`. ROMAND was never the question; *which ROMAND style* was. Dimensions go in
`PEB-DIM` at normal weight on the `DIMENSIONS` layer, like every other sheet.

**And the trap underneath all of it.** A gap that exists to clear TEXT must be computed from that
text's height (4B.27). The staircase sheet placed its labels in multiples of `u`, its geometry
unit, so enlarging the lettering moved the text and not the gaps: every label collided and the
auto-fit dropped the sheet from 1:143 to 1:182, handing back most of the gain. Raising a text
size is never a one-number change unless the gaps are already expressed in it.

---

### 4B.63 A chain is STATED from the BSF, never measured off the drawing

**Owner, 3-Sep-2026:** *"BSF showing out to out dimensions but mezzanine floor plan showing in
to in of the columns - sync all the dim and bubbles grids."*

A width chain is written **out to out of steel column**: `5@15240` starting at 0 and ending at
76,200. A column centred on the first station therefore *straddles* the out-to-out line - half
the section outside the building, and the dimension arrow landing in the middle of the steel
instead of on its face. The Column Layout Plan has always known this (`peb-main-column-ys`
starts at `colOff` and ends at `wid - colOff`; only the INTERIOR lines sit on the raw sums).
Anything that builds its own stations must apply the same correction - `peb-mezz-snap-ends`.

That leaves **two lists of the same chain, and they are not interchangeable**:

| list | what it is | what it is for |
|---|---|---|
| `*OO` | the BSF's, `0 .. wid` | the chain **TEXT** |
| snapped | ends on the column centrelines | where the **STEEL** is drawn, and the bubbles |

`peb-chain-text` prints the estimator's expression verbatim **only while that expression still
fits the stations it is handed**. Hand it the snapped list and `5@15240` stops fitting, so it
falls back to measuring the gaps and prints `1@14540 + 3@15240 + 1@14540` - the centre-to-centre
chain. That is the in-to-in number, arrived at silently, on a sheet headed by a BSF that says
15,240.

> **Every chain on every sheet is the estimator's expression with its basis spelled out.
> Nothing is measured off drawn stations. The arrows run to the out-to-out line, because that
> is the line the number describes.**

The same rule kills the duplicates: a mezzanine column chain that *is* the module chain, or a
footprint dimension that *is* the building's own width, says nothing new and is not drawn.

---

### 4B.64 Placement: drawing -> chains -> bubbles, outward, on every sheet

The three-nested-chains order (4-Jul) says finest inboard, overall outermost. It says nothing
about where the **bubbles** go, and the Column Layout Plan and the Mezzanine Floor Plan had
settled on opposite answers - one read outward as drawing -> chains -> bubbles, the other as
drawing -> bubbles -> chains. Same grid, two reading orders.

> **Bubbles are OUTSIDE the dimension stack, in both directions, on every sheet.**

And the bubble column is placed **from wherever the outermost rung finished**, never from a
constant: add a rung and the bubbles move with it (4B.27). The stalk is then a **tick**, not a
line back to the drawing - run it back to the deck edge and it rules straight through every
chain bar and every chain label on the way.

---

### 4B.65 One bubble size on every sheet - and why it is the BUBBLE that is corrected

**Owner, 3-Sep-2026, four times over:** *"Fix the bubbles issue."*

4B.31 gives one radius, `720 x TEXT-SCALE`, and every sheet obeyed it - and the bubbles still
did not match, because a **model** radius plots at `1440 x TS / sc`. TS is *estimated* from the
building's face; `sc` is *measured* from the drawn extents, which is that face **plus every
paper-sized dim chain, bubble stack, legend and heading hung off it**. A sheet carrying three
nested chains and a legend is fitted smaller than a bare elevation of the same building, and its
bubble plots smaller with it. Measured on MSPL-26-279, in true plotted millimetres:

```
Cross Section        6.01     Column Layout Plan       4.58
End Wall Framing     6.04     Mezzanine Floor Plan     4.74
Side Wall Framing    5.91     Roof Framing / Sheeting  4.84
Sheeting Elevations  5.21
```

A third bigger on one sheet than another - and *perfectly consistent within each sheet type*,
which is the tell: not noise, but the annotation profile of the sheet.

> **Each sheet declares its profile (`peb-bub-fit`) and the bubble is corrected for it. The
> factor is MEASURED - `peb-log-sheet` writes sheet no. / TEXT-SCALE / fitted scale to a CSV -
> never guessed.**

**It is deliberately the BUBBLE and not TEXT-SCALE.** Scaling all the lettering to close the same
gap costs the Column Layout Plan **13% of its drawing scale**, because bigger text means bigger
extents means a smaller fit. Correcting the bubble alone costs about 2%. The reference (1.00) is
set at the framing elevation and cross section - the two already near 6 mm - so nothing on the
set gets smaller. Result: **6.7-6.9 mm everywhere**, spread 33% -> 6%, and the plan held its
1:532.

Every sheet-level drawer sets `*PEB-BUB-FIT*` beside its `*PEB-TEXT-SCALE*`, and **none
inherits** - the whole lesson of the old `*PEB-BUBRAD*`, which the wall elevations read without
ever setting, so their bubble size depended on which sheet rendered before them.

---

### 4B.66 Masonry stops at the steel it meets

MSPL-26-279 states `BP_BRICK_HT` 5,029 (16'-6") and `MZ1_CH_FFL_BEAM` 4,877 (16'-0"). Both are
deliberate round imperial figures and **both are right** - they describe different places. The
brick dado is 16'-6" where nothing crosses it; the clear height under the mezzanine beam is
16'-0".

They meet only on the **end wall**, where the mezzanine main beam lies in the wall plane. There
the brick was drawn straight through 152 mm of steel, under a label reading H=5,029 on a sheet
that had just drawn the soffit at 4,877.

> **Where the mezzanine reaches an end wall, the masonry stops at the beam soffit - and the
> label says which level stopped it: `BRICK WALL (BY OTHERS) - H=4,877 (TO MEZZ. BEAM SOFFIT)`.**

H=4,877 under a stated 16'-6" dado reads as a mistake until the reader is told why. No BSF value
is changed; the drawing simply stops being unbuildable. Gated on the mezzanine actually reaching
that end, and on end walls only - on a side wall the beams frame in end-on, so the wall is
notched at each beam rather than capped.

---

### 4B.67 A named floor is named where it is MEASURED

The staircase elevation carried `MEZZANINE FLOOR` as a mark of its own on the left, and its
fifteen characters ran into the top flight's corner and its handrail - and, on a stair with two
plan blocks, into the plan's own `PLAN` caption, printing **MEZZANINE FLOORPLAN**.
Right-justifying it hangs 3.6 m of text off the left edge and costs a scale step for one word.

> **The level marker that MEASURES a line also NAMES it: `+5380mm   MEZZANINE FLOOR`. The mark
> on the far side keeps its triangle and its level line, but not the name.**

Corollary, and the reason the `F.F.L` elbow went the same way: one level, one name. Three labels
crowding a single line is not emphasis.

---

### 4B.68 Reserve space by MEASURING the block, not by a formula for it

`peb-stair-elev-drop` computed how far to drop the elevation below the plan. It is a formula,
and on a 10 m stair - three landings, **two** plan blocks - it came up short and the elevation's
head mark printed into the plan's caption. The plan drawer already **returns its true extents**.

> **Where a drawer returns its extents, place the next block from those. Keep the formula as the
> other half of a `min`, so whichever wants more room wins.**

This is 4B.27 one level up: a gap that has to clear something is measured from that thing -
including when the "something" is a whole block whose size depends on the job.

---

### 4B.69 A floor's TOP FACE is its F.F.L - so the last tread is one riser below it

**Owner, 3-Sep-2026:** *"Distance b/w the final step and FFL should be 150mm."*

It was 249. The two floors on the staircase elevation were drawn in **opposite directions**:

```
  ground     slab from  oy - 100  UP TO  oy        top face = F.F.L      correct
  mezzanine  slab from  ycur      UP TO  ycur+100  top face = F.F.L+100  wrong
```

So the flight arrived at the **soffit** of the floor it serves, and the step from the final tread
onto the finished floor measured one riser *plus the slab*.

The sheet was already contradicting itself, which is the tell: the level marker prints **+5,380 at
`ycur`** and calls it MEZZANINE FLOOR, while the concrete drawn there put the walking surface at
+5,480. One of the two had to be wrong, and it was not the marker.

> **Every floor on the sheet is drawn the same way: top face ON the level, concrete hanging BELOW
> it. The last tread of a flight then sits exactly one riser under the F.F.L - which is what a
> final riser IS.**

Two things follow, and both were wrong for the same reason:

- **Hatching goes INSIDE the slab.** Both bands were hatched over a 150-200 range against a 100
  band, so at ground two of four lines were drawn on or above the finished floor. Hatch is what
  tells a reader the band is concrete; outside the band it says the floor is somewhere it is not.
- **A level mark with no text gets no standoff.** `peb-stair-floor-mark` offsets its symbol to keep
  the *text* clear of the hatch. Once the mezzanine's name moved to the right-hand level column
  (4B.67) that mark had no text left, and kept standing a quarter of a metre clear of the line it
  points at - a level symbol in the wrong place, on a drawing whose subject is levels.

Verified on MSPL-26-279 by measuring the plot: floor line to top tread **2.88 pt** against a riser
pitch of **2.82 pt** - one riser, 149.44 mm, which is the 150 nominal the equal-riser rule aims at.

---

### 4B.70 A dimension too small for its text puts the TEXT outside - or drops the words

**Owner, 3-Sep-2026:** *"Avoid the overriding & fix the dim properly."*

A dimension label was always centred on its dimension, however long the text or short the span.
`"2690 FULL LANDING HEIGHT"` is twenty-four characters against a 2,690 mm span: at 1:152 the
string is two and a half times longer than the thing it measures, so it overran both arrows and
printed across whatever was below. `"1200 LANDING"` beside `"5400 FLIGHT RUN"` printed as one
word - **`5400 FLIGHT RUN1200 LANDING`**.

Two rules, applied in order:

> **1. Where the text will not fit between the arrows, it goes OUTSIDE them** - past the upper
> arrow on a vertical, past the right-hand one on a horizontal. That is what a draughtsman does,
> and it leaves the neighbouring dimension its own room.
>
> **2. Where even that will not read, the NESTED-CHAIN rule applies instead: the span that can
> carry a description carries it; the ones inside it carry values.**

So the staircase elevation reads `5,380 [17'-8"] STAIRCASE HEIGHT` outside and a bare `2690`
inside; the plan reads `1200 / 5100 FLIGHT RUN / 1200`; and the section reads `2600` with
`O/O OF STEEL COLUMN (1200 + 200 + 1200)` on the line beneath - the line that has room for it.
Nothing is lost: the level column beside the stair already prints `+2690MM` against that line.

---

### 4B.71 One text height per sheet - and the blocks are placed by MEASUREMENT, not by constants

**Owner, 3-Sep-2026:** *"Text of stair is too small"* · *"Fix all the labelling of staircase"* ·
*"Do the best refinement."*

**THE SIZE.** The staircase sheet carried **three** text heights and only one was ever tuned: the
section lettered at `1.5u`, the step detail at `1.4u`, the rest at `2.2u`. Two of six blocks
printed a third smaller than everything around them, which is most of "too small" on its own -
a reader judges a sheet by its smallest legible text. One function (`peb-stair-th`), asked by
every drawer (4B.9).

**THE PLACEMENT.** Every block sat at a constant number of stair-widths from the plan - 5.5 for
the section, 10.0 for the layout plan. That holds only while the lettering never changes, and the
moment the text was raised the sheet folded into itself: the step detail landed inside the base
plate plan, `SECTION A-A`'s caption printed through the layout plan's. It is 4B.27 at block
scale - a gap that has to clear TEXT, measured in something other than the text.

> **Blocks are paired by SHAPE and placed by measurement.** The two long-and-low plans on one
> line, the two tall views on the next, the two small ones under those - which is what keeps the
> sheet narrow, because three views across a line is what forces the scale down.
>
> **And a block is cleared by its EXTENT, not by its origin.** The step detail grows *upward*
> from the point it is given, so its origin drops by its own height as well as by the section's
> dimensions above it.

**THE DETAIL THAT WAS SMALLER THAN ITS OWN LABELS.** A step is 300 x 149 - 2 mm by 1 mm at sheet
scale, while `"300 GOING"` is four times wider than the step it points at and the plate note ten
times wider. **No amount of moving labels fixes a view smaller than its own lettering: the view
has to grow.** Drawn x4, with the dimensions still stating the TRUE value (pass a pre-formatted
string; `peb-stair-dimtext` passes through anything already starting with a digit), so nothing
reports the drawing's size instead of the steel's.

---

### 4B.72 A column stops at the landing it carries

**Owner, 3-Sep-2026:** *"In case of more landing than 1, columns should reach till landing, not
in the air"* · *"Remove extending portion & column will go till last mid landing."*

Both column pairs ran to the TOPMOST mid-landing - right for the pair that landing sits on, wrong
for the other. Landings alternate ends, so on a three-landing stair:

```
   right-hand pair   carries  +2537  and  +7612     ->  runs to 7,612
   left-hand pair    carries  +5075                 ->  runs to 5,075
```

Running the left pair to +7612 as well left 2.5 m of column standing above the last thing it
holds - the same "column in the air" struck off the one-landing sheet on 1-Sep, one landing
further up.

> **Count the two ends separately. Landing `i` is at `xhi` for even `i` and `xlo` for odd `i`;
> each end's columns rise to the highest landing on THAT end, and no further.**

**A trap worth the line it cost.** The first cut used `(> colHi 0.0)` to mean "this end has a
landing". The elevation is placed at a large NEGATIVE origin - blocks stack downward from the
plan - so every level is below zero and **every column silently vanished from the sheet**. An
absolute coordinate is never a flag; use `nil`.

---

### 4B.73 A position is stated ONCE, and every sheet that draws it asks the same function

**Owner, 3-Sep-2026:** *"Sync all the details with each other of stair and its sync with
mezzanine plan and CLP, then audit."*

`ST<n>_OFFSET_Y` is one number in the BSF. Three sheets drew from it and two of them read it
differently:

```
   mezzanine floor plan   offY = the CENTRE of the stairwell, spanning offY +/- 1,300
   column lay-out plan    offY = the LOWER edge,  columns at offY and offY + 1,200
```

So one stated offset put the same staircase in two places 1,300 mm apart, and - worse - the CLP
called the column spacing **1,200** while the staircase sheet's own base plate plan dimensioned
the very same pair at **2,600 O/O OF STEEL COLUMN**. A contractor setting out from the CLP would
have cast the bases on the flight lines instead of the tower corners.

Neither sheet was "wrong" in isolation. The fault is that each did the arithmetic itself.

> **Where two sheets draw the same thing, ONE of them owns the geometry and the other asks it.**
> The CLP now calls `peb-mzfp-stair-org` - the mezzanine plan's own placer - and stands its
> columns on what comes back. `offY` is the stairwell CENTRE everywhere, the columns are on the
> tower's outer lines everywhere, and the clamp that keeps a stair on the deck it serves now
> applies to both plans instead of one.

**The same rule caught the label.** `onREW` was set only on the fallback path, so a stair placed
from its BSF offsets always printed `(LEW)` - ST2, at 42,260 of a 54,860 m building and hard
against the right end wall, was labelled as being at the left one. **An end is not an input; it
is a consequence of the position.** Read it off the column that has just been placed.

**And an audit is a program, not a squint.** `_syncaudit.js` reads the generated PEB data and
asserts across sheets - stair height against `MZ_FLOOR_HT`, offsets inside the building extents,
the two end walls carrying the same post chain. It found `ST1_HEIGHT 5380` against
`MZ_FLOOR_HT 5379`: a stair climbing to a level one millimetre off the floor it lands on, which
no drawing would ever show but every dimension would carry.

---

---

## STAIRCASE — the Mammut convention, harvested 1-Sep-2026

Source: **Mammut Technical Manual, Chapter 12 "STAIRCASE & LADDERS", Section 12.1 "Staircase &
Handrails"** — `D:\Design Manual\Technical Manual.pdf`, pages 307-319 (13 sheets). Read the
figures, do not paraphrase this section from memory: it is the ground truth for every label
below ([[maimaar-drawings-reference-first]]).

**The standard staircase is a DOUBLE FLIGHT with an intermediate (mid) landing** — the manual's
own words. Single flight is offered too. Stringers are a hot-rolled channel or a single plate.
Treads may be checkered plate, grating, concrete-filled steel or plain RC, interchangeable
without modification. **Staircase paint matches the primary member's paint** — it is never
specified separately.

Manual sheet 5 of 13 (p311) is the case Maimaar quotes most often and the one 279-26-MSPL asks
for: **SINGLE FLIGHT STAIRCASE WITH TOP-MID LANDING** (`ST<n>_TOP_LANDING=1` +
`ST<n>_MID_LANDING=1`).

### PLAN — what is drawn, and the exact words

The flight is a band between two **stringers** (the long edges), with tread lines across it.
Landings are separate platforms at each end of the run, each closed by a **landing beam**.

| Element | Label, verbatim |
|---|---|
| Long edges of every flight | `STRINGER` |
| Tread lines | `TREAD (TYP.)` |
| Beam closing the top landing | `TOP LANDING BEAM` |
| The top landing itself | `TOP LANDING PLATFORM` |
| Beam(s) at the mid landing | `MID-LANDING BEAM` — reads vertically, inside the landing |
| The mid landing itself | `MID-LANDING PLATFORM` |
| Post under the mid landing | `MID-LANDING POST` — a filled circle in plan |
| Bracing at the mid landing | `CABLE BRACING` |
| Climb direction | `UP` at the FOOT, on a leader with a small open circle |
| Overall run dimension | `STAIRCASE LENGTH` |
| Sheet title | `PLAN`, underlined |

The climb arrow is a **single line along the centre of the run with a solid arrowhead at the
TOP (mezzanine) end and a small open circle at the foot**, `UP` lettered beside the circle. It
is not an arrow at each end, and `UP` is not written along the flight.

### ELEVATION / SECTION — what is drawn

| Element | Label, verbatim |
|---|---|
| Rails, near and far side | `HANDRAIL (NS / FS)` |
| Kick plate at every landing | `TOE PLATE` |
| Deck the stair lands on | `MEZZANINE LEVEL` |
| Beam(s) at the head | `TOP LANDING BEAMS` |
| Beam(s) at the mid landing | `MID-LANDING BEAMS` |
| Post under the mid landing | `MID-LANDING POST` |
| Sloping member | `STRINGER` |
| Treads | `TREAD (TYP.)` |
| Ground datum | `FINISH FLOOR LEVEL` |
| Base fixing | `EXPANSION BOLTS` |
| Vertical dims | `STAIRCASE HEIGHT`, `MID-LANDING HEIGHT` |
| Horizontal dims | `TOP LANDING WIDTH`, `MID-LANDING WIDTH`, `STAIRCASE LENGTH` |
| Sheet titles | `ELEVATION`, then the type, both underlined |

**Handrail set-out is `475` above `425`** — the two dimensions the manual carries on every
elevation, measured up from the walking surface. Draw them; they are the only numbers on the
handrail and they are what makes it read as a Mammut rail rather than a generic railing.

### What this means for the engine

The current plan drawer is a **flat footprint with tread lines and a rotated "UP"** — it has no
stringers, no landing platform, no landing beam, no mid-landing post, no cable bracing, and it
letters `UP` along the run instead of at the foot. Every one of those is a named element on the
manual sheet, so the footprint is not a staircase yet, it is a hatched rectangle.

### STAIRCASE — corrected against Maimaar's OWN issued drawing, 1-Sep-2026

Source: **055-MSPL Style Textile, "STAIR CASE FOR FF2 MEZZANINE", Rev-01, sheet 06 "ELEVATION AT
GRID-B"** (`E:\Maimaar Steel Pvt Ltd\Jobs\2022\055-MSPL_Style Textile_Stairs`). An issued,
for-approval drawing beats both the manual and any inference. Where this and the Mammut manual
disagree, **this wins** — it is what Maimaar actually builds.

| | Maimaar issued drawing | what the sheet had before |
|---|---|---|
| Handrail height | **1100 mm** | 900 (475+425) — WRONG |
| Going | **280 mm** | 260 (from the manual) |
| Stringer | **C-200x75x6x6** channel | plain 250 deep band |
| Handrail | **Ø42.7 mm pipe, 1.291 mm wall** | plain lines |
| Rail infill | **Tube 50x5 / 50x3** | none |
| Tread support | **L-50x50x5, 2 per step, welded to stringer** | none |
| Landing beam | **Main Beam F=100x5 W=250x4** | plain rectangle |
| Column | **F=150x6 W=250x5**, full height, on a 200 mm pedestal | stub post under the landing |
| Base plates | **CBP-01** (column), **SBP-01** (stringer) | none |
| Material | **Grade 50 throughout the staircase** | not stated |

**THE 475/425 IN THE MAMMUT MANUAL IS NOT THE HANDRAIL HEIGHT.** They are the rail spacings
drawn above a mezzanine deck. The staircase handrail is **1100**, which is also exactly what the
BSF already says — its field reads *"1.1m High Handrails Included"*. Two independent sources and
the form all agree; the sheet was the only thing that did not.

**The columns run full height past the staircase** and the flights hang off them through the main
beams — they are not stub posts standing under each landing. On a multi-storey stair the same
two columns carry every landing.

### A U-TYPE HAS TWO FLIGHTS PER STOREY — AND THE PLAN MUST DRAW EVERY ONE OF THEM

**Owner, 1-Sep-2026:** *"Actually there is contradiction b/w the plan and section"*, and, pointing
at the same reference: *"this is special for multi-storey U-Type Staircase, Section, Plan, Column
Layout Plan."*

He was right, and it was measurable. On **MSPL-26-279** (Sky Power, two U-shape stairs, 1,200 wide,
5,380 mm mezzanine, top + mid landing) the sheet drew:

| | flights | risers | climb drawn |
|---|---|---|---|
| PLAN | 2 | 24 (11 + 11 tread lines) | 3,600 mm |
| ELEVATION | 3 | 36 (levels +0 / +1793 / +3587 / +5380) | 5,380 mm |

Both views read the same `peb-stair-flights` list — that much had already been fixed. The fault was
one level down: `peb-stair-plan-u` took `(nth 0 fl)` and `(nth 1 fl)` **and drew only those two**,
whatever the length of the list. A U plan can lay out two bands, the split asked for three, and the
third flight was dropped silently. Reading the same rule is not the same as drawing the same stair.

**Two rules come out of it, both taken off 055-MSPL, not invented.**

**1. Risers per flight is 18, not 12.** 055-MSPL numbers every riser on its floor plans. Counted
off the drawing: **13 · 14 · 14 · 14 · 14** (flights 1-13, 14-27, 28-41, 42-55, 56-69). Never 12,
never more than 15. The 12 in the engine came from the strict end of the BS 5395 range; IBC has no
riser-count limit at all, only the 3658 mm rise between landings. An issued approval drawing beats
a code range read at second hand. At 18, a 5,380 mm storey splits 18/18 — two flights, which is
what a U *is* — and plan and elevation agree by construction.

**2. More than two flights means more than one PLAN.** 055-MSPL's own sheet index carries
**"MAIN BEAM - CHECKERED PLATE - TUBE - STRINGER - LAYOUT PLAN" three times, one per floor**, each
plan holding that floor's two flights, riser numbering running continuously across all three
(1-13, 14-27 | 28-41, 42-55 | 56-69), one `UP` per plan, with **ELEVATION AT GRID-B** (along the
run) and **ELEVATION AT GRID-1 & 2** (across it) carrying the whole climb. So `peb-stair-plan-u`
now takes the flights **in pairs**, draws one plan block per pair, stacks them down the sheet and
captions each `PLAN AT LEVEL n` — with the set captioned `PLAN` once, underneath. A two-flight
stair produces exactly one block and one caption, so the ordinary mezzanine sheet is unchanged.

`peb-stair-elev-drop` adds the extra blocks' pitch, or the elevation lands on top of plan two.

**The general rule, worth more than either number:** when a view cannot hold what the data says,
it must draw more views — never quietly draw less. A dropped flight looks exactly like a stair
that was designed shorter.

### THE LANDING RULE: the step count decides, against an approved internal standard

**Owner, 1-Sep-2026:** *"Add the Rule of no. of landing based on the no. of steps must be less than
approved as per the internal standards"*, *"There must be Autodivision Rule & should be flexible
till 2-4 steps"*, and *"our priority is to keep the rise to 150mm."*

> **No flight may carry more steps than the Maimaar approved maximum. The number of intermediate
> landings is whatever it takes to satisfy that — never a number someone types in.**

| Constant | Value | Source |
|---|---|---|
| `peb-stair-rise` | **150 mm** | house standard; *priority is to keep the rise to 150* |
| `peb-stair-going` | **300 mm** | house standard |
| `peb-stair-max-risers` | **15** | Maimaar approved maximum steps per flight |
| `peb-stair-step-tol` | **3** | the 2-4 step flexibility, spent **on the cap** |
| `peb-stair-max-rise` | **3658 mm** | IBC 1011.8, rise between landings |

1. `risers = round(height / 150)` — the rise is fixed, so the step count follows from the climb.
   **Never stretch the riser to make a split come out neatly.**
2. `flights = max( ceil(risers / (15+3)), ceil(height / 3658) )` — the flexible ceiling decides the
   flight count, because the whole point of the tolerance is to avoid adding a landing for the sake
   of one or two steps.
3. `intermediate landings = flights − 1`.
4. Steps are then **divided equally**, remainder to the lowest flights. So the tolerance decides
   *how many* flights and the equal split decides *how long* each is — two mechanisms, two jobs.

**Why 15 and not 12, and not 18.** 055-MSPL numbers every riser; counted off it the flights are
**13 · 14 · 14 · 14 · 14** — its own maximum is 15. IBC has no riser-count limit at all, only the
3658 mm rise, so the old 12 came from the strict end of BS 5395 read second-hand and is contradicted
by Maimaar's own issued drawing. A flat 18 (which this file briefly carried) is the right *ceiling*
but the wrong *standard*: it silently licenses every flight to run three steps longer than anything
Maimaar has issued. Hence two constants, not one.

**The rule reproduces the reference — and a caution about how that was checked.** Feeding
055-MSPL's own step counts through the division rule gives its own flights exactly:

| its steps | rule gives | drawn on 055-MSPL |
|---|---|---|
| 27 | 14 / 13 | **13 · 14** |
| 28 | 14 / 14 | **14 · 14** |
| 14 | 14 | **14**, single flight |

**Do not check it the other way round.** The first version of that test re-derived the step count
from the reference's storey heights using *our* 150 mm riser and "failed" — because 055-MSPL was
built at a **~187 mm** riser, so on the same 5054 mm storey it has 27 steps where we would have 34.
That is the house standard outranking one job, exactly as intended, not a disagreement. The
division rule and the riser standard are separate things and must be tested separately.

### The rule is printed on the sheet

`peb-stair-rulenote` draws it small, at the very bottom, under everything — the place and weight of
055-MSPL's own *"NOTE: Grade 50 Material Is Used In Stair Case"*. It states the rule **and this
staircase's own numbers**, generated from the same `peb-stair-flights` list the views are drawn
from. That is the point of putting it on the drawing rather than only here: if a drawer ever again
draws a different number of flights than the rule produced — the 279-26 fault — the note and the
drawing contradict each other on the customer's own sheet. A silent fault becomes one anybody sees.

### Level captions name their levels, not an ordinal

055-MSPL captions its floor plans `PLAN FROM F.F.L TO 5054mm LEVEL`, `PLAN FROM 5054 TO 10257mm
LEVEL`. `peb-stair-level-caption` builds exactly that. An ordinal ("PLAN AT LEVEL 2") tells a reader
nothing they cannot already count; the levels tie the plan to the elevation's own level markers,
which are drawn in those same numbers.

### Two new views, both off the reference

**`peb-stair-collayout`** — the reference's APR-01. It answers the one question the walking plan
cannot: *where does this staircase land on the floor*. `CBP-01 (QTY-04)` — four column base plates,
a pair on each column line — and `SBP-01 (QTY-02)` — two stringer base plates at the foot.
**It does not grow with the landing count:** the columns run full height and every storey's landing
hangs off the same two column lines, so a four-landing stair has the same four base plates as a
one-landing stair. Dimensions carry the reference's own wording, value first, description after:
`O/O OF STEEL COLUMN`, `C/C OF STEEL COLUMN`, `C/C OF STEEL COLUMN TO BASE PLATE OF STRINGER`.

**`peb-stair-stepdetail`** — the reference's *"Typical Detail of Steel Checkered Plate Step"*
(nosing 25, plate 6). **Form from the reference, numbers from ourselves:** it is dimensioned from
`peb-stair-going` / `peb-stair-rise`, not the reference's 280/185, so it can never drift from the
stair drawn beside it on the same sheet. Parts are **named, not sized** — `STRINGER`, `TREAD CLEAT`
— because PD is blind by default and a section size is designed-steel information. The plate
*thickness* is stated, because that is what the customer is buying, not a designed section.

### STANDING RULE — ALL RISERS MUST BE EQUAL

**Owner, 3-Sep-2026:** *"Standing Rule for staircase — All Riser Must be Equal."*

This **supersedes** the 1-Sep rule that held the riser at exactly 150 and took the remainder at the
base. That rule is recorded below, because the reason it was wrong is the point.

**What 150-exactly actually drew.** `round(h/150) × 150` overshoots the storey by up to half a
riser, and the leftover went into the base: a 5,380 mm storey drew 36 × 150 = 5,400 and the stair
sprang from **−20**. So every riser measured 150 — *except the first one a person steps on*, which
measured **130** from the finished floor. The sheet stated "ALL RISERS 150MM EXACTLY" directly
above a drawing of an unequal flight.

A 20 mm odd riser at the foot of a flight is a trip hazard, and it fails the uniformity both
**IBC 1011.5.4** and **BS 5395** require — risers within about 3 mm of each other. Holding a
nominal at the cost of the one riser that varies gets the priority backwards.

> **THE RULE.** Equality is the invariant; 150 is the target the count aims at.
>
> ```
> count = round(height / 150)     <- 150 chooses HOW MANY
> riser = height / count          <- and the height decides the rest
> ```
>
> Every riser identical. The stair springs from **F.F.L** and the head lands on the deck, because
> `count × (height/count)` *is* the height — there is no remainder left to hide.

5,380 / 36 = **149.44 mm**, landing +2,690, head +5,380, base 0.

`peb-stair-rise` takes the height and returns the equal riser; `peb-stair-risers` still asks the
**nominal** (`peb-stair-rise-nom`), because it is choosing the count and asking the actual riser
there would be circular. `peb-stair-base-offset` returns **0.0** and is kept only because every
drawer asks it.

**One riser, stated once.** The specification block used to print a hard-coded `RISE PER STEP :
150 MM` while the note beside it derived the real figure — two risers for one staircase on one
sheet. Both now read the same function, and the typical step detail dimensions it too.

*(Superseded, 1-Sep-2026: "every riser is exactly 150 and the odd millimetres go at the base",
justified by the grout bed under the base plates. The grout bed is real; using it to absorb a
20 mm error in the bottom riser was not.)*

### THE COLUMNS CARRY THE MID-LANDINGS — SO THEY STOP AT THE HIGHEST ONE

**Owner, 3-Sep-2026:** *"In case of Intermediate Floors, the columns will extend till highest
mid-landing. In case mid-landings are > 1, 4 columns will come on 4 corners — only if the landings
are more than 1. Overall: the columns support the mid-landing between the floors, and the stringer
rests on the F.F.L for each floor."*

This **supersedes** both earlier passes — "four columns to the top, for any number of landings"
(1-Sep) and "trim at the first landing" (2-Sep). The ruling states the *reason*, and the reason
settles the height and the count together.

**What a stair column is for.** At every floor the stringer bears on the **F.F.L** — the slab
carries it, nothing else is needed. The one place a flight has nothing to land on is a **mid-landing
between two floors**. That is what the columns hold up, and it is the whole of their job.

> **HOW HIGH.** Columns run from the floor to the **highest mid-landing**, and stop. Above it the
> last flight is already held at both ends — by the landing it leaves and by the deck it arrives
> on — so steel carried higher stands in air holding nothing.
>
> **HOW MANY.** **Four**, at the tower corners, **when there is more than one mid-landing**:
> landings alternate ends as the stair switches back, so each end needs a pair. With **exactly one**
> mid-landing there is one end to hold, so **one pair**, at that landing's own end.

The owner's markup that forced this: *"this side encircled column will not go in the air as there
no support required in case of one mid landing"* — a 279-26 stair with one landing was drawing a
second pair of columns from the floor up to a landing at the other end of the tower.

On 279-26 (2 flights, 1 mid-landing at +2,690): **one pair, at the landing end, floor to +2,690.**

`nland = flights − 1`. The topmost mid-landing sits above every flight but the last, so its height
is `rise × Σ(flights[0 … n−2])`. The U alternates ends, so landing *i* is at `xhi` for even *i* and
`xlo` for odd *i*; the topmost is at `xhi` when `nland` is odd.

*(Superseded: the 1-Sep "columns go till top, 4 corners, any number of landings", which cited
055-MSPL's `CBP-01 (QTY-04)`. That drawing has FOUR intermediate landings — four corner columns is
the right answer for it, and this rule still gives that answer. What it no longer does is give
four columns to a stair with one landing.)*

### THE LANDING IS A FULL LANDING, AND THERE IS NO TOP PLATFORM

The intermediate landing spans the **whole stairwell** — both flight bands and the well between
them — because a person climbs flight 1, turns on it, and sets off up flight 2. It is a **FULL
landing**, not a half one, and that is the word on the drawing and in the code.

And **the second landing IS the mezzanine floor.** `ST<n>_TOP_LANDING` no longer draws a platform;
drawing one in front of the deck invents a step that does not exist. The field is read for the
sheet title only.

The title therefore names what actually varies — the number of **intermediate** landings, derived
from the flight list like everything else: `STAIR ST1 - U-SHAPE STAIRCASE WITH 1 INTERMEDIATE
LANDING`.

### A DIMENSION CARRIES ITS MEASUREMENT, AND EACH FACT APPEARS ONCE

**Owner, 1-Sep-2026:** *"clear the mixed labelling and show the clear dimensions."*

**Every dimension prints its value.** The main views were drawing a dimension line with a
description and no number — `STAIRCASE LENGTH`, `MID-LANDING HEIGHT`, `OUT TO OUT WIDTH`. That is a
caption sitting on a dimension line: the sheet *looked* dimensioned while telling the reader
nothing. `peb-stair-dim` / `peb-stair-vdim` now measure themselves from the endpoints they are
already given, so **a caller cannot forget and the number cannot disagree with the line it sits
on**. Format is the reference's own — value first, description after: `6318 C/C OF STEEL LINE`.

**One fact, one place — the view that owns it.**

| view | owns |
|---|---|
| PLAN | the footprint — flight run, landing, overall length, out-to-out width |
| ELEVATION | the climb — level markers, full-landing height, staircase height |
| SECTION | the width across, and the part names |
| COLUMN LAYOUT | base plates and the dimensions between them |
| STEP DETAIL | going, riser, nosing, tread plate |
| SPEC NOTE | only what no view can draw — type, tread material, handrail, which mezzanine |

The section used to repeat the elevation's `STAIRCASE HEIGHT`, its whole set of `+NNNNmm` markers
and the stair title; the spec note repeated the width, the height and the landing platform. Stating
a fact twice is worse than stating it once: a reader who notices a difference has no way to tell
which is authoritative, and nothing forces the two to agree except that both happen to be right
today.

### NEVER WRITE "MAMMUT" ON A DRAWING — the grep that proves it

Standing rule, restated 1-Sep-2026. Exactly one **drawn** string in the engine ever broke it —
`MAIMAAR_PEB_Stair.lsp`'s load note, `REFERENCE : BS 6399 / MAMMUT DESIGN MANUAL …`, now
`REFERENCE : BS 6399 - LIVE LOADS, TABLE 4.10`. BS 6399 *is* the standard; the manual was only
where it was read, and that provenance belongs here, not on a customer's sheet.

The check, before any release that touches a note block:

```
grep -rn -i mammut engine/*.lsp | grep -v '^[^:]*:[0-9]*: *;;' | grep -v peb-titleblock-mammut
```

Anything it returns is on paper. Comments and the function name `peb-titleblock-mammut` never
reach the sheet and are not the concern.

### THE SWITCHBACK STACKS — IT DOES NOT WALK SIDEWAYS

**Owner, 1-Sep-2026**, marking up the 3-landing render in red and green
(`D:\Sales Department\MSPL\Proposals\2026\279-26-MSPL_…\Rendered Pictures\`):
*"see the 2nd landing which should be outside and green column will come, also stringer will start
from right edge of 2nd landing."*

Both the plan and the elevation advanced their cursor **past** the landing, so every flight began
one landing further along than the last:

```
  WRONG                                 RIGHT
  flight 1     0 -> 5100                flight 1     0 -> 5100   landing out to  6300
  flight 2  6300 -> 1200                flight 2  5100 ->    0   landing out to -1200
  flight 3     0 -> 5100                flight 3     0 -> 5100   landing out to  6300
  ...the stair walks right               ...it stacks in one footprint
```

**A flight turns at the INNER edge of the landing it leaves, and the landing projects OUTWARD
past the end of the flight that arrived on it.** The cursor does not move out with the landing.
Two consequences:

- The flights then **overlap in x**, which is correct — they are at different *depths*, and an
  elevation looks along the depth. A switchback drawn flat is supposed to cross over itself.
- **Outward is the only place the landing can physically go.** Hung back over the foot of the
  flight below it would leave no headroom on the bottom steps.

The tower therefore spans `-lw … run + lw`, and that outward face is where the near columns stand —
the green line on the owner's markup falls out of the geometry rather than being placed to match it.

**A two-flight stair hides this completely** (on flight 1 the two conventions agree), which is why
it survived until a three-landing stair was asked for. The general lesson: a rule that is only
exercised in one direction has only been tested in one direction.

**And the landing between two plan blocks belonged to neither.** Block 1 drew flights 1-2 and their
far landing, block 2 drew flights 3-4 and theirs, and the landing you actually turn on to get from
one to the other fell down the gap. Every block above the first now draws the outward landing it
steps off, and — because the columns belong to the **tower**, not to the block — every floor plan
places its near columns at that outward face, including the ground block that has no landing there.
Otherwise one staircase's four columns appear at two different x on two of its own plans.

### COLUMNS TRIM AT THE LANDING THEY CARRY — THEY DO NOT FLOAT IN THE AIR

**Owner, 1-Sep-2026**, marked-up images from `D:\Sales Department\MSPL\Proposals\2026\279-26-MSPL_…\Rendered Pictures\`:
*"Trim the Columns at this level as marked.PNG"* and *"This side Encircled Column will not go in the Air as there no support required in case of one mid landing."*

The **structure** is four columns at the four corners of the stair tower. **They run from the floor to the bottom face of the highest landing at their end**, not to the mezzanine. Above the last landing the next flight is already supported at both ends — by the landing it leaves and the mezzanine or next landing it arrives on. Columns there would carry nothing and would float in mid-air.

In a U-stair, landings alternate ends: landing 0 is at RIGHT (where flight 1 lands), landing 1 is at LEFT (where flight 2 lands), landing 2 is at RIGHT, and so on. **Left columns run to the highest odd-indexed landing, right columns run to the highest even-indexed landing, or both run to the mezzanine if no such landing exists.**

| stairs | left pair | right pair |
|---|---|---|
| 1 landing | floor → mezzanine (carries landing 0 + flight 2 above) | floor → landing 0 (carries it, nothing above) |
| 3 landings | floor → landing 1 (carries it + flights 1-2) | floor → landing 2 (carries it, nothing above) |

`peb-stair-col-max-h` computes this: it takes a column index (0=left, 1=right), the list of landing heights, mezzanine height, and the stair shape, and returns the maximum height that column pair should extend to. Both `peb-stair-elev` and `peb-stair-section` call it before drawing their columns.

**Test by rendering a 1-landing and 3-landing stair:** the two column pairs should have different heights, and on a 1-landing stair the right pair should trim at the landing, not extend to the mezzanine.
