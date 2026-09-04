# WALL LOUVER — fixed · adjustable · sand-trap

Every accessory on an elevation is drawn by `MAIMAAR_PEB_Elevation.lsp`'s placement loop as a
**plain rectangle** (`:252`, a bare `RECTANG` on layer `OPEN`, plus two diagonals when the type
says "door"). A louver, a window and a light panel therefore leave the proposal set identical.
This component closes that for the louver.

## The one thing it has to get right: SIZE IS A VARIABLE

The catalogue standard is **1000 × 1000 fixed** and **900 × 1000 adjustable**, but the BSF lets
the estimator type any `w` and `h` (`components.js` → `LOUVER_SPEC`), and the reference sheet
itself is drawn at a **1500** louver width. So nothing in the drawer is hard-coded to a size.
Width, height, type and screen come in as arguments and everything else is derived:

| Derived | Formula | Check |
|---|---|---|
| Framed opening | louver + 2 × 22 | 1500 → **1544**, 900 → **944**, 1000 high → **1044** |
| Openings `N` | ⌊span ÷ 100⌋ | 1000 high → **10**, as the manual's worked example |
| Free area `AEFF` | `N × C × L`, C = 0.035 m | 1.0 × 1.0 → **0.35 m²** |
| With insect screen | AEFF ÷ 2 | Section 13.8: "further reduced by 50%" |
| Girt to girt | framed opening + 2 × 48 | see *the 10 mm* below |
| Louvers for an area | ⌈required ÷ AEFF⌉ | 73.4 m² ÷ 0.35 → **210**, the manual's own answer |

That last row is the honest test of the whole thing, and the sample sheet prints it: the manual
works a real building through to *"Use 210 fixed louvers (1.0 m × 1.0 m), 105 on each sidewall"*,
and `peb-lv-count-for-area` reproduces 210 from the derived formulas, not from a stored number.

## THE STANDARD ADOPTED, and why

**The industry Technical Manual, Chapter 13 / Section 13.8 "Louvers"** — all eight pages are in
`reference/`, with every traced number and where it sits on the sheet in `reference/NOTES.md`.

That choice was made *after* looking for a Maimaar one. `E:\Maimaar Steel Pvt Ltd\Jobs` was
scanned end to end — **1,873 DWG/DXF and 24,526 PDFs**, by filename, by text inside every DWG,
and by `pdftotext` through every detail-, typical- and accessory-named sheet. **There is no
Maimaar wall-louver detail in it.** The only louver drawings that exist are:

- job **107-MSPL** (2023), a bespoke facade grill — blades at 554 / 747 / 946 in a fabricated
  frame, kept in `reference/` because it shows how Maimaar dimensions a louver elevation, but it
  is not the catalogue product;
- a client's cable-tray drawing and a client's interior `3"×1½" MS LOUVERS` timber-finish screen
  — neither is a PEB wall louver.

So the manual is not a fallback, it is the only dimensioned source that exists, and it is the
one the BSF's own field list was built against (1000 × 1000 default, fixed / adjustable /
sand-trap, insect screen, "same as wall").

## Traced vs stylised (rulebook 4B.24, golden rule 20)

**TRACED** — frame margin 22 each edge · projection 105 off the steel line · accessory girt 48
clear of the framed opening · blade pitch 100 · clear between blades C = 35 · blade face 65 ·
`SDS-4.8×20` self-drilling fasteners at 300 O.C. · standard sizes 1000 × 1000 and 900 × 1000.

**STYLISED, and labelled so on the sheet:**

- **The blade section.** The reference blade is a rolled Z with a return lip and *none of its own
  dimensions are given anywhere on the sheet*. It is drawn as a straight drainable slat falling
  to the outside. Correct dimensions under a straight shape is honest; inventing a lip is not.
- **The sand-trap.** Section 13.8 carries fixed and adjustable **only**. Maimaar sells a third
  type — the BSF offers it and the estimator prices it separately (`L1X1S5AZ` / `S7AZ` / `S7AL`,
  pinned by `estimation-louver.test.js`) — so it must be drawable. It is drawn with **vertical**
  blades at the same traced pitch and clear, which is what a sand trap is, and it stays marked
  stylised until a real sand-trap sheet is traced.

### The 10 mm the reference does not close

