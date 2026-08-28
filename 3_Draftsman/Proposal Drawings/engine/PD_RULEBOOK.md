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
100 mm. *(*PEB-CP-THK/GAP/EXT*, Section.lsp:3609-3611)*

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
`RA_TURBOVENTS`, `RA_ROOF_OPENING`) via `peb-draw-roof-accessories` — the same
routine the Column Layout Plan uses. One source, no second opinion: if the BSF
declares none, the sheet draws none.

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
| Eave gutter | `Jobs59-MSPL_PAECO\Approval drawing\Eave Gutter9-MSPL_Eave Gutter.pdf` | **traced** — 165 base, 203 deep, 1.2 mm PPG.L, 3 m |
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

## 5. THE DOC SET (how the four files relate)
| File | Holds | Read it when |
|---|---|---|
| **PD_RULEBOOK.md** (this) | Every rule, organized; the BSF↔PD contract | You want the law — what must/mustn't happen |
| **PD_MASTER_REFERENCE.md** | LSP code/function index · full per-key trigger matrix · coverage ledger | You need to know what a specific field/key does end-to-end |
| **PD_BSF_SYNC_MECHANISM.md** | The zero-conflict mechanism: key contract · drift guard · shared core · default policy · realtime · gap register | You want to guarantee BSF and PD can never drift, or to fill a gap |
| **DRAWING_CONTENT_RULES.md** | Per-sheet element-ownership matrix | You need to know which sheet owns an element |
