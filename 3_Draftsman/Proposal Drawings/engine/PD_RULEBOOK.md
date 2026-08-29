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

Draw the owner's own numbers, mid-range — **main beam 325, joist 175, secondary 125** — so the
sheet shows the steel that is quoted.

**The legibility floor is a rule, not a fudge.** Every sheet is auto-fitted to A4, so a fixed
model width plots *smaller* the bigger the building; past ~93 m a 175 mm joist flange closes to a
single line and stops reading as a member at all. The floor is expressed in `*PEB-TEXT-SCALE*` —
the engine's existing "constant on paper" unit — and tuned to engage only ABOVE that size, so at
93 m and below the members plot at TRUE width.

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

## 5. THE DOC SET (how the four files relate)
| File | Holds | Read it when |
|---|---|---|
| **PD_RULEBOOK.md** (this) | Every rule, organized; the BSF↔PD contract | You want the law — what must/mustn't happen |
| **PD_MASTER_REFERENCE.md** | LSP code/function index · full per-key trigger matrix · coverage ledger | You need to know what a specific field/key does end-to-end |
| **PD_BSF_SYNC_MECHANISM.md** | The zero-conflict mechanism: key contract · drift guard · shared core · default policy · realtime · gap register | You want to guarantee BSF and PD can never drift, or to fill a gap |
| **DRAWING_CONTENT_RULES.md** | Per-sheet element-ownership matrix | You need to know which sheet owns an element |
