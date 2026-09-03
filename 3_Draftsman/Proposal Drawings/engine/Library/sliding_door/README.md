# SLIDING DOOR

A sliding door is a **leaf hung from a track**, not a hole in a wall. Everything that makes it
read as one on a drawing — the track running well past the opening, the sandwich-panel bays
between cover trims, the floor rail on its stubs, the wall it needs to park in — is what the old
placement loop threw away when it drew every accessory as a `RECTANG` with two diagonals.

> **Every number here was measured off the issued drawings' VECTORS** (golden rule 19), not read
> off their text stream. `reference/view_reference.js` imported both sheets; the measurement
> overturned three things this file first had wrong. They are set out under *What the vectors
> corrected* below, because each one is a trap the next component will meet too.

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
| real example | **MSPL-030 SDS-01** — 3936 opening, 4039 leaf, parks over 3936 of wall | the bow-tie on the approval sheet |

**The leaf is not symmetric.** MSPL-030 dimensions it `539 | 302 | 1448 | 1448 | 302`: a wide
**leading strip** carrying the meeting stile and its cover trim, then the panel field, then a
narrow cover trim at the jamb end. Drawing it symmetric put an equal closer at both ends and lost
the meeting stile altogether. `peb-sld-leaf` takes a `lead` argument; on a bi-parting pair the
two leaves lead at each other.

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

## What the vectors corrected

**1 · There is no diagonal brace.** The first version drew one, from a shop drawing listing
`DOOR_ROUND_BAR DRB-1 = D12 x 4500` with a 45° note. Both elevations show what that bar really
is: the **floor guide rail**, running the whole slide length below FFL on short stubs, with L50×5
clips at ~830 centres. `ROUND_BAR` on MSPL-030 points at the same rail. A sliding door leaf is a
panel in a frame; it is not braced like a portal.

**2 · There is no stile grid on the elevation.** The manual designs the leaf on a 1500 × 1500
stile-and-rail grid (p755–758) and that design is real — but the stiles are **behind the panel**
and neither issued drawing shows them. What the drawings show is the sandwich-panel field between
cover trims. The manual sizes the members; the drawing draws the door. The member sizes stay in
the schedule; the elevation stops inventing lines.

**3 · MSPL-030 SDS-01 is a SINGLE leaf, not a pair.** The `3936` on that sheet labels the **wall
the leaf parks over**, not a second leaf — the leaf is 4039 and the total run is 7972. Reading
`3936 / 3937` out of the text stream as two leaves is exactly the mistake the text invites, and
the hatch pattern in the geometry settles it: the region is masonry, not door.

## The panel field is chosen, not assumed

MSPL-030 divides a 3495 field as `302 | 1448 | 1448 | 302` — whole panels in the middle, the
remainder split evenly between two closers. `peb-sld-joints` applies that rule, not those
numbers, so any leaf width comes out the same way. On the reproduced sheet it lands at
`539 | 291 | 1448 | 1448 | 291` against the issued `539 | 302 | 1448 | 1448 | 302`: **the leading
strip and both full panels exact, the closers 11 mm out.**

There is a guard — a closer narrower than a fraction of a panel reads as a slip rather than a
closer, so one whole panel is dropped and the closers grow. **The threshold is calibrated, not
guessed.** It was first set at 0.20, and MSPL-030's own closer is 302 on a 1448 panel = 0.209 —
the guard threw away the very drawing it was derived from and collapsed `302|1448|1448|302` into
`1002|1448|1002`. It is 0.12.

## The sandwich bays are left clear

MSPL-027 (2021) ribs the panel across the whole leaf; MSPL-030 (2022) leaves the bays clean and
shows only the joints. At proposal scale a 184 module across a 4 m leaf is 22 lines and reads as
a solid block, so the newer, cleaner convention is the one drawn. The rib field is still there —
`peb-sld-leaf` takes a `ribs` flag — for a detail drawn at size.

## Traced vs stylised

Rulebook 4B.24 — *a stylised shape under correct dimensions is honest; invented dimensions are
not.* (Golden rule 20.)

**TRACED** — measured off the sources above, and safe to quote:

- the leaf's own layout: leading strip **539**, panel **1448**, cover trim **70**
- leaf height **2430** (2462 over trims), underside **12** clear of FFL
- floor rail stubs at **125 / 890 / 990**, guide **200** below FFL
- L50 × 5 perimeter angle, Ø12 round bar — **as the floor rail**
- U-channel track PL 3 × 214, hood trim over it, clips PL 3 × 100
- 120 mm C leaf framing; 200C / 250C jamb and header (manual p750)
- the assembly set **410** off the grid, and the wall a leaf needs to park in

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

**VERIFIED AGAINST THE VECTORS**, 3-Sep-2026 — both sheets imported with
`reference/view_reference.js` and measured; the DXFs are kept beside them. The three corrections
above are what that pass found. The one number still taken on trust is the **sandwich panel width
1448**, which the text dimensions and the geometry disagree about (the field is drawn as three
equal bays); the drawn field is reproduced, the dimension is quoted.

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

`sample/render_sample.js` → `sample/last_render.png`, about 18 seconds. No BSF, no inquiry — the
drawers are pure geometry and take their size as arguments.

It reproduces **MSPL-030 SDS-01** at the sizes measured off that sheet: a single sliding door,
opening 3936, leaf 4086, height 2430, parking over 3936 of wall, total run 7972. It is drawn in a
piece of wall with the leaf shown parked, so it can be laid beside
`reference/MSPL-030_2022_SDS-01_*.pdf` and compared line for line. That is the point — a sample
at an invented "standard size" cannot be checked against anything.

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
