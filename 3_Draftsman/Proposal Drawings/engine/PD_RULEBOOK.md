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

## 5. THE DOC SET (how the four files relate)
| File | Holds | Read it when |
|---|---|---|
| **PD_RULEBOOK.md** (this) | Every rule, organized; the BSF↔PD contract | You want the law — what must/mustn't happen |
| **PD_MASTER_REFERENCE.md** | LSP code/function index · full per-key trigger matrix · coverage ledger | You need to know what a specific field/key does end-to-end |
| **PD_BSF_SYNC_MECHANISM.md** | The zero-conflict mechanism: key contract · drift guard · shared core · default policy · realtime · gap register | You want to guarantee BSF and PD can never drift, or to fill a gap |
| **DRAWING_CONTENT_RULES.md** | Per-sheet element-ownership matrix | You need to know which sheet owns an element |
