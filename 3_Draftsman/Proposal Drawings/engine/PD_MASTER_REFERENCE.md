# PD MASTER REFERENCE — LSP engine, rules, and IF/BSF ↔ PD sync

**Purpose.** One document that compiles *everything* about Proposal Drawings so nothing
falls through a crack: the full LSP code index, the standards it draws to, and — the heart
of this file — the **end-to-end trigger matrix** that proves every IF/BSF field either
reaches a drawing or is knowingly accounted for. Built to answer one question for any
field: *"If I tick/type this in the BSF, what draws — and if nothing draws, why not?"*

**Status.** Consolidated 21-Jul-2026 from a line-level audit of both sides of the pipe.
Every row is code-grounded (file:line). Companion docs: `PD_GLOBAL_RULES.md` (the binding
rules), `DRAWING_CONTENT_RULES.md` (per-sheet element ownership).

**Terms.** **IF** = Inquiry Form. **BSF** = Building Specification Form (the single source
of truth; a second front-end view over the same inquiry/building/area DB rows the IF writes).
**PD** = Proposal Drawings.

**Legend (status column):**
✅ live end-to-end · ⚙️ live but a silent server default can print an un-entered value ·
❌ **DEAD** (emitted by the bridge, no engine reader — verified) · ⚠️ mismatch / should-draw-but-doesn't (review) ·
➖ emitted but PD-irrelevant by design (commercial/title text only).

---

## 0. THE PIPELINE (how a field becomes a line on paper)

```
 IF / BSF form (browser)                         Node/TS bridge                         AutoLISP engine
 public/modules/sales/spec.js  ─ writes DB ─►  services/drawingData.ts  ─ writes ─►  MAIMAAR_PEB_*.lsp
 inquiries / inquiry_buildings                  generate(): serialise +               peb-v3-read-file → alist
 inquiry_areas                                  ×1000 scale + tick-gate               peb-v3-to-legacy → legacy keys
 inquiry_area_components                        + silent defaults                     MSPL-Get-Str/Num/Int → drawers
        │                                              │                                     │
   ONE truth (DB row)                    PEB_Data_B<n>_A<m>.txt (flat KEY=value, mm)    DXF / DWG / PDF
```

Four transforms happen in the bridge, in order, and each can change or drop a value:
1. **Field-ownership gate** — `ownedAreaView(a, structureType)` blanks any field the area's
   structure type doesn't own (`drawingData.ts:157`).
2. **Tick-gate** — `parseSelection`/`filterComponents` drop un-ticked component blocks
   (`sectionSelection.ts`; `drawingData.ts:693`).
3. **Scale + default** — `mm()/mm0()/scaleSpacing()` ×1000; blank sources get a hardcoded
   default (`drawingData.ts:31-98`).
4. **Instance cap** — only the first N of each component are read (4 walls, PT1-4, MZ1-3,
   ST1-4, CR1-3, RM×1, CW×1); extras are silently dropped.

Then the engine does its own translation (`peb-v3-to-legacy`) and applies a *second* layer
of hardcoded defaults on read. **A field can therefore be defaulted twice** — once by the
bridge, once by the engine — so a blank BSF field can still print a confident number.

---

## 1. LSP CODE INDEX (all the engine coding, organized)

