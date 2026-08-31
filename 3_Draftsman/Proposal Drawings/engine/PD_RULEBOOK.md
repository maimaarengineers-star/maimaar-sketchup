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
