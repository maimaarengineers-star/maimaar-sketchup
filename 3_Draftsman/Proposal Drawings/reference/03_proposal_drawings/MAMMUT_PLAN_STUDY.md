# Mammut Column-Layout PLAN — study findings (for the Maimaar PD engine)

Studied representative Mammut proposal-drawing plans from the MBS archive
(`D:\Misc\Miscellaneous\Personnel\MBS Data\A_Pakistan\{Proposals,Jobs}`), biased to
multi-area / multi-span / accessory-rich jobs. Deep-read: **Roshan Packages** (MS3 multi-span,
RCC area) and **Raaziq Industrial** (crane + mezzanine). These validate the approved plan
(`layout-of-multi-areas-in-adaptive-bird.md`) and pin the exact conventions to mirror.

## Confirmed conventions (mirror these)

1. **Sheet = "COLUMN LAY-OUT PLAN"** (+ "(OPTION NO. N)" when multiple options), title centred on the left; Mammut vertical title strip on the right (General Notes + "THIS DOCUMENT IS PROPOSAL DRAWING… NOT FOR CONSTRUCTION" + design-load table) — we already match the strip.

2. **Overall dims carry the BASIS text verbatim** (this is the core of our R3):
   - "BUILDING LENGTH : 85340 **CENTER TO CENTER OF STEEL COLUMNS**"
   - "BUILDING WIDTH : 32004 **O/O OF STEEL**" (out-to-out of steel)
   - "BUILDING LENGTH; 72491 **C/C OF RCC COLUMN**" (a different area/part can use a different basis)
   → Map each IF basis → its label text. Different areas may carry different basis.

3. **Spacing chains = the exact grouping** (our R4):
   - Equal runs → "10 @ 8534", "9 @ 7112".
   - Unequal bays → shown **individually** (6001, 6001, 8085, 8085, … 7620, 5182, 2438).
   - Module groups also show **sub-totals** (e.g. 4572+6096×4+3048 with 13868 / 18136 subtotals).
   → Print the IF grouped expression verbatim (count@spacing where equal, individual where not); add the overall = sum. mm units.

4. **Grid bubbles** = hexagonal, numbered (1,2,3…) along length, lettered (A,B,C…) across width, **including half-grids** A'/B'/1'/3' at corner/end-bay framing (these come from the endwall-column / end-bay split).

5. **Multi-area in one plan**: distinct areas drawn together — e.g. steel AREA-01 + a hatched "AREA # 2" RCC structure along one edge, each **dimensioned separately** with its own basis, sharing the boundary. AREA tag boxed ("AREA-01", "AREA # 2"). → our P5.

6. **Bracing**: "BRACED BAY" text + "CROSS BRACING" label + X-bracing drawn only in the chosen bays. (Drives our door-vs-braced-bay clash, P4.)

7. **Roof/slope annotations on the plan**: FALL arrows + slope "ONE:15"/"ONE:20", "RIDGE LINE", "C/L OF RAFTER", "VALLEY GUTTER / DOWN SPOUT", "WALK WAY", "MAIN FRAME BOTH ENDS".

## Accessories shown ON the plan (richer than our current engine)
- **Mezzanine**: hatched "MEZZANINE FLOOR" region + mezz beams + interior mezz columns (⊕) + **staircase** (treads, HANDRAIL, STRINGER) with its own small dims.
- **Crane**: crane-beam line along the bay + "CRANE RUN LENGTH : 53.227M" + capacity ("CRANE 5MT") + "DSD 3.0M x 3.0M".
- **Cut-out**: a "CUT OUT" region marked with diagonal X.
- **Doors/windows**: located by **offset from the nearest grid** (drives the no-cross-bracing rule, P4).

## Implications for our build (deltas vs current Maimaar plan)
- **Already match**: grid bubbles, columns, cross-bracing X + BRACED BAY, FALL arrows, RIDGE, NSW/FSW labels, overall dims, title strip.
- **Build (approved plan)**: P2 basis-driven labels (map IF basis → "C/C OF STEEL COLUMNS"/"O/O OF STEEL"/…); P3 exact grouped chains (incl. unequal-individual + subtotals); P4 endwall posts from IF + half-grids + doors/windows offsets + braced-bay clash; P5 multi-area (hatched secondary areas, per-area basis, shared boundary, AREA-0N tags, web/2+200 gap).
- **Future (beyond this plan)**: in-plan mezzanine (hatch + stairs), crane beam + run-length + capacity, cut-outs, walkway, valley gutter — capture as a later accessory-detailing phase (data already exists: MZ_*, CR_*, ST_*, RX_*/CN_*).

## Multi-area / multi-building catalogue (31 distinct proposal sets scanned)
Rendered the column-layout-plan page of 31 distinct proposal-drawing sets (2010-2014) into
contact sheets + deep-read the richest. NOTE: the archive mixes **Mammut** and **Izhar Steel**
(a competitor) proposals — both are valid PEB references; the conventions agree.

**How multiple areas are represented (the key for P5):**
1. **Each area = its own grid + columns + AREA-0N tag**, tiled to form the combined footprint;
   each area dimensioned with its own bay/width chains + basis (areas may differ in basis).
2. **Hatch convention for non-new-steel zones** — RCC, EXISTING, FUTURE areas are drawn with a
   concrete/diagonal **HATCH + label**, visually distinct from the clear new-steel area:
   - "RCC STRUCTURE" (Raaziq, #15, Al-Nafia) — concrete area adjacent to steel.
   - "EXISTING RCC BUILDING" / "EXISTING STEEL BUILDING" (Unilever, #24, #26, US Denim) — tie-in.
   - "FUTURE EXTENSION" / "FUTURE BUILDING" (Zealcon-4228, Roshan, Kainat) — provision zone, hatched.
3. **Two-area side-by-side** with shared boundary + the column-centreline gap: Zealcon-092
   (AREA-01 + AREA-02 + a Roof Plan on the same sheet), Kainat (AREA #1 + AREA #2).
4. **Multi-BUILDING on one sheet**: Werrick ("BUILDING 1" + "NEW BUILDING" + "BUILDING 2").
5. **L-shaped / non-rectangular** combined footprint (#28) — areas at different x/y offsets.
6. **Mezzanine** present → a separate "MEZZANINE FLOOR PLAN" beside the column plan (ZRK, Raaziq).
7. **Crane** buildings: crane-beam line + "CRANE RUN LENGTH" + capacity + cage-ladders (#26, Zealcon-4228, Raaziq).
8. Long buildings (Big-Bird, 21 bays) carry **roof monitors/ventilators** along the ridge (→ roof plan / P6).

**Direct consequences for our build:**
- P5 must support: per-area grid+tag+dims at tiled offsets; a **HATCH style for RCC/EXISTING/FUTURE
  areas** with a type label (drive from the IF area "structure type" / position); the web/2+200
  inter-area gap; shared-boundary dual labels; and tolerate L-shaped (non-collinear) tilings.
- Roof plan (P6) references: #19, #22, #23, #25 (purlins, fall arrows, ridge, skylights, sheeting).
- Later accessory phase: mezzanine floor plan, crane beam + run length, cage ladders.

## Coverage note
Representative deep study (multi-span + crane/mezzanine + RCC multi-area) captured the full convention set. A bulk DWG→DXF conversion of ~50 sets (ODA File Converter / `acad DXFOUT` batch) can be run to extract exact geometry for any detail not visible in the rendered PDFs; the conventions above are sufficient to implement P2–P5.