`SECTION-B` carries an overall of **1150** girt to girt, but its own chain reads
`48 + 22 + 1000 + 22 + 48 = 1140`. The 10 mm is undimensioned — most likely the girt flange.
`peb-lv-girt-span` uses the **chain**, because that is the part that is actually dimensioned and
the only part that scales. Do not adopt 1150 for other sizes.

## Why it reads differently from the sheeting: PEN, not colour

The proposal PDF plots monochrome (`monochrome.ctb` on all four plot paths), so every ACI
collapses to black on the deliverable. Only lineweight carries.

| | Layer | Pen |
|---|---|---|
| Steel sheeting | `SHEETING` | 0.09 |
| **Louver frame** | `LOUVER` | **0.50** |
| Louver blades | `LOUVER` | 0.25 |
| Insect screen | `LOUVER` | 0.05 |

`LOUVER` (ACI 3 / 0.50) **is in `Rule_Book/PEB_LAYERS.csv`** and in the generated
`_PEB_LAYERS_generated.lsp` — put there by the sliding-door terminal (commit `2719e93`), not by
this work. Golden rule M4 still lists it as off-standard; that entry is now stale and the list is
down to two. Nothing here regenerated the standard: rebuilding it pulls in unrelated drift
(`FRAME` 1/0.30 → 7/0.50, `COMP-MEZZ-BEAM` 0.50 → 0.40), exactly what golden rule 9 says to
refuse, so the generated file was restored **byte-identical**.

## The screen and the blades never overlap

The materials catalogue records the insect screen as a crossed line fill at **120**. That is
within 20% of the **100** blade pitch — precisely the frequency clash rule M2 warns about, and
laid one over the other it reads as a grey blob.

The reference sheet had already solved it: its `LOUVER EXTERIOR` view is **split by a diagonal
break**, mesh on one side, blades on the other. `peb-lv-elev` draws it that way — the fill and
the blades are each clipped to their own side of the break line — so each material reads at its
own frequency and neither competes.

A louver drawn 40 mm wide in a band along a 48 m wall has no room for that, so
`peb-lv-band-on-wall` passes `showScreen` = nil and gets blades edge to edge.

## Annotation

One L-leader for a whole band carrying `NN No. <TYPE> W × H` — golden rule 17, the same rule the
wall lights follow. A band of louvers labelled one by one is noise.

The detail captions state the **rule**, not one job's numbers (golden rule 18): the size drawn,
`N × C × L = AEFF`, and whether the screen is in. Nothing on the sheet is job-specific.

## Text height — the fix the light panel still needs

`peb-th`'s ladder is `ANNOT` **830 mm**, which plots at 3.0 mm on an A1 sheet showing a 48 m
building. Used unchanged on a 1000 mm louver **one caption is 83% of the louver's own height**.
`*PEB-TEXT-SCALE*` does not fix it, because that scales *offsets*, not heights — which is why the
light panel's sample sheet is still recorded as broken.

So this component sets its own: `peb-lv-set-th` is called once with the smallest louver on the
sheet, and text, ticks, dimension-ladder gaps and column pitch are all multiples of it. Every
view also **returns the width it consumed, annotation included**, so the sample lays the next one
out after it instead of advancing by a guessed millimetre offset. Nothing can collide however the
sizes change.

## What is in here

```
MAIMAAR_PEB_Louver.lsp   the drawers — pure geometry, nothing reads the BSF
reference/               Section 13.8 (8 pages, PDF + PNGs), the 107-MSPL grill, NOTES.md
sample/render_sample.js  the harness: 4-5 louvers, 4 sizes, 3 types, one scale
sample/last_render.png   what it looks like
```

Entry points: `peb-lv-elev` · `peb-lv-detail` · `peb-lv-section-a` · `peb-lv-section-b` ·
`peb-lv-band-on-wall` · `peb-lv-free-area` · `peb-lv-count-for-area`.
`node sample/render_sample.js` → a PNG in ~18 seconds.

## The data side — done

`LV_*` keys are emitted by `services/drawingData.ts`, beside `WA_LIGHT_*`. The BSF splits the
louver across two components (`adjLouver`, which has no type field because the card *is* the
type, and `fixedLouver`, which offers Fixed / Adjustable / Sand-trap) because that is how the
estimator prices them; they are resolved to **one** set of drawing keys there — `LV_ON`, `LV_QTY`,
`LV_TYPE`, `LV_W`, `LV_H`, `LV_MAT`, `LV_COLOR`, `LV_SCREEN`, `LV_WALLS`, `LV_MODE`,
`LV_PER_BAY` — so the LISP never compares a card name. The BSF computes, the drawing reads.

