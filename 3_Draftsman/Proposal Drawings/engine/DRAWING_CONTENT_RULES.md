# DRAWING CONTENT RULES — what belongs on each PEB Proposal Drawing

**Purpose.** One canonical spec for the AutoLISP drawing engines: for every proposal
drawing type, exactly WHICH elements belong on it and which do NOT. This prevents the
same feature being drawn on two sheets (duplication) or falling through the cracks.

**Status.** Research synthesis, 6-Jul-2026. Grounded in three reference bodies:
- `reference/Folder_C/00_STRUCTURE_CATALOGUE.md` + the per-type `_SPEC.txt` (Mammut manual distilled).
- `reference/Folder_B/*` real CRM archive proposal drawings (read directly from the PDFs).
- `reference/03_proposal_drawings/DXF/*` — 11 curated Mammut/Maimaar reference DXFs (layers + TEXT inspected with ezdxf).
- Cross-checked against the current engines (`MAIMAAR_PEB_Plan/Section/Roof/Elevation/Framing/Cover.lsp`).

Do NOT treat this as engine code. It is the acceptance spec the engines are measured against.

---

## 0. The master rule: the Column Layout Plan is the origin of the grid

Every sheet in the set shares ONE grid: **number lines (1,2,3…) run along the LENGTH**
(bays) and **letter lines (A,B,C…) run across the WIDTH** (frame). The **Column Layout
Plan is the MASTER** — it fixes the grid stations, the column positions and the overall
dimensions. Every other sheet (Roof Plan, Elevations, Framing, Section) *derives its
geometry from the same data file with the same algorithms*, so the grid numbers/letters
land in identical positions and the drawings register with each other. If a grid bubble
moves on the Column Layout Plan it must move everywhere.

Axes convention (shared, from `MAIMAAR_PEB_Roof.lsp` header):
`NSW = bottom (y=0) · FSW = top (y=wid) · LEW = left (x=0) · REW = right (x=len)`.

**The standard Maimaar proposal set** (confirmed from `Folder_B/Cold-Storage/MSPL-24-002`,
a clear-span shed — its own `LIST OF DRAWINGS`):
`PRO-00 List of Drawings (Cover) · PRO-01 Column Layout Plan · PRO-02/03 Cross Section(s)
· PRO-04 Roof Sheeting Plan · PRO-05 End Wall Elevation · PRO-06 Side Wall Elevation`.
Mammut's equivalent 8-sheet set (`MAMMUT_08_PearlKhas` poultry): Cover · Roof Plan ·
Elevation (NSW/FSW) · Side Wall Elevation · Cross-Section · per-grid cross-sections ·
Anchor-Bolt Setting Plan. See OPEN QUESTIONS on set membership.

---

## 1. COVER  (PRO-00)  —  `MAIMAAR_PEB_Cover.lsp`

**PURPOSE:** Title/index page — identifies the project and lists the sheets; no geometry.

**BELONGS ON IT**
- Triple border + Maimaar logo + company/contact block (Standard).
- Boxed **"PROPOSAL DRAWING"** banner + **"PROPOSAL / QUOTE NO."** (IF `PROPOSAL`).
- Title-block fields, all from the IF: Customer (`CLIENT`), Building Name (`BLDGNAME`),
  Project Title (`PROJECT`), Bldg No (`BLDGNO`), Rev (`REVNO`), Date, Prepared/Checked.
