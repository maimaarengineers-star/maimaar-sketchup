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

## Coverage note
Representative deep study (multi-span + crane/mezzanine + RCC multi-area) captured the full convention set. A bulk DWG→DXF conversion of ~50 sets (ODA File Converter / `acad DXFOUT` batch) can be run to extract exact geometry for any detail not visible in the rendered PDFs; the conventions above are sufficient to implement P2–P5.