## Where a louver sits — it is the AIR INTAKE

> "Louver are used for the Air-Intake" · "Top Level of Louver must be 300mm below the top of
> brickwork level, as sometime there is beam on the top" — owner, 4-Sep-2026

The louver is the **inlet** of the ventilation system; the ridge/turbine ventilators are the
outlet. Air enters low, warms, rises and leaves at the ridge — so the louver belongs in the low
band of the wall. The reference manual says the same in its arithmetic: the louvers supply the
building's **free inlet area**, which must exceed **150% of the ventilation (exhaust) area**.

**The rule** (`geometryRules.louver()`): `head = brick − 300`, `sill = head − height`.

The 300 is **beam clearance**, not a margin for looks — a capping / tie beam commonly runs along
the top of the masonry, and a louver whose head is on the brick line fouls it. Leaving the gap is
right whether or not a given job has the beam, which is the only way one rule serves every job.

| Case | Sill |
|---|---|
| Fits in the dado | `brick − 300 − height` — the normal case, clear of the beam |
| Dado too short | `brick + 300` — clears the beam from **above**, in the sheeting |
| No brickwork | `0.9` — no masonry, no beam; the engine's own non-door default |

On MSPL-26-266 (brick 3048, louver 914): **head 2748, sill 1834**.

**The level is derived, never read.** There is no louver sill field on the BSF card, because
where a louver sits is settled by what it is for and by the beam above it. `drawingData.ts`
derives it, which also corrects 266 — whose placements still carry 2134 from the first draft —
without anyone re-touching the BSF. Each wall reads its own dado.

**If a building needs more air, add louver AREA — do not drop the sill.** Stack flow goes as the
square root of stack height but linearly with free area: on 266, dropping the sill from 2134 to
600 buys about +18%, while one more louver per bay buys +100%.

**The masonry is removed where a louver comes** — a guarded `WIPEOUT` over the framed opening, so
the brick coursing stops at the louver instead of running through it.

## Status — SYNCED, and drawing on MSPL-26-266

All three sync edits are done, and the louvers now draw in the brickwall on both side-wall
elevations (PRO-03 framing and PRO-05 sheeting).

1. `(load …)` — added to `loadLines` in `services/drawingData.ts`. **`scripts/renderOneSheet.js`
   kept its own copy of that list and had no library on it at all**, so a sheet rendered through
   the harness drew no library component while production drew one. It now reads the `Library/`
   folder instead of holding a second list that can drift.
2. The dispatch — `peb-fr-open-sill` / `peb-fr-open-ht` / `peb-fr-draw-opening` in
   `MAIMAAR_PEB_Framing.lsp`. Both wall elevations drew **every** framed opening as a box from
   the wall base to `0.72 × eave height`, so on 266 all twelve louvers and all twelve windows
   plotted at `0 → 4662.6`: a 914-high louver came out a 4.66 m tall rectangle standing on the
   floor. `PL*_SILL` and `PL*_HEIGHT` were in the data the whole time and nothing read them.
   Now: louvers `2134 → 3048`, windows `3962 → 5486`, the door `0 → 3658`.
3. The placement rule — nothing to add. 266 already stores sill 2134 against a 914 louver and a
   3048 brickwall, and `2134 + 914 = 3048` puts the head exactly on top of the brickwork. A
   `geometryRules.js` default that *derives* that (`sill = brick − height`, the brick-line twin
   of the light panel's `sill = clear − length`) is still worth adding so a louver typed on a new
   job lands there without anyone typing it.

Two things the real sheet taught, both now in the drawer:

- **Blade density follows the plot, not the product.** At the elevation's 1:259 the traced 100
  pitch is 0.39 mm on paper, nine blade pairs merged, and every louver plotted a **solid black
  block** (golden rule 5: a dense fill reaches the customer black). Below ~1.5 plotted mm the
  drawer falls back to an indicative 4 strokes. The traced pitch still governs the detail and
  still governs AEFF — only what is legible at that scale changes.
- **A framed opening is a hole.** The brick hatch ran straight through the louver, coursing
  visible between the blades. A guarded `WIPEOUT` over the framed opening masks it, the same
  device and guard the brick-height label already uses, drawn before the louver so it hides the
  fill and nothing after it.