Live engine dir: `D:\maimaar-os\3_Draftsman\Proposal Drawings\engine\`
(the `_checkpoints\` subfolder is a dated snapshot — not live).

### 1.1 Files & roles
| File | Lines | Role |
|---|--:|---|
| `MAIMAAR_PEB_Standard.lsp` | 423 | Primitive draw library + standards DB + the orchestrator `peb-all-sheets`. Loads first; draws nothing itself. |
| `MAIMAAR_PEB_Section.lsp` | 9139 | Cross-Section engine `C:PEB-SECTION`. Also **hosts** the v3 reader, the frame-code map, and the mezz/crane/monitor **section** drawers. Largest file. |
| `MAIMAAR_PEB_Plan.lsp` | 6484 | Column Layout Plan (MASTER) `C:PEB-PLAN`. Hosts its own v3 reader copy + every **plan-view** component drawer + `peb-draw-components` dispatch. |
| `MAIMAAR_PEB_Cover.lsp` | 219 | Cover PRO-00 `C:PEB-COVER` — border, logo, title block, LIST OF DRAWINGS. |
| `MAIMAAR_PEB_Roof.lsp` | 509 | Roof (sheeting) plan `C:PEB-ROOF` — reuses Plan grid helpers; owns roof accessories + gutters. |
| `MAIMAAR_PEB_Elevation.lsp` | 365 | Wall elevations `C:PEB-ELEVATION` (NSW/FSW/LEW/REW). |
| `MAIMAAR_PEB_Framing.lsp` | 533 | Steel-framing plan/elevations `C:PEB-FRAMING`, `-WALL-FRAMING`, `-ROOF-FRAMING`. |
| `MAIMAAR_PEB_PDF.lsp` | 128 | Plot/merge utility `C:MSPLPDF` (Node `merge_pdfs.js`). Not a drawing engine. |
| `_peb_rules.lsp` | 18 | Auto-gen `*PEB-RULES*` steel-geometry ratios (from `MAIMAAR_RULE_BOOK.dxf`). |
| `_peb_symbols.lsp` | 8 | Auto-gen `*PEB-SYMBOLS*` — the RIDGE-LINE glyph. |
| `_PEB_LAYERS_generated.lsp` | 48 | Auto-gen `*PEB-LAYERS*` layer table (from `Rule_Book/PEB_LAYERS.csv`); overrides Standard.lsp's fallback. |

### 1.2 Entry points (all `c:` commands)
- **Plan.lsp:** `C:PEB-PLAN` (3528), `C:PEB-PDF` (6023), `C:PEB-WHAT` (6085, entity inspector), `C:PEB-MEZZ-FLOOR` (6444)
- **Section.lsp:** `C:PEB-SECTION` (7223), `C:PEB-PDF` (9088)
- **Cover.lsp:** `C:PEB-COVER` (213) · **Roof.lsp:** `C:PEB-ROOF` (154) · **Elevation.lsp:** `C:PEB-ELEVATION` (332)
- **Framing.lsp:** `C:PEB-FRAMING` (471), `C:PEB-WALL-FRAMING` (505), `C:PEB-ROOF-FRAMING` (508)
- **PDF.lsp:** `C:MSPLPDF` (101), `C:MSPLPDFNEW` (121)
- **Orchestrator (function, not a command):** `peb-all-sheets` (Standard.lsp:415) → **Cover → Plan → Section only** (the strict 3-sheet proposal set; Roof/Elevation/Framing are complete engines but excluded).
- **Non-interactive entries (called by the bridge `.scr`):** `peb-cover-from-file`, `peb-plan-from-file` (5725), `peb-section-from-file` (9059), `peb-roof-from-file`, `peb-elevation-from-file`, `peb-framing-from-file`, `peb-mezz-floor-from-file`.

### 1.3 Function map by subsystem (both big files share these — **duplicated in Plan.lsp AND Section.lsp; last load wins**)
- **Data I/O:** `peb-v3-read-file`, `peb-v3-is-v3-format`, `peb-alist-get`, `MSPL-Read-Data`, `MSPL-Get-Str/Num/Int`, `peb-v3-to-legacy` (the translation layer — §2.2).
- **Parsing:** `peb-frame-display-to-code` (name→STYPE), `peb-slope-to-denom`, `peb-parse-mod-expression`, `peb-parse-frame-grid`, `peb-mg-grid`, `peb-build-sheeting-string`, `peb-panel-label`.
- **Standards/primitives (Standard.lsp):** `peb-line/poly/rect/circle/disc/arc/solid/text/mtext/insert/pent/bubble/leader`, `peb-ensure-layers`, `peb-std-setup`, `peb-tile-place`, `peb-all-sheets`.
- **Frame geometry (Section.lsp):** `compute-section-layout` (1746) + one drawer per STYPE: `draw-ms/ss/rc/mg/fr/f2/cc/acs/ams/bf/falcon2/lt/petrol-frame`, `build-frame-polygon`, `peb-ridge-x`, `peb-bf-valley-x`.
- **Plates/steel (Section.lsp):** `peb-conn-plate-pair`, `draw-knee-hplate`, `draw-ridge-plate`, `draw-base-plates`, `draw-rafter-stiffeners`, CP/GP constants `*PEB-CP-THK/GAP/EXT*` (3609-3611).
- **Cladding/purlins (Section.lsp):** `draw-cladding`, `draw-cladding-mg`, `draw-purlins`, `draw-girts`, `draw-eave-strut`, `peb-z-purlin-at`.
- **Plan grid/columns (Plan.lsp):** `draw-I-column-lengthwise/-widthwise`, `peb-draw-bracing`, `peb-draw-endwall-bracing`, `peb-draw-placements`, `peb-fall-glyph-set`, `grid-bubble`, `peb-ridge-line`.
- **Plan components (Plan.lsp):** `peb-draw-components` (2079, dispatch) → `peb-draw-canopy / -mezzanine / -stairs / -roof-ext / -fascia / -monitor / -partition / -crane`; `peb-draw-roof-accessories` (Roof-owned).
- **Title block:** `peb-build-tbdata`, `peb-titleblock-mammut`, `peb-tb-logo`.
- **Section components:** `peb-draw-mezz-section`, `peb-draw-crane-section`, `peb-draw-roof-monitor`, `peb-draw-catwalk`.

*(The complete per-line `defun` index for every file lives in the audit appendix; the map
above is the working index.)*

---

## 2. THE SYNC CONTRACT

### 2.1 Conventions (binding — see PD_GLOBAL_RULES A6-A11)
- **Units:** DB & form = metres; wire = **mm**. Bridge scales every length/spacing ×1000
  (`MM=1000`). Pass-through exceptions: stair widths, crane loads, free-text ("As per Design").
- **Slope:** ratio `rise:run` (`1:10`), never degrees.
- **Ridge offset:** mm from NSW; **blank = centred**. Butterfly/canopy valley uses
  `BP_CANT_SPAN`, not ridge offset.
- **Blank vs 0:** `0`="none"; blank="engine default" — not interchangeable.
- **Walls:** NSW=near(bottom), FSW=far(top), LEW=left-end, REW=right-end.
- **Booleans:** literal `Yes`/`No`.
- **File = identity:** `PEB_Data_B<bldg>_A<area>.txt`; one file per area; one DWG per building.
- **Parser ignores** blank lines, `;` comments, `[SECTION]` headers — only `KEY=value` matters, order-independent.

### 2.2 The v3 → legacy translation (`peb-v3-to-legacy`, Section.lsp:526 / Plan.lsp:193)
The engine does **not** read most raw IF keys directly — it rewrites them to legacy names first.
Key transforms (raw IF key → legacy key the drawers read):

| Raw IF/BSF key | → legacy | transform |
|---|---|---|
| HD_PROJECT/CUSTOMER/PROPOSAL_NO/REVISION/DATE/DRN_BY/CHK_BY/BLDG_NAME/LOCATION/IDENTICAL | PROJECT/CLIENT/PROPOSAL(+PROPOSAL_FULL)/REVNO/TBDATE/TBDRN/TBCHK/TBBLDGNAME/LOCATION/IDENTICAL | text; PROPOSAL digits-only |
| BP_LENGTH/WIDTH | LENGTH/WIDTH | mm |
| BP_ROOF_SLOPE(+_CUSTOM) | SLOPE | via `peb-slope-to-denom` |
| BP_FRAME_TYPE | STYPE | via `peb-frame-display-to-code` |
| BP_EAVE_HEIGHT | CLEARHEIGHT | mm |
| BP_GROUND_CH / BP_FIRST_CH | GROUNDCH / FIRSTCH | G+1 storeys |
| BP_BRICK_HT | BRICKHEIGHT | mm; blank⇒"0" |
| BP_WIDTH_MOD | NUMMODULES + MODULE1..n + MODEXPR | parsed `n@span` |
| BP_BAY_SPACING | NUMBAYS + BAY1..n + BAYEXPR | parsed `n@span` |
| BP_NUM_INT_COLS | NUMGABLES / SPANSPERGABLE | MG: max(2,n) |
| DL_* | WINDSPEED/EXPOSURE/COLLATERAL/LIVEROOF/LIVEFRAME/SEISMIC/SNOW/DESIGNCODE/TEMP/RAIN | EXPOSURE blank⇒"B" |
| PN_* (roof/wall) | ROOFSHEETING / WALLSHEETING | via `peb-build-sheeting-string` |
| BP_*_REF, BP_EW_*, OW_*, BP_DIM_DISPLAY | same names passed through | — |
| **wildcard passthrough** `PL* BR* RM* CR*` | copied verbatim | component blocks stay reachable |

**Frame-code map `*PEB-FRAME-CODE-MAP*`** (Section.lsp:117): "CLEAR SPAN GABLE"→CS,
"SINGLE SLOPE"→SS, "MULTI-SPAN"→MS, "LEAN-TO"→LT, "MULTI-GABLE"→MG, "FLAT ROOF"→FR,
"ROOF ON RCC COLUMNS"→RC, "FLAT ROOF G+1"→F2, "ARCHED CLEAR SPAN"→ACS,
"ARCHED MULTI-SPAN"→AMS, "BUTTERFLY"→BF, "CANTILEVER CANOPY"→CC, "PETROL PUMP"→PP.
**Valid STYPE set** (Section.lsp:7324): `CS SS MS LT MG FR F2 RC CC BF ACS AMS PP`.
F2 auto-selected when a FLAT ROOF has an active mezzanine (`f2-active-p`).

---

## 3. MASTER TRIGGER MATRIX

For each family: **IF/BSF field → PEB_Data key → bridge (write) → engine (read/draw) → sheet → status.**
Sheets: C=Cover, P=Plan, S=Section, R=Roof, E=Elevation, F=Framing. (R/E/F run on demand;
shipped set = C/P/S.) Bridge lines are `drawingData.ts`; engine lines are the `.lsp`.

### 3.1 META / HEADER
| IF/BSF field | Key | Write | Read (engine) | Sheet | Status |
|---|---|--:|---|---|---|
| building index | BUILDING_NUM | 164 | v3→BLDGNO | C/P/S | ✅ |
| area index | AREA_NUM | 165 | Plan:3961/4828, Roof:471 | P/R | ✅ |
| `customer` | HD_CUSTOMER | 169 | v3→CLIENT | C/P/S | ✅ |
| `project` | HD_PROJECT | 170 | v3→PROJECT | C/P/S | ✅ |
| `location` | HD_LOCATION | 171 | v3→LOCATION | C | ✅ |
| `proposal` | HD_PROPOSAL_NO | 172 | v3→PROPOSAL | C/P/S | ⚙️ dflt `MSPL-000-26` |
| `revision` | HD_REVISION | 173 | v3→REVNO | C/P/S | ⚙️ dflt `0` |
| date | HD_DATE | 174 | v3→TBDATE | C/P/S | ✅ |
| — | HD_DRN_BY | 175 | v3→TBDRN | C/P/S | ⚙️ blank→engine dflt `M.H` |
| — | HD_CHK_BY | 176 | v3→TBCHK | C/P/S | ⚙️ blank→engine dflt `YEA` |
| `contactPerson`/`contactNo` | HD_ATTENTION(_MOB) | 177-178 | — none — | — | ➖ not drawn |
| commercial | HD_VALIDITY / HD_DELIVERY / HD_PAYMENT / HD_CURRENCY / HD_PRICING_UNIT / HD_SALES_* | 179-186 | — none — | — | ➖ emitted, PD ignores (geometry-only) |
| count | BUILDING_COUNT | 187 | v3→BLDGCOUNT (Cover:184) | C | ✅ |
| count | AREA_COUNT | 188 | — none (engine uses AREA_NUM) — | — | ➖ unconsumed |
| `identicalCount` | HD_IDENTICAL | 189 | v3→IDENTICAL | C/P/S | ⚙️ dflt `1` |
| `buildingName` (options) | HD_BLDG_NAME | 190 | v3→TBBLDGNAME | C/P/S | ✅ conditional |

### 3.2 BUILDING GEOMETRY (BP_ / CC_)
| IF/BSF field | Key | Write | Read (engine) | Sheet | Status |
|---|---|--:|---|---|---|
| `typeOfFrame`/`canopyType` | BP_FRAME_TYPE | 200-212 | v3→STYPE (frame-code map) | P/S/R/E/F | ⚙️ dflt `Clear Span Gable` |
| `canopyType /falcon/` | CC_FALCON_PEAK | 213 | Section:1830.., Plan:573/1472/1564 | P/S | ✅ |
| `canopyType /toward/` | CC_LOW_AT_COLUMN | 214 | Section:6007.., Plan:1489/1574 | P/S | ✅ |
| `interiorColumns` | BP_NUM_INT_COLS | 215 | v3→NUMGABLES; Plan:255 | P/S | ⚙️ dflt `None` |
| `width` | BP_WIDTH | 216 | v3→WIDTH (Section wid=W−470) | P/S/R/E/F | ✅ |
| `length` | BP_LENGTH | 217 | v3→LENGTH | P/S/R/E/F | ✅ |
| `ridgeOffset` | BP_RIDGE_OFFSET | 221 | `peb-ridge-x`/`-y` Sec:1743 Plan:563 | P/S | ✅ (blank=centred) |
| `fpCantileverSpan` | BP_CANT_SPAN | 226 | `peb-bf-valley-x/y` Sec:3128 Plan:576 | P/S | ✅ |
| `bfValleyHeight` | **BP_VALLEY_HEIGHT** | 227 | **— NONE (0 refs) —** | — | ❌ **DEAD** (valley from BP_CANT_SPAN instead) |
| `height`/`eaveHeight` | BP_EAVE_HEIGHT | 228 | v3→CLEARHEIGHT; Plan:4014, Fram:291 | P/S/E/F | ✅ |
| `roofSlope` | BP_ROOF_SLOPE(+_CUSTOM) | 229-230 | v3→SLOPE | P/S/R/E/F | ⚙️ dflt `1:10` |
| `widthModule` | BP_WIDTH_MOD | 234-238 | v3→NUMMODULES/MODULEn/MODEXPR | P/S/R | ✅ scaleSpacing |
| `widthModule` (grid `|`) | BP_FRAME_GRID | 243 | `peb-parse-frame-grid` Sec:192 Plan:3722 | P/S | ✅ multi-gable |
| `widthModule` gable count | BP_GABLE_COUNT | 244 | **— NONE —** | — | ❌ unconsumed (count derived from grid) |
| `baySpacing` | BP_BAY_SPACING | 245 | v3→NUMBAYS/BAYn/BAYEXPR | P/S/R/E/F | ✅ scaleSpacing |
| `*Basis` (7 fields) | BP_*_REF | 247-252 | v3→*_REF (dim basis suffix) | P/R | ⚙️ dflt `Out to out of Steel Column` |
| `widthBasis` alias | BP_DIM_REF | 253 | **— NONE —** | — | ❌ unconsumed (alias) |
| `heightBasis` | BP_HEIGHT_REF | 254 | Plan:4017 (height tag) | P | ⚙️ dflt `Eave Height` |
| `blockWallHeight` | BP_BRICK_HT | 255 | v3→BRICKHEIGHT | S/E/F | ✅ mm |
| `rigidFrameColumns` | BP_COL_WEB_STYLE | 256 | **— NONE —** | — | ⚠️ **should drive taper, not read** — drawing always tapers |
| — | BP_DIM_DISPLAY | 257 | Plan:3645 (MM&FT vs FT) | P | ✅ (hardcoded `mm`) |
| `leftEndwallFrame` | BP_EW_LEFT_FRAME | 258 | v3→EW_LEFT_FRAME; Plan:288 | P | ⚙️ dflt `Bearing Frame` |
| `leftEndwallGirts` | BP_EW_LEFT_GIRTS | 259 | v3; Plan:4363/4481 (brace/flush) | P | ⚙️ dflt `By-Framed` |
| `leftEndwallColumns` | BP_EW_LEFT_SPACING | 260 | v3→EWLEXPR; Plan:4364 | P/S/E/F | ✅ scaleSpacing |
| `rightEndwall*` | BP_EW_RIGHT_FRAME/GIRTS/SPACING | 261-263 | v3→EW_RIGHT_*; EWREXPR | P/E/F | ✅ / ⚙️ |
| `bracingExterior` | BP_BRACING_EXT | 264 | Plan:4370 | P | ⚙️ dflt `Diagonal Rods` |
| `bracingInterior` | BP_BRACING_INT | 265 | Plan:4371 | P | ⚙️ dflt `Not Applicable` |
| `eaveType` | BP_EAVE_TYPE | 266 | **— NONE —** | — | ⚠️ gutter/trim not driven by this key |
| `gableType` | BP_GABLE_TYPE | 267 | **— NONE —** | — | ⚠️ unconsumed |
| `extBaseCondition` | BP_EXT_BASE_COND | 268 | **— NONE —** | — | ⚠️ **pinned/fixed base plate not drawn** |
| `intBaseCondition` | BP_INT_BASE_COND | 269 | **— NONE —** | — | ⚠️ unconsumed |
| `filletWeld` | BP_WELD_TYPE | 270 | **— NONE —** | — | ⚠️ unconsumed (spec text only) |

### 3.3 WALLS (OW_) & OPENINGS (PL_)
| IF/BSF field | Key | Write | Read (engine) | Sheet | Status |
|---|---|--:|---|---|---|
| `nearSideWall` etc. | OW_NSW/FSW/LEW/REW | 273-276 | Plan:3600 (`peb-wall-open-p`), Elev:129 | P/E | ⚙️ dflt `Fully Sheeted` |
| `area.placements[]` | PL_COUNT + PL{n}_* (MARK/TYPE/SURFACE/GRID_FROM/TO/OFFSET/SILL/LINTEL/WIDTH/HEIGHT/QTY/…/AT) | 628-657 | Plan:1054 (`peb-draw-placements`), Elev:234, Fram:162 | P/E/F | ✅ (doors/windows/openings) |

### 3.4 PANELS / SHEETING (PN_) — components-sourced
| IF/BSF field | Key | Write | Read (engine) | Sheet | Status |
|---|---|--:|---|---|---|
| `roof*`/`wall*` panel fields | PN_{ROOF/WALL}_TYPE/OUTER_MAT/PROFILE/FINISH/COLOR/PIR_* /INNER_* | 562-573 | `peb-panel-label` Sec:294-307; `peb-build-sheeting-string` Plan:176; `peb-roof-panel-note` Roof:141 | S/R | ⚙️ dflt `0.50 mm AZ150`/`Single Skin` |
| `roof_accessory.roofInsulation` | PN_ROOF_INSUL_THK/TYPE/DENS | 529 | `peb-panel-label` Sec:305-307 *(strcat-built)* | S | ✅ |
| `wall_accessory.wallInsulation` | PN_WALL_INSUL_THK/TYPE/DENS | 530 | `peb-panel-label` Sec:305-307 | S | ✅ |
| liner component | PN_LINER_* | 576-587 | `peb-panel-label` Sec:303 | S | ⚙️ mostly hardcoded |

### 3.5 DESIGN LOADS (DL_) → title block
| IF/BSF field | Key | Write | Read | Sheet | Status |
|---|---|--:|---|---|---|
| `liveLoad` | DL_LIVE_ROOF | 533 | v3→LIVEROOF; TB Plan:1770 | C/P/S | ⚙️ **dflt `0.57`** |
| `frameLiveLoad` | DL_LIVE_FRAME | 534 | v3→LIVEFRAME; TB Plan:1771 | C/P/S | ⚙️ **dflt `0.57`** |
| `windSpeed` | DL_WIND_SPEED | 535 | v3→WINDSPEED | C/P/S | ⚙️ engine dflt `135` |
| `exposure` | DL_EXPOSURE | 536 | v3→EXPOSURE | C/P/S | ⚙️ dflt `B` |
| `seismicZone` | DL_SEISMIC | 537 | v3→SEISMIC | C/P/S | ⚙️ dflt `2b` |
| `snowLoad` | DL_SNOW | 538 | v3→SNOW | C/P/S | ✅ (blank⇒`-`) |
| `collateralLoad` | DL_COLLATERAL | 539 | v3→COLLATERAL | C/P/S | ✅ |
| `temperatureLoad` | DL_TEMP | 540 | v3→TEMP | C/P/S | ⚙️ dflt `None` |
| `rainfallIntensity` | DL_RAINFALL | 541 | v3→RAIN | C/P/S | ⚙️ **dflt `120`** |
| `designCode` | DL_DESIGN_CODE | 543 | v3→DESIGNCODE | C/P/S | ⚙️ dflt `MBMA 2006` |

### 3.6 ROOF ACCESSORIES (RA_) & AREA POSITION (AR_)
| IF/BSF field | Key | Write | Read | Sheet | Status |
|---|---|--:|---|---|---|
| `skylights` | RA_SKYLIGHTS | 507 | Plan:3479 (`peb-draw-roof-accessories`, called by **Roof**) | R | ✅ |
| `turboVents` | RA_TURBOVENTS | 508 | Plan:3480 | R | ✅ |
| `roofOpeningArea` | RA_ROOF_OPENING | 509 | Plan:3481 | R | ✅ |
| `msHighSide` | RA_MONO_HIGH | 510 | Plan:1517, Fram:120/298 (mono fall side) | P/F | ⚙️ dflt `FSW` |
| `areaPosition` | AR_POSITION | 546 | Plan:3593/5764 (shared-wall tiling) | P | ⚙️ dflt `Standalone` |
| `areaRefArea` | AR_REF_AREA | 547 | Plan:4830/5943 | P | ✅ |
| `areaGap` | AR_GAP | 548 | Plan:4831 | P | ✅ |

### 3.7 COMPONENTS (tick-gated; each self-gates on `*_TOGGLE`)
Plan dispatch order (`peb-draw-components` Plan.lsp:2079, called at 4384):
**canopy → mezzanine → stairs → roof-ext → fascia → monitor → partition → crane**
(mezzanine before stairs so `ST_IN_MEZZ` can anchor). Roof accessories are dispatched by
the **Roof** engine, never the Plan.

| Component | Toggle | Plan drawer (line) | Section drawer (line) | Key fields consumed | Status |
|---|---|---|---|---|---|
| **Canopy** CN_ | CN_TOGGLE / CN_{w}_TOGGLE | `peb-draw-canopy` 2110 | (frame via STYPE CC) | WIDTH/LEN/GRID_FROM/TO, EAVE_HT, EAVE | ✅ (⚙️ CN_{w}_PROJ hardcoded `0`) |
| **Roof-ext** RX_ | RX_TOGGLE / RX_{w}_TOGGLE | `peb-draw-roof-ext` 2184 | ref | WIDTH/LEN/EAVE/GRID_FROM/TO | ✅ |
| **Fascia** FA_ | FA_TOGGLE / FA_{w}_TOGGLE | `peb-draw-fascia` 2248 | **`draw-fascia-vertical` / `peb-fascia-side`** (Standard Vertical, sidewalls); RC via `draw-rc-fascia` (FA_NSW_HT) | TYPE/HT/LEN/PROJ/GUTTER/SOFFIT/BACKUP/PANEL | ✅ |
| **Monitor** RM_ | RM_TOGGLE (Sec gate 7583, CS/MS/RC/MG only) | `peb-draw-monitor` 2317 | `peb-draw-roof-monitor` 6686 | THROAT/OVERALL_WIDTH/LENGTH/HEIGHT/GRID; **RM_CONSTR** | ✅ (RM_CONSTR key mismatch fixed 21-Jul, §4a) |
| **Partition** PT_ | PT_TOGGLE / PT{n}_TOGGLE | `peb-draw-partition` 2400 | ref | TYPE/LENGTH/LOCATION/OPEN | ✅ |
| **Mezzanine** MZ_ | MZ_TOGGLE / MZ{n}_TOGGLE | `peb-draw-mezzanine` 2642 (+`peb-draw-mezz-floor-plan` 6248) | `peb-draw-mezz-section` 6459 | COL_SPACING/RCC/WIDTH_ANCHOR/GRID_BAY/JOIST/FLOOR_HT/CH_* /FLOOR_THK | ⚙️ JOIST dflt `1250`, FLOOR_THK `150`, NUM_FLOORS `1` |
| **Stairs** ST_ | ST_TOGGLE / ST{n}_TOGGLE | `peb-draw-stairs` 3348 | (anchors to mezz foots) | WIDTH/HEIGHT/TYPE/LANDINGS/IN_MEZZ | ⚙️ WIDTH dflt `1200`, landings `1` |
| **Crane** CR_ | CR_TOGGLE / CR{n}_TOGGLE | `peb-draw-crane` 3023 | `peb-draw-crane-section` 6959 | SPAN/CAP/TYPE/CMAA_CLASS/GRID_LOC/RUN_LENGTH/BY_OTHERS/GRID_*_W/HOOK/BRIDGE | ⚙️ CAP dflt `10`, CMAA_CAT `3` |
| **Cat-walkway** CW_ | CW_TOGGLE | (Section) `peb-draw-catwalk` 3480 | ← same | LOCATION/SIDE/HEIGHT/WIDTH/RAIL | ⚙️ LOCATION `Inside`, SIDE `Both` |
| **Liner** LN_ | LN_TOGGLE | (via panel label) | `peb-panel-label` gate 364 | ROOF/WALL_COVERAGE/LOCATION/FLANGE_BRACES | ✅ |

**Tick-gate map** (`SEC1_SUBKEY`, sectionSelection.ts:39-55): componentType → checklist key —
liner→liner, fascia→fascia, roof_extension→roofext, canopy→canopy, partition→partition,
mezzanine→mezz, **stairs→mezz** (shares), roof_platform→platform, cat_walkway→catwalk,
roof_monitor→monitor, crane_system→crane, roof_accessory/wall_accessory→acc. Types not in
the map (bracing, *_spec) are **always** included. If the inquiry has no `sec1:` sub-keys
saved, **everything is included** (legacy contract).

---

## 4. COVERAGE LEDGER — "nothing missed to trigger"

### 4a. CONFIRMED DEAD TRIGGERS (emitted by bridge, no engine reader — verified by grep)
| Key | Bridge | Problem | Status |
|---|--:|---|---|
| **RM_CONSTRUCTION_TYPE** | 454 | Engine reads **`RM_CONSTR`** (Section:6707), a different name. Roof-monitor construction type (Hot-Rolled vs Built-up) was silently dropped → section used default member depths. | ✅ **FIXED 21-Jul** — bridge now emits `RM_CONSTR` (drawingData.ts:454), matching the reader. |
| **BP_VALLEY_HEIGHT** | 227 | 0 engine refs. Butterfly valley height is derived from `BP_CANT_SPAN` + slope instead. | ⚠️ **Reclassified to §4.2 / ④** — the estimator enters this value, so wire it into the butterfly geometry (a fidelity decision), don't silently drop it. |

### 4b. EMITTED-BUT-UNCONSUMED — review whether it *should* draw
| Key(s) | Verdict |
|---|---|
| **BP_COL_WEB_STYLE** (Tapered/Straight) | ⚠️ Drawing **always tapers**; a "Straight Web" selection is not honoured. Decide: draw straight, or drop the field. |
| **BP_EXT_BASE_COND / BP_INT_BASE_COND** (Pinned/Fixed) | ⚠️ Base-plate detail is identical regardless; pinned-vs-fixed is not reflected in the Section anchor detail. |
| **BP_EAVE_TYPE / BP_GABLE_TYPE** | ⚠️ Gutter-vs-trim eave & gable trim are not driven by these keys (eave gutter is drawn from other logic). Confirm intended. |
| BP_WELD_TYPE, BP_GABLE_COUNT, BP_DIM_REF | ➖ Spec/notes or redundant aliases; safe to leave unconsumed. |
| HD commercial block, AREA_COUNT | ➖ By design — PD is geometry-only; these ride the data bundle for parity, not the drawing. |

### 4c. READ-WITHOUT-WRITER — engine reads a key the bridge never emits (silent engine default)
| Engine key | Reader | Consequence |
|---|---|---|
| BP_GROUND_CH / BP_FIRST_CH (→GROUNDCH/FIRSTCH) | Section v3:571-572 | F2 (flat-roof G+1) storey clear-heights never emitted → engine blank/default. Wire if F2 double-storey heights must be exact. |
| MZ_OFFSET_FROM / MZ_OFFSET_TO | Plan:2712/6266 | Bridge emits MZ_GRID_BAY_FROM/TO only; mezz bay offset falls to default. Minor. |

### 4d. SILENT DEFAULTS that can print an un-entered value on a customer drawing
Leave any of these blank in the BSF and a **confident value still prints** (bridge default,
then a second engine default). The load-bearing numeric ones:
`MZ_JOIST=1250`, `MZ*_FLOOR_THK=150`, `MZ_NUM_FLOORS=1`, `ST*_WIDTH=1200`,
`CR*_CAP=10`, `CR*_CMAA_CAT=3`, `RM_HEIGHT=throat/2`,
`DL_LIVE_ROOF/FRAME=0.57`, `DL_RAINFALL=120`, `DL_WIND_SPEED=135` (engine),
`BP_ROOF_SLOPE=1:10`, `DL_SEISMIC=2b`, `DL_DESIGN_CODE=MBMA 2006`, `HD_PROPOSAL_NO=MSPL-000-26`.
**Rule:** if it must be right on paper, set it in the BSF — never rely on the default.

### 4e. DB fields captured by IF/BSF but never emitted to PD (data that never reaches a drawing)
Ownership/scope aside, these have columns but no PEB_Data key:
- **Panels/material:** roof/wallPanelThickness, roof/wallInsulation (area-level — insulation
  comes only from accessory components), roof/wallLiner(+Area), trimSize, all *Supplier,
  roof/wallIntThickness, backupPanel*, primarySteelFinish, wiremeshPosition, downpipeType, liftFloor.
- **Loads:** deadLoad, importanceFactor.
- **Geometry extras:** eaveLow/eaveHigh (mono datums), archRise, fpTilt, fflLevel, tocLevel,
  xBracingNSW/FSW/LEW/REW (per-wall X-bracing), blockWallScope, front/backEaveType.
- **Estimation take-off:** minMemberThickness, roof/wallSagRods(+Dia), cfSectionType, buFinish, cfFinish, trimsSpec.
- **Structure-type families (entirely unemitted):** existing-building ref (exLength/Width/Eave/…),
  extension (extAtWall/matchProfile/commonWall/attachWall/…), car-park/petrol
  (cpConfig/cpBays/ppColumnGrid/…), lift-shaft (shaftWidth/travelHeight/liftCapacity/…),
  standalone-stair (stFloors/stFlights/…), profileDescription/Sketch.
- **Material spec → model JSON only (not the .txt reader):** primary/secondarySteelGrade,
  boltGrade, anchorBoltGrade, weldElectrode, paintSystem, sheetingSpec, materialBuiltupGrade/Fy.
- **Notes:** areaNote, accessoriesNotes, cutoutArea, usageOfBuilding, areaLabel.

*(Most of the above are intentionally out of scope for a proposal drawing; the ones worth a
second look are the per-wall X-bracing, mono eaveLow/eaveHigh, archRise, and the base/weld
spec fields in 4b, because they change how the frame actually looks.)*

---

## 5. STANDARDS THE ENGINE DRAWS TO (self-contained reference)

### 5.1 Fonts (owner 19-Jul: **ALL TEXT = romand.shx**)
Standard.lsp declares Arial/`romans.shx`, but **Plan.lsp:3901-3904 overrides** every style
(`PEB-TITLE/BODY/DIM/ROMAND`) to `romand.shx` at plan time; `Standard` style repointed
(3907), dim style `DIMTXSTY "ROMAND"` (5556), title MTEXT wrapped `{\fromand.shx;…}` (1635).
Only the bold company name uses `arialbd.ttf`. Arrowheads = **OPEN** type.

### 5.2 `*PEB-DIM-PARAMS*` (Standard.lsp:150)
DIMTXT 600 · DIMASZ 600 · DIMEXE 100 · DIMEXO 100 · DIMGAP 10 · DIMDEC 0 (whole mm).
Text heights: SMALL 50 · DIM 56 · ANNOT 300 · HEADING 320 · LABEL 400 · TITLE 450.

### 5.3 `*PEB-CP*` connection plates (Section.lsp:3609-3611)
`*PEB-CP-THK*`=30.0 (each plate) · `*PEB-CP-GAP*`=1.5 (seam) · `*PEB-CP-EXT*`=100.0 (past flange).
Two filled-solid plates, no bolt donuts, 100 mm past both flanges (length ≥ web+200).

### 5.4 `*PEB-RULES*` steel geometry (`_peb_rules.lsp`; accessor `peb-rule`)
col_depth_div 27 · flange_width_xD 0.4 · flange_thick_xD 0.04 · web_thick_xD 0.026 ·
bolt_dia_xD 0.077 · bolt_x 0.105 · bolt_y 0.18 · endwall_depth_x_main 0.5 ·
brace_reach_xD 0.456 · brace_web_offset_xD 0.013 · rcc_square 520 · bubble_radius 620 · fall_width 600.

### 5.5 `*PEB-LAYERS*` (from `Rule_Book/PEB_LAYERS.csv` → `_PEB_LAYERS_generated.lsp`; overrides fallback)
name · ACI · linetype · lw-mm. Salient: COLUMNS 1/Cont/0.50 · GRID 150 · GRID-LINES 8/CENTER/0.09 ·
CROSS 4/DOT/0.18 · PLATES 1/0.35 · FRAME 1/0.30 · RIDGE 5/HIDDEN/0.18 · PURLINS 6/0.13 ·
GIRTS 6/0.13 · SHEETING 4/0.09 · CLADDING 5/0.18 · GUTTER 4/0.18 · DIMENSIONS 6/0.13 ·
ARROWS 3/0.13 · FALL 1/0.18 · HATCHR 32/0.30 (RCC poché) · BRICK-WALL 30/0.25.
Hatch `*PEB-HATCH*`: RCC/CONCRETE→AR-CONC/25/ACI32; MASONRY/BRICK→AR-B816/20/ACI7; EXISTING/FUTURE→ANSI31.

### 5.6 The binding rules
Full text in **`PD_GLOBAL_RULES.md`** (Part A = module/BSF contract A1-A16; Part B =
within-PD generation B1-B15). Per-sheet element ownership in **`DRAWING_CONTENT_RULES.md`**.
The one non-negotiable: **the Column Layout Plan is the master grid; every sheet derives
from the same data with the same algorithms so the sheets register.**

---

## 6. UNIVERSAL CORE — the data-interpretation layer must be shared (audit + spec)

**Rule (universal).** The data-interpretation core — the reader, the `MSPL-*` accessors, the
frame-code map, and the BSF→legacy translation (`peb-v3-to-legacy`) — is a UNIVERSAL contract:
it must behave identically for every sheet, or the plan and the section can interpret the same
BSF row differently. Today it is **copied** into both `Plan.lsp` and `Section.lsp`, and the
copies have **already drifted** — exactly the conflict single-source prevents. Target: one
shared **`_peb_core.lsp`**, loaded first, so the rule is defined once and applies to both.

### 6.1 Drift audit (21-Jul-2026, verified by function-level diff)
| Function(s) | State | Detail |
|---|---|---|
| peb-v3-read-file · peb-v3-is-v3-format · peb-alist-get · MSPL-Read-Data · MSPL-Get-Str/Num/Int · peb-digits-only · peb-strip-non-numeric · peb-split-on-char · peb-slope-to-denom | ✅ identical (10) | safe to lift as-is |
| **peb-frame-display-to-code** | ⚠️ drifted | Section is MISSING the `G+1 / double-storey → F2` clause Plan has → a verbose "Double Storey" string mis-maps on the section |
| **peb-v3-to-legacy** | ⚠️ drifted | Section lacks Plan's `(append (reverse out) v3)` full raw-key passthrough (so Section sees only `PL*/BR*/RM*/CR*` and misses `MZ_/BP_CANT_SPAN/…`); Plan lacks Section's `GROUNDCH`/`FIRSTCH` (F2 storey heights) |
| **peb-build-sheeting-string** | ⚠️ drifted (intentional) | Plan = defensive wrapper (peb-panel-label may be unloaded); Section = direct call. `peb-panel-label` + cladding helpers are Section-only and STAY in Section |
| peb-parse-mod-expression · peb-parse-frame-grid | ✅ code identical | only comments/neighbours differ |

### 6.2 The canonical (union) — additive-only
- **peb-frame-display-to-code** = Plan's (superset: keeps the G+1→F2 clause).
- **peb-v3-to-legacy** = Plan's structure incl. `(append (reverse out) v3)` full passthrough,
  **plus** Section's `GROUNDCH`/`FIRSTCH` lines after `CLEARHEIGHT`. Because it only ever ADDS
  readable keys, nothing either engine draws today can disappear — it can only restore keys
  that were being dropped.
- **peb-build-sheeting-string** = Plan's defensive version (same output as Section's direct
  call when peb-panel-label is loaded; safe when it isn't).

### 6.3 Target architecture (PLANNED — not yet executed)
```
_peb_core.lsp            ← NEW: the 15 canonical functions above + *PEB-FRAME-CODE-MAP*
MAIMAAR_PEB_Standard.lsp   (shared primitives / standards)
MAIMAAR_PEB_Section.lsp    (section drawers + peb-panel-label & cladding helpers stay here)
MAIMAAR_PEB_Plan.lsp       (plan drawers)
```
Load wiring: prepend `(load ".../_peb_core.lsp")` **before** Standard in every loader —
`drawingData.ts:801-803` (per-area scr) & `826-833` (per-building), `drawingRender.ts:88-93`
(reuse scr) & `279-283` (pdf scr) — then delete the 15 functions from Plan.lsp and Section.lsp.

### 6.4 Execution gate (why this is a spec, not yet done)
The canonical `peb-v3-to-legacy` makes Section read keys it currently drops (e.g. mezzanine
`MZ_*`), so it can change what a section draws for real jobs. It **must be headless-render-
verified on representative samples (mezzanine, crane, butterfly, multi-gable) before commit.**
Rendering is deliberately out of scope for this documentation pass — this section is the spec
to execute against when the owner schedules the refactor.

### 6.5 Other maintainer facts
- Until 6.3 lands, the copied core is **live-drifted**: any edit to one copy MUST be mirrored
  in the other (last-loaded wins otherwise).
- Standard.lsp's fallback layer table + Arial/`romans.shx` literals are **superseded at runtime**
  (layers by the CSV, fonts by the romand override) — not the source of truth.
- Roof / Elevation / Framing are complete, runnable engines but **excluded from `peb-all-sheets`**
  (shipped set = Cover/Plan/Section) — wire them in only on an owner call.
