# SLIDING DOOR

A sliding door is a **leaf hung from a track**, not a hole in a wall. Everything that makes it
read as one on a drawing — the track running well past the opening, the stile-and-rail grid, the
diagonal brace, the wall it needs to park in — is what the old placement loop threw away when it
drew every accessory as a `RECTANG` with two diagonals.

```
peb-sld-elevation   the whole door on a wall elevation
peb-sld-plan        the plan symbol
peb-sld-leaf        one leaf, reusable
peb-sld-track       the U-channel track and its wheels
peb-sld-opening     the framed opening — jamb, header
peb-sld-ghost       the leaf in its PARKED position
peb-sld-context     the sheeting and girts around it (development only)
peb-sld-sample      the standard-size sample — `SLDSAMPLE` inside AutoCAD
```

Everything takes **origin, size and hand as arguments**. Nothing here reads the BSF (golden
rule 2 / 24): `geometryRules.js` computes, the BSF stores, this draws what it is handed.

---

## Two doors, one drawer

| | SSD — single sliding door | DSD — double / bi-parting |
|---|---|---|
| leaves | 1 | 2 |
| leaf width | opening + 2 × 75 cover | opening / 2 + 75 cover |
| parks into | one pocket, one side | one pocket each side |
| wall needed | opening + 1 leaf + 100 | opening + 2 leaves + 200 |
| real example | MSPL-027 SSD-01 — 4500 opening | MSPL-030 SDS-01 — 7972 track |

`peb-sld-elevation` takes `leaves` = 1 or 2 and `hand` = ±1. One drawer, both doors — the same
rule as one panel being a wall light or a sky light depending on the surface (golden rule 1).

---

## The numbers, and where each one came from

### From two real Maimaar jobs

| | MSPL-027 SSD-01 · 05-Nov-2021 | MSPL-030 SDS-01 · 01-Apr-2022 |
|---|---|---|
| job | Awan Sports, Bhan Stitching Hall No. 02 | Awan Sports, Initial Paddle Sanding Hall |
| type | SINGLE leaf | DOUBLE leaf |
| leaf | 4500 × 2206 | 3936 / 3937 |
| track | 7972 (8382 over trims) | |
| stile grid | 125 / 298 / 540 / 551 / 540 / 291 / 640 / 644 / 640 / 230 | **125 / 890 / 990 typical** |
| infill | Sandwich panel 2200 × 1155 | Sandwich panel, 1448 wide, 302 edges |
| perimeter | `DOOR_ANGLE` DA-3 = **L50 × 5** × 4500 | `DOOR_ANGLE` |
| diagonal | `DOOR_ROUND_BAR` DRB-1 = **Ø12** × 4500 | `ROUND_BAR` |
| track section | `U-CHANNEL` UC-1 = **PL 3 × 214** × 4500 | `OPENING_CHANNEL` + `DOOR_WHEEL` |
| clips | `U-CLIP` PL3 × 100 · `NEW_ANGLE` L50×5 ×77 (18 no.) · `NEW_PLATE` FLT5×50 ×105 (9 no.) | `L-CLIP` |
| head | | `DOOR_HEADER` + `HOOD_TRIM` + canopy flashing over the wheel |
| sill | | floor guide **200 below FFL**, **12 clear** under the leaf |
| parking | slide-back **1154**, total run 5991 over a 4500 opening | leaf overrun past the jamb **410** |

Both jobs are in `reference/` as issued — erection drawings, shop drawings with their material
lists, the designer's 3D sketch, and site photographs of the finished door.

### From the reference PEB technical manual (`reference/RefManual_*.pdf`)

