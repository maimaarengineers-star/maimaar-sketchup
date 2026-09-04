# GRAVITY RIDGE VENTILATOR — **symbol only**

> "Only symbol for the Proposal Drawings ... In Next Phases we will develop the complete in all
> respect. Symbol means should be excellent presentation once we should place in the PD Section
> and Elevation." — owner, 4-Sep-2026

This draws a **symbol**, deliberately: the ventilator's true outside profile, at its true size,
placed correctly on the ridge, drawn well enough to carry a proposal — and **not** its twenty-odd
fabricated parts. The approval drawing has those (L-1…L-5A, T-1…T-4, CH-1, CL-1, CL-2, MSB bolts,
screws) and a later phase will draw them. A proposal sheet at 1:193 cannot show a 0.5 mm brace
plate and should not pretend to.

**A symbol is not a licence to invent.** Every dimension is traced, so the symbol is the real
product simplified, never a cartoon.

## What it is for

The ridge ventilator is the **OUTLET** of the ventilation system; the louvers (`../Louver/`) are
the **INTAKE**. Air enters low through the louvers, warms, rises, and is discharged here. The two
are sized against each other — the reference manual requires the free inlet area to exceed **150%
of the ventilation area**.

## TRACED — from Maimaar's own drawing, not a manual

**MSPL-203** (Afridi Markets / DHL Warehouse, Islamabad, 2025) is the job where the ridge
ventilator was **in Maimaar's own scope**, so its approval sheet 20, *RIDGE VENTILATOR DETAILS*,
is Maimaar's own product. SECTION A-A (FRAMING) dimensions it completely:

| | |
|---|---|
| Overall width | **600** (300 + 300 about the ridge) |
| Overall height | **542** above the roof line at the ridge |
| Hood underside | **288** clear of the roof sheet — **this is the throat** |
| Wind band (skirt) depth | **203** |
| Top flat | **400**, with a **120** turned-down return each end |
| Unit length | **3000** (TOP VIEW, and the `RV-01` legend on sheet 18) |
| Bird mesh | **12 × 12 G.I.** |
| Purlins | 200Z 1.5 either side of the opening |

Cross-checked against the industry manual's Section 13.7 table (`reference/NOTES.md`): MRV 300 /
MRV 600, both 3000 long, throat area = throat × length (0.9 / 1.8 m²), damper an option on the
300 only. Maimaar's own unit is a 600 throat.

## How it is presented

On a 22.8 m cross section a 542 mm hood is about 3 mm of paper. It reads because of **pen**, and
because **the throat is left open** — the outline is deliberately *not* closed along the bottom.
That gap is the one feature that says "ventilator" rather than "box on the ridge".

| | Layer | Pen |
|---|---|---|
| Hood outline | `RIDGE-VENT` | **0.50** |
| Throat edges / mesh hint | `RIDGE-VENT` | 0.13 |
| Roof sheeting behind | `SHEETING` | 0.09 |

`RIDGE-VENT` (ACI 4 / 0.50) was added to `Rule_Book/PEB_LAYERS.csv` rather than inventing another
ad-hoc layer (golden rule M4).

**Bird-screen density follows the plot, not the product.** The mesh is 12 × 12; drawn at that
pitch on a proposal section it is solid ink. The drawer hints it with a few ticks and drops even
those when the plot is too small — the real mesh spec stays in the note. Same rule the louver's
blades follow.

## The callout takes the HOST SHEET's size

This cost two renders and is worth stating plainly. **One component, two host sheets, two
different annotation sizes:**

| Sheet | Its own callouts | What the caller passes |
|---|---|---|
| Cross section (PRO-02) | `PURLIN` / `RAFTER` / `EAVE GUTTER` at **198** | the literal **220** the section already uses |
| End wall sheeting (PRO-06) | `WALL SHEETING` 480, wall-light band **664** | **`(peb-th 'ANNOT)`** |

Handed `peb-th`'s raw `ANNOT` on the section, the callout came out **673 tall against their
198** — three times everything around it, straddling the roof note and running out over the
title block. Handed the section's 220 on the elevation it was a third of its neighbours. So the
drawer holds **neither**: `peb-rv-place` takes the height as an argument and each sheet supplies
its own. Leader offsets are multiples of that height too — a gap measured in text heights is the
same gap on every sheet, whatever the scale. (Measured in `*PEB-TEXT-SCALE*` instead, the label
was thrown up into the sheet title on the elevation.)