- **LIST OF DRAWINGS** table (DRG# · Drawing No · Title · Date · Rev) — the index that
  every real set carries as PRO-00 (see both PDFs read).
- The four standard note boxes that ride the title strip on every sheet: **General Notes,
  Building Accessories, Building Design Loads, Building Design Codes** (loads from
  `WINDSPEED/LIVELOAD/SNOW/COLLATERAL/SOLAR/EXPOSURE/STEELGRADE`; accessories = the
  cladding spec + counts).

**DOES NOT belong:** any plan/section geometry, grid, dimensions of the building.

---

## 2. COLUMN LAYOUT PLAN  (PRO-01)  —  `MAIMAAR_PEB_Plan.lsp`  (MASTER)

**PURPOSE:** Top view fixing the grid, every column position and the setting-out dimensions.

**BELONGS ON IT**
- **Grid** — number lines along length, letter lines across width; **grid bubbles** on the
  top and left; extra half-lines (A′, E′, 1′…) for endwall/canopy offsets (seen in every DXF).
- **Columns** drawn as true I-section marks in plan (`draw-I-column-lengthwise/-widthwise`):
  sidewall/bay rows, endwall posts, and any interior column line (Multi-Span, separate
  crane columns, Multi-Gable valley line). Column topology is the plan discriminator
  (Catalogue §"PLAN DISCRIMINATORS").
- **Ridge line** (label `RIDGE LINE`) for gable types; **valley line(s)** for Multi-Gable;
  **RAFTER** direction indicator. (Cold-Storage PRO-01 shows RIDGE LINE + RAFTER labels.)
- **FALL / slope glyphs** — a MINIMAL set (owner: max 2–3, snapped to unbraced bays so
  the `BRACED BAY` text never overlaps) showing the roof-fall direction + slope ratio
  (`peb-fall-marker`, owner 4-Jul). DELIBERATE EXCEPTION (owner 7-Jul): fall direction is
  also useful on the layout plan, so it is shown on BOTH the CLP (this minimal set) and the
  Roof Plan (the full owner set). The two are intentionally kept in sync, not a duplication bug.
- **Bracing marks** — braced-bay X's + notes (`WALL BRACING / ROOF BRACING / PORTAL
  BRACING` appear as plan text in `MAIMAAR_06_Warehouse`). Rule = brace 2nd & 2nd-last bay.
- **Dimensions**: bay chain, width chain, and the two overall notes
  `LENGTH : … O/O OF STEEL LINE` and `WIDTH : … O/O OF STEEL LINE`.
- **Base/column marks** (crosshair + base plate footprint) at each column.
- **STRUCTURAL components that have columns / a footprint on the plan**:
  - **Mezzanine** — decking outline + its OWN stub-column grid + main-beam lines + joist
    lines + staircase location (`peb-draw-mezzanine`, `peb-draw-stairs`).
  - **Crane** — runway beams (two length lines inboard of sidewall cols) + bridge across
    width + hook + capacity/type label; separate crane-column row if >20 t or span >15 m
    (`peb-draw-crane`).
  - **Partition** — interior partition line + framed opening (`peb-draw-partition`).
  - **Canopy / Lean-to footprint** — projecting strip beyond the wall (`peb-draw-canopy`);
    lean-to also gets its outer column line. (Cold-Storage PRO-01 marks `CONOPY`.)
  - **Roof-extension footprint** (`peb-draw-roof-ext`), **Fascia/parapet band**
    (`peb-draw-fascia`), **Roof-monitor strip on the ridge** (`peb-draw-monitor`).
- **Wall openings** marked as footprint/swing at their grid station (`DOOR 2434 X 2438`
  on Cold-Storage PRO-01) — location only; the full clad opening lives on the Elevation.

**DOES NOT belong (explicit)**
- **Roof ACCESSORIES — skylights, turbo/ridge vents, roof openings.**  KEY OWNER RULE
  (6-Jul): these go **ONLY on the Roof Plan**, not here. The code enforces it —
  `MAIMAAR_PEB_Plan.lsp:1561` note: *"roof ACCESSORIES belong on the ROOF PLAN, NOT the
  Column Layout Plan; peb-draw-roof-accessories is called by the Roof engine, not here."*
- Purlins, girts, sheeting run-lines, gutters/downspouts (all belong to Roof
  / Elevation / Section).  *(Fall/slope glyphs ARE shown here too — a deliberate owner
  exception, 7-Jul; see the "BELONGS ON IT" list above.)*
- Sheeting + insulation build-up spec (belongs to the Section; a short cladding note may
  ride the accessories box only).

---

## 3. ROOF PLAN  (a.k.a. ROOF SHEETING PLAN, PRO-04)  —  `MAIMAAR_PEB_Roof.lsp`

**PURPOSE:** Top view of the roof — how it drains and is clad, on the master grid.

**BELONGS ON IT**
- **Roof outline + eaves**, and the **SAME grid + grid bubbles** as the Column Layout Plan
  (so the two register) — but **grid bubbles only, NO column marks** (confirmed:
  Cold-Storage PRO-04 "Roof Sheeting Plan" shows grid bubbles and sheeting, no columns).
- **Ridge line(s)** (gable) and **Valley line(s)** (Multi-Gable / Butterfly).
- **Fall / slope arrows** with the slope ratio (`SLOPE 1:07` in four quadrants on
  Cold-Storage PRO-04; `FALL` on Mammut Roof Plan) — direction per structure type
  (ridge→eave gable; one-way mono-slope; ridge→valley→ridge Multi-Gable; inward-to-centre
  flat roof). `peb-roof-falls`.
- **Purlin lines** running parallel to the ridge (the sheeting-run lines double as this).
- **Eave gutters + downspouts** — gutter lines just outside the eave walls + downspout
  squares at bay stations; full perimeter for flat/butterfly (`peb-roof-gutters`).
- **ROOF ACCESSORIES** — skylights (even grid), turbo/ridge vents (circles along ridge),
  roof openings, with the true count in the label (`peb-draw-roof-accessories`). **Owned here.**
- **Roof-plane coverage of roof-extensions (RX_*) and canopies (CN_*)** — their roof
  footprint (`peb-draw-roof-ext`, `peb-draw-canopy` reused).
- **Roof-monitor opening** band (`ROOF MONITOR OPENING` text in `MAIMAAR_06_Warehouse`).
- **Panel / sheeting note** (`ROOF CLADDING PIR 50mm SANDWICH PANEL` corner note) +
  own grid dimensions.

**DOES NOT belong (explicit)**
- Column marks, base plates, bracing X's (those are Column-Layout / Framing).
- The full frame profile or heights (Section).
- Wall openings, girts (Elevations).

---

## 4. WALL ELEVATIONS — NSW / FSW / LEW / REW  (PRO-05 End, PRO-06 Side)  —  `MAIMAAR_PEB_Elevation.lsp`

**PURPOSE:** The finished outside face of each wall — cladding + openings + condition.

**BELONGS ON IT**
- Ground line + **brick base** (`BP_BRICK_HT`, `BRICK WALL (BY OTHERS)`).
- **Columns** as vertical lines at their grid stations (bay cols on side walls; endwall
  posts rising to the gable/slope underside on end walls).
- **Girts** — horizontal lines at ~1800 spacing.
- **Roof-line profile at the top**: flat eave (side walls); gable peak (CS/MS/RC),
  mono-slope (SS/LT/CC), butterfly valley (BF) or Multi-Gable sawtooth (MG) on end walls,
  with the **slope ratio** tag (`1:07`).
- **Wall sheeting** — light cladding panel run-lines over the face + the **wall condition
  note** (`OW_<wall>`, e.g. `SIDE WALL CLADDING PIR 50mm SANDWICH PANEL`). This is the
  sheet that OWNS the drawn cladding of the wall.
- **Wall openings** — doors/windows drawn to size on the face at their placement
  (`PL_*`); this is the OWNER of openings (Cold-Storage PRO-05 shows the `S.D 2438x2438`
  door + windows as squares on PRO-06). Canopy/fascia that attach to this face show here too.
- **Wall X-bracing** in the braced bays/panels (`peb-braced-bays`).
- **Grid bubbles** along the bottom + `<WALL> ELEVATION @ GRID …` title + height/bay dims.

**DOES NOT belong (explicit)**
- Roof accessories, fall arrows, gutters (Roof Plan).
- Base plates / anchor detail (Framing / Section).
- The internal frame members or the sheeting build-up spec (Section).
- Purlins / ridge line as objects (the apex is only implied by the profile).

---

## 5. FRAMING ELEVATIONS  (Steel Framing — side + end)  —  `MAIMAAR_PEB_Framing.lsp`

**PURPOSE:** The BARE structural skeleton of each wall/roof — steel only, no cladding.
The long-wall / end-wall companion to the cross-section. `C:PEB-FRAMING` +
`C:PEB-ROOF-FRAMING`.

**BELONGS ON IT**
- **Base plates** at every column (owner of the base-plate mark on a wall view).
- **I-columns** (true web depth) at grid stations.
- **Eave strut / rafter profile** across the top per STYPE (gable / mono / flat / butterfly).
- **Girts** (wall) and, on the roof-framing variant, **rafters + purlins + ridge**.
- **Bracing** — wall X-bracing (and roof X-bracing on the roof-framing sheet).
- **Fall arrows + slope ratio** on the roof-framing sheet (`peb-fr-fall`).
- **Roof accessories as framed openings** (skylight/vent/monitor band) on roof-framing.
- Grid bubbles + eave & bay dimensions.

**DOES NOT belong (explicit)**
- **NO sheeting, NO cladding, NO wall condition note** — this is the discriminator from
  the Wall Elevation (engine header: *"Distinct from the Wall Elevation which carries
  sheeting/openings"*).
- No doors/windows as clad openings (only their framed jambs, if any).
- No sheeting/insulation spec label.

---

## 6. CROSS-SECTION(S)  (PRO-02/03)  —  `MAIMAAR_PEB_Section.lsp`

**PURPOSE:** The rigid-frame profile cut across the width — members, connections, the full
cladding build-up and the controlling heights. One section per distinct frame (typical +
endwall + at-grid where the frame changes; real sets carry 2–4, e.g. `@ GRID 01 TO 03`
and `@ GRID 04 & 05`).

**BELONGS ON IT**
- **Cross-frame profile** — columns + rafters at the true slope, tapered where designed.
- **Haunch / ridge / base connection plates** (bolted knee + apex plates, base plate on
  the anchor).
- **Purlins + girts** shown in section (the small member marks along rafter/column).
- **Full SHEETING & INSULATION build-up labels** — the OWNER of the spec:
  `peb-panel-label` composes the ROOF and WALL sandwich, e.g.
  `0.50mm AZ 150 + 50 PIR Core Density 38kg/m3 + 0.50mm AZ 150`
  (Mammut sections label `ROOF SANDWICH PANEL / WALL SANDWICH PANEL / SKIN PANEL`).
- **Brick wall (by others)** base, `CLEAR HEIGHT` and eave/ridge **heights**, width dim
  (`… O/O OF STEEL LINE`), grid refs at the frame lines.
- **Mezzanine / crane shown in section** — mezzanine deck+beam+joist build-up (100mm
  concrete by others + 0.7mm decking + joist + main beam + chemical anchoring, per
  `MSPL-26-122` PRO-03); crane runway beam + bracket/stepped/separate-column support.
- **Fascia / parapet / monitor** in cross where present.

**DOES NOT belong (explicit)**
- The plan grid layout, bay dimensions along the length (Column Layout Plan).
- Fall arrows / gutters as plan symbols (Roof Plan) — a gutter may appear as a cross
  detail (ref) but drainage direction is the Roof Plan's job.
- Wall openings across the length (Elevation).

---

## 7. SUMMARY MATRIX — which sheet owns which element

Legend: **✓** = drawn (owned here) · **ref** = referenced/implied only, not the owner ·
**–** = must NOT appear. "Framing" = Framing Elevation (bare steel + roof-framing variant).

| Element | Cover | Column Layout Plan | Roof Plan | Wall Elevations | Framing Elev. | Cross-Section |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Grid lines | – | ✓ (master) | ✓ | ✓ | ✓ | ref |
| Grid bubbles | – | ✓ | ✓ | ✓ | ✓ | ref |
| Columns (I-marks) | – | ✓ | – | ✓ | ✓ | ✓ (frame) |
| Ridge line | – | ✓ | ✓ | ref (apex) | ✓ (roof-fr) | ✓ (apex) |
| Valley line (MG/BF) | – | ✓ | ✓ | ref | ✓ (roof-fr) | ref |
| Purlins | – | – | ✓ | – | ✓ (roof-fr) | ✓ (marks) |
| Girts | – | – | – | ✓ | ✓ | ✓ (marks) |
| Fall / slope arrows | – | ✓ (min set, owner 7-Jul) | ✓ (owner, full set) | ref (slope tag) | ✓ (roof-fr) | ref (rafter slope) |
| Gutters / downspouts | – | – | ✓ (owner) | ref | – | ref (detail) |
| Sheeting run-lines (cladding) | – | – | ✓ (roof) | ✓ (wall) | – | – |
| Sheeting + insulation SPEC label | ref (accessory box) | – | ref (corner note) | ref (condition note) | – | ✓ (owner, full build-up) |
| Wall openings (doors/windows) | – | ✓ (footprint) | – | ✓ (owner, clad) | ref (framed jamb) | ref |
| Bracing (X marks) | – | ✓ (owner) | – | ✓ (wall) | ✓ (wall+roof) | – |
| Base plates | – | ref (base mark) | – | – | ✓ | ✓ (w/ anchor) |
| Mezzanine | – | ✓ (stub grid+beams) | – | ref | ref | ✓ (section) |
| Crane | – | ✓ (runway+bridge) | – | ref | ref | ✓ (section) |
| Canopy / Lean-to | – | ✓ (footprint) | ✓ (roof cover) | ✓ (on face) | ref | ✓ (section) |
| Roof extension | – | ✓ (footprint) | ✓ (roof cover) | ref | ref | ref |
| Roof monitor | – | ✓ (ridge strip) | ✓ (opening band) | ref (raised gable) | ✓ (roof-fr) | ✓ (section) |
| Fascia / parapet | – | ✓ (band) | ref | ✓ (on face) | ref | ✓ (section) |
| Partition | – | ✓ (line+opening) | – | ref | ref | ✓ (section) |
| Stairs | – | ✓ (footprint) | – | ref | – | ref |
| Skylights / turbo-vents / roof openings | – | **–** (moved off, 6-Jul) | **✓ (OWNER)** | – | ref (roof-fr opening) | ref (build-up) |
| Dimensions | – | ✓ (bay/width/overall) | ✓ (grid) | ✓ (bay/height) | ✓ (bay/eave) | ✓ (width/heights) |
| Title block + note boxes | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| List of Drawings | ✓ (owner) | – | – | – | – | – |

**One-line ownership call for the ~20 key elements:**
Grid & columns & bracing & structural footprints (mezz/crane/partition/stairs/canopy/
roof-ext/fascia/monitor) → **Column Layout Plan**. Ridge/valley + fall arrows + gutters/
downspouts + purlins + **skylights/vents/roof-openings** + roof-plane coverage →
**Roof Plan**. Wall cladding + wall openings + girts + wall condition → **Wall Elevations**.
Bare steel + base plates → **Framing Elevation**. Frame profile + haunch/ridge plates +
**full sheeting/insulation spec** + heights + mezz/crane-in-section → **Cross-Section**.
Title/index → **Cover**.

---

## 8. OPEN QUESTIONS for the owner

1. **Roof Plan scope — lean "Roof Sheeting Plan" vs rich "Roof Plan".** The real Maimaar
   clear-span set (`Cold-Storage/MSPL-24-002` PRO-04) draws only **sheeting-run lines +
   slope arrows + grid** — no purlins, gutters, downspouts or accessories. The current
   `MAIMAAR_PEB_Roof.lsp` (and the 6-Jul accessories rule) produce the **richer** Mammut-
   style Roof Plan (purlins + gutters + downspouts + skylights/vents). Confirm the target:
   full detail, or the lean sheeting plan? (This spec assumes the richer version, since the
   6-Jul rule deliberately homed accessories there.)

2. **Which sheets are in the STANDARD set vs on-demand.** Memory *"Strict drawing set"*
   says the proposal set = EXACTLY **Cover + Column Layout Plan + Section** (no framing /
   elevations). But real archive sets (Cold-Storage) ship Cover + CLP + Section(s) + Roof
   Sheeting Plan + End Wall Elevation + Side Wall Elevation. Confirm the canonical set,
   and whether **Framing Elevations** are proposal-stage at all or approval/fabrication-only
   (no archive proposal PDF sampled contained a bare-steel Framing Elevation).

3. **Anchor-Bolt Setting Plan.** Mammut sets include a dedicated `ANCHOR BOLT SETTING PLAN`
   sheet (+ bolt schedule); the Maimaar cold-storage set omits it (foundation goes to
   separate Civil/Foundation drawings). Is ABP part of the proposal set, or does the base-
   plate/anchor detail live only on the Section? (Affects where the anchor-bolt schedule
   `peb-draw-ab-schedule` is placed.)

4. **Gutter ownership Section vs Roof.** Gutter drainage (direction, downspout count) is
   the Roof Plan's; a gutter cross-detail can also appear on the Section. Confirm the
   Section shows the eave-gutter cut (ref) and does not repeat downspout counts.

5. **Ridge vent vs turbo-vent placement.** Ridge ventilators sit on the ridge and read on
   both the Roof Plan (plan symbol, owner) and the Section/End-Wall (cross profile, ref).
   Confirm ridge vents follow the same "Roof Plan owns the count" rule as skylights/turbo-vents.

6. **Standalone component jobs = own mini-set.** A standalone Mezzanine job
   (`MSPL-26-122`) is drawn as its OWN set — *Main Beam & Joist Plan · Floor Layout Plan ·
   Typical Cross Section* — NOT as an overlay on a shell's Column Layout Plan. Confirm the
   engine should emit that dedicated 3-sheet layout when the job is component-only (mezz /
   platform / canopy / crane standalone) rather than adding footprints to a building CLP.