| page | what it settles |
|---|---|
| **750** | *"120 mm deep sections are used as framing members of sliding doors."* Framed-opening jambs and headers are C-sections, single or double back-to-back — 200C15 up to 3000 long, 250C when the girt is 250 deep. Connection bolts **12 mm dia HSB Gr. 8.8**. |
| **754** | Jamb tributary width for a **sliding door** (or open access) = **0.5 m**. For a roll-up door it is (framed opening / 2 + 0.5). A sliding leaf carries its own wind load to its own track — which is *why* a sliding door's jamb is so much lighter than a roll-up's. |
| **755** | The worked DSD: framed opening **6000 × 6000**, *"designing the door leaf members of size 3 × 6"*. Inner stile span 1.50 m, width 1.50 m. |
| **756** | Inner stile → **120C20**. |
| **757** | Central stile span 6.00 m, width 1.50 m → **2 × 120C20**; edge stile designed for half the central stile load. |
| **758** | Bottom stile span 3.00 m, width 0.75 m. |
| **755** | For the 6000 roll-up jamb, *"capacities are much below required, even for double 'C' section, hence hot-rolled or built-up section may be used"*. |

Read together, pages 755–758 describe **a 1500 × 1500 stile-and-rail grid** on a 3 m × 6 m leaf.
That is the module this module draws to.

---

## The module is chosen, not assumed

A leaf is never an exact multiple of 1500, so `peb-sld-ndiv` divides it into the whole number of
panels nearest the target and spaces them equally. One rule, and it reproduces both sources:

| leaf | divisions | module | matches |
|---|---|---|---|
| 3000 (manual DSD) | 2 | 1500 | manual p755–758 |
| 3075 (this sample) | 2 | 1537 | — |
| 3936 (MSPL-030) | 3 | 1312 | job used 990 + 890 + 125 ends |

MSPL-030 is the honest disagreement: the job put a 125 edge and an 890 end panel either side of a
990 run rather than dividing equally. Equal division is the simpler rule and the one the manual
designs to; the difference is a panel-joint position, not a member size, and it does not change
what the customer is being sold. **If a job ever needs the exact as-built spacing, that belongs in
the BSF as a stile-spacing field, not in this file.**

---

## Traced vs stylised

Rulebook 4B.24 — *a stylised shape under correct dimensions is honest; invented dimensions are
not.* (Golden rule 20.)

**TRACED** — measured off the sources above, and safe to quote:

- the 1500 stile-and-rail module and the 3 × 6 leaf
- L50 × 5 perimeter and rail angle
- Ø12 round-bar diagonal
- U-channel track PL 3 × 214, and its 200 clear above the leaf top
- 12 clear under the leaf, floor guide 200 below FFL
- 120 mm C leaf framing; 200C / 250C jamb and header
- leaf overrun past the jamb, and the wall needed to park a leaf

**STYLISED** — drawn to look right, not measured:

- **the section shape of every member.** A stile plots as one 0.25 line at proposal scale, not as
  a C-profile. The *dimensions* around it are the traced ones.
- **the wheel**, drawn as a 55-radius circle in the track. The real `DOOR_WHEEL` is a proprietary
  bought-in item (see `MSPL-045_2022_door-wheel-channel.pdf`,
  `MSPL-067_2022_sliding-door-accessories-BOQ.pdf`), so its diameter is a supplier number, not
  ours.
- **the hood trim, cover trims and cover angles.** Real, and on every job drawing — but detail-
  drawing items. They do not belong on a proposal elevation.
- **the wall context** (`peb-sld-context`) is development scaffolding so the door can be judged
  in a wall. The building engine draws its own wall; do not call it from a sheet.

**NOT YET VERIFIED AGAINST THE VECTORS.** Golden rule 19 — the seam-lock skylight was traced at
637 from the text layer and turned out to be 484 across the finished panel. Every job number in
the table above was read from the PDF's **extracted text stream**, not from its geometry. Run
`reference/view_reference.js` and check before quoting any of them as an as-built.

---

## Pens — the only thing that survives the plot

The proposal PDF plots monochrome (`monochrome.ctb`, all four plot paths), so colour carries
nothing on the deliverable. Only lineweight does, and every entity here sets its own `(cons 370)`.

| | layer | pen |
|---|---|---|
| leaf and opening outline | `SLIDING DOOR` | **0.50** |
| track channel, jamb, header | `SLIDING DOOR` | 0.35 |
| stiles, rails, parked-leaf outline | `SLIDING DOOR` | 0.25 |
| diagonal brace, slide arrow | `SLIDING DOOR` | 0.18 |
| panel infill fill | `SLIDING DOOR` | **0.05** (golden rule M3) |
| the wall around it | `SHEETING` / `GIRTS` | 0.09 / 0.13 |