## Where it is placed

| Sheet | What it shows | Guard |
|---|---|---|
| **Cross section** PRO-02 | one unit end-on at the ridge apex | skipped when `monoRise` — a single slope has no ridge |
| **End wall sheeting** PRO-06 | one unit end-on astride the gable apex | mirrored for the outside view |
| **Side wall sheeting** PRO-05 | **every unit seen along its 3000 length**, one per bay, standing on a light ridge reference line | gable roofs only |
| **Roof sheeting plan** PRO-08 | **every unit in plan**, one in the middle of each bay, hood footprint + throat opening | falls back to even spacing if the bay grid is unusable |

Sheeting elevations only, following the wall-light standing rule: the framing elevation is about
structure, and this is an accessory on the finished roof.

## What the audit changed (4-Sep-2026)

**The side wall elevation was drawing nothing, and that was wrong.** The first cut reasoned that a
side wall hides the ridge. **Mammut's own proposal drawing says otherwise** — PK-14-202 (Rafhan
Maize), sheet 04 *NEAR & FAR SIDE WALL ELEVATION*, in `reference/`, draws the ventilators marching
along the top of the side elevation, one per bay, with a single `RIDGE VENTILATOR` leader. They
are right: the ridge is the **highest line on the building**, so units standing on it are seen in
silhouette above the roof. That is also the only view showing how many there are and how they are
spaced. `peb-rv-side` draws them, and their sheet 02 *TOP ROOF PLAN* confirmed the plan
convention — one per bay, mid-bay, on the ridge.

**The throat opening was missing everywhere.** The hood is 600 wide whatever the throat is, so a
300 and a 600 were drawn identically — hiding the one number the whole ventilation calculation
runs on (throat area = throat × length, 0.9 vs 1.8 m² per unit). Every view now shows the opening
cut in the roof at the size the BSF states: jamb ticks in section, a clear inner rectangle in
plan with the hood raked only either side of it.

**The roof plan drew nothing at all, silently.** Two causes, both worth remembering:
- the block had been absorbed into a neighbouring `(if …)` branch during a paren-matched insert,
  so it only ran for RCC-floor buildings — it now sits at the function's top level;
- `MSPL-Get-Num` returns **nil** for an absent key and `(max 0.0 nil)` throws, inside a
  `vl-catch-all-apply` that the caller had *already* wrapped in a second one. Two nested silent
  catches and nothing appeared. Every number now goes through `atoi`/`atof` on a string.

**Two estimation defects**, pinned by `tests/unit/estimation-ridgevent.test.js`:
- the throat **defaulted to 600** in `computeRidgeVent` and `mapComponents` while the BSF card
  defaults to **300** — a job whose throat was never touched priced the bigger unit while the
  drawing and the proposal both said 300;
- a **damper was priced on a 600**, which has no damper option (the manual's table is explicit).
  It fell through `hasRate` to the undampered code, so the customer was quoted, silently,
  something they had asked for and cannot have.

**Nothing checked that the louvers could feed the ventilators.** The manual's rule is that free
inlet area must exceed **150% of the ventilation area**; `drawingData` now warns when it does not.
MSPL-26-266 trips it: 6 units give 5.40 m² of ventilation area needing 8.10 m² of inlet, and its
12 louvers give 5.76 m² — halved by their insect screen.

## Entry points

`peb-rv-symbol` · `peb-rv-profile` · `peb-rv-plan` · `peb-rv-label` · `peb-rv-place`
Run `node sample/render_sample.js` for the symbol at true size with its traced chain, next to the
same symbol as actually placed.

## One trap this file paid for

`t` and `k` were used as local variable names. **AutoLISP is dynamically scoped**, so every
callee — `peb-comp-layer`, `txt`, the entmake helpers — saw `T` (true) rebound to a number. The
sheet rendered "successfully" and came out **completely blank**, with nothing in the output to
say why. Never name a local `t`.

## Status

Symbol built, traced, and drawing on MSPL-26-266's cross section and end-wall elevation.
`lispcheck` clean. `RA_RV_*` keys flow from the BSF. The full fabricated detail is a later phase.
