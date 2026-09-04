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

| Sheet | Placement | Guard |
|---|---|---|
| **Cross section** PRO-02 | on the ridge apex, `peb-ridge-x` across the span | skipped when `monoRise` — a single-slope roof has no ridge |
| **End wall sheeting** PRO-06 | astride the gable apex, mirrored for the outside view | end walls only; a side wall hides the ridge behind itself |

Sheeting elevation only, following the wall-light standing rule: the framing elevation is about
structure, and this is an accessory on the finished roof.

`peb-rv-plan` draws the plan bar (3000 long on the ridge, as MSPL-203 sheet 18 draws it, raked
rather than SOLID because a solid fill reaches the customer black) — written, not yet wired into
the roof plan.

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