`SLIDING DOOR` is ACI 30 / 0.50 in `Rule_Book/PEB_LAYERS.csv`. It is orange in the DWG the
draughtsman works in, and black like everything else on the customer's PDF.

The door is the **only** thing on the sheet at 0.50. The first render put the wall context on the
door's own layer and the whole elevation read as door.

## Panel infill — one source, not two equal numbers

The leaf is clad in **sandwich panel** on both jobs, so it is drawn at the sandwich module —
`peb-sandwich-module`, declared beside `peb-sd-sandwich` in `MAIMAAR_PEB_Framing.lsp`, the drawer
that owns the profile. Golden rule 3: *"100% match" means one source, not two equal numbers.*

That also separates the door from its surroundings by **geometry** (golden rule M1): the sidewall
ribs at the 250 S pitch, the leaf at 184, and the two plainly differ on the page.

---

## Two failures this component hit, and how they were closed

**A linetype the drawing does not have is rejected in silence.** The parked leaf was first drawn
as a `HIDDEN` polyline. `HIDDEN` is not in a standalone drawing's table, and an `entmake` naming a
linetype the table lacks does not error — the ghost simply was not there, with nothing in the log.
It is now drawn as **strokes** (`peb-sld-dash`), the same reason `peb-mezz-hatch` strokes its own
45° lines instead of trusting a HATCH pattern.

**`SAVEAS DXF` re-prompts and eats the rest of the script.** The first harness wrote DWG, DXF and
PNG. The DXF step left an open prompt, the `PNGOUT` line was swallowed, and the run "succeeded"
for 300 seconds with no PNG (golden rule 10). The harness now writes DWG + PNG only.

---

## The plan symbol is not ours to invent

`peb-sld-plan` was first written as an offset line with a dashed pocket. Readable, and wrong:
Maimaar **already issues** a plan symbol for a sliding door, and it is on the sheet the customer
signs — `reference/MSPL-030_2021_APPROVAL-sheet18_sliding-door-on-elevation.pdf`.

The wall band **breaks** at the opening and becomes a **bow-tie**: each leaf a wedge tapering
from the full wall thickness at its own jamb to a point where the leaves meet. Above it, two
centred lines:

```
        SLIDING DOOR
         2438 x 3048
```

2438 x 3048 is a real Maimaar door — 8 ft x 10 ft. The drawer now draws exactly that symbol and
takes the second line as an argument. A component that invents its own symbol makes two sheets of
the same job disagree, which is the whole reason the library exists.

## The sample

`sample/render_sample.js` → `sample/last_render.png`, about 18 seconds.

A **double sliding door in a 6000 × 6000 framed opening**. That size is not chosen to look tidy —
it is the exact case the manual designs on p753–758, so every member on the sample has a published
calculation behind it. It is drawn in a piece of wall, with both leaves shown parked, because a
sliding door elevation that shows only the closed leaf tells the customer nothing about the wall
the door needs.

Needs no BSF and no inquiry — the drawers are pure geometry and take their size as arguments.

---

## Syncing into the building drawings

Three small, reviewable edits (golden rules, *Syncing*):

1. `(load ".../Library/sliding_door/MAIMAAR_PEB_SlidingDoor.lsp")` into `loadLines`,
   `services/drawingData.ts`.
2. A `SLIDING DOOR` case in the placement dispatch in `MAIMAAR_PEB_Elevation.lsp` — today a bare
   `RECTANG` for every accessory — calling `peb-sld-elevation` with the opening the BSF holds.
3. The **placement rule** on the BSF side, never in the LISP: which wall, the sill (FFL), and
   **which way it parks**. A door that parks into a corner or across another opening is a real
   clash, and that is a `geometryRules.js` decision, not a drawing decision.

Then render one real building and diff it against the previous PDF.

`peb-sld-context` and `peb-sld-sample` are **development only**. Neither is called by a sheet.
