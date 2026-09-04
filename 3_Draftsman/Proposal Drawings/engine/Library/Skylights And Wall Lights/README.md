# LIGHT PANEL — wall light / sky light

One product, two names (Nasir, 3-Sep-2026): *"on Wall it is called Wall Light not Skylight,
though both have the same material — as we say purlins and girts."* Same fiberglass, same
profile; the NAME follows the surface. Nothing here hard-codes one.

## STANDING RULE — where it appears

> "wall lights will come on the Walls Sheeting Plan" — Nasir, 3-Sep-2026

The wall light belongs on the **WALL SHEETING ELEVATIONS** (PRO-04a side walls / PRO-04b end
walls), not on the framing elevations. It is a cladding item: it replaces a sheet on the sheet
module, so it is drawn where the sheeting is drawn. The sky light equivalently belongs on the
**ROOF SHEETING PLAN** (PRO-05b), which is where `peb-draw-skylights-per-bay` already puts it.

## The numbers, and where each came from

**SAME PROFILE — THE MATERIAL IS THE ONLY DIFFERENCE** (owner, 3-Sep-2026). The panel is not a
product of its own; it is the building's own sheet profile, in fiberglass.

| | Wall light | Sky light, S-profile roof | Sky light, lock-seam roof |
|---|---|---|---|
| Profile | Standard S 35-250 | Standard S 35-250 | **Lock Seam** |
| Cover | 1000 | 1000 | 470 |
| Thickness | 1.5 mm | 1.5 mm | **2.0 mm** |
| Drawn by | `peb-sd-sprofile` | `peb-sd-sprofile` | `peb-sd-lockseam` |

Neither profile is re-authored here. Both are the functions the DETAILS sheet already draws the
STEEL sheet with; each gained a `*PEB-SPROF-LAYER*` override so the same geometry lands on the
light-panel layer. `peb-acc-light-section` picks between them from `RA_SKY_PROFILE`, and
`peb-acc-thk-for` picks the matching thickness. A wall is never lock seam — that is a roof-only
sheeting option — so a wall light needs no choice.

### What the PAECO sheet shows, and why we do not draw it

MSPL-224 / MSPL-169 carry a *separate* `SKYLIGHT PROFILE : THK. 2mm` beside the lock-seam sheet.
Measured off the imported DXF — the polyline itself, not the dimension text (rule 19) — it is:

```
 152 big rib | 134 pan | 65 small stiffener rib | 134 pan | 152 big rib   = 637 overall
 big rib 75 deep · small stiffener rib 36 deep · crown 25
 COVER 484, crown centre to crown centre        (637 − 152 − 25 = 460 … 485 measured)
 25 x 25 x 1.2 tube on the middle rib
```

The paper coordinates scale at ~24.5 mm/unit and land exactly on the drawing's own dimension
chain, which is the check that the reading is right. Two corrections came out of it: the shape is
**not** a single trapezoid — there is a small stiffener rib in the middle that the first reading
missed entirely — and **484 is the cover, crown to crown**, the same convention the S profile
uses, while 637 is the overall width.

It is recorded here so the measurement is not lost, but it is a supplier's own product. The
house rule is the one above: the panel takes the building's sheet profile.

## Why it reads differently from the sheeting

The proposal PDF plots **monochrome** (`monochrome.ctb` — `MAIMAAR_PEB_PDF.lsp:90`, `:140`,
`drawingRender.ts:394`, `:1263`), so colour carries nothing on the deliverable. Only pen does.

| | Layer | Pen |
|---|---|---|
| Steel sheeting | `SHEETING` | 0.09 |
| **Light panel outline** | `SKY LIGHT` / `WALL LIGHT` | **0.50** |
| Translucency fill | same | 0.05 (`peb-sky-hatch`) |

Both light layers were added to `Rule_Book/PEB_LAYERS.csv` on 3-Sep-2026 at ACI 4 / 0.50, and
the outline also carries `(cons 370 50)` on the entity so it is right even in a drawing whose
layer table did not come from the standard.

## Annotation

> "no need to mention the labeling of wall lights — just show the wall lights ... Only L-Type
> ladder with Text 'Wall Light - Type' ... Maximum Write the Qty"

A band of 48 panels labelled individually is noise. The band reads as a band; **one** L-leader
(`peb-label-with-leader` with `"V"` — its 3-vertex L) carries `NN No. WALL LIGHT - TYPE`.

## Length and sill — computed by the BSF, never by the drawer

`geometry.lightPanel(clearHeightM, brickHeightM, statedLenM)` in
`2_Sales CRM/public/modules/sales/geometryRules.js`:

- the head always lands on the clear-height line, so **sill = clear − length**;
- the default length is the standard 3250, shortened only as far as the brickwork forces.

For MSPL-26-266 (clear 5486, brick 3048, stated length 1524) it yields **sill 3962, head 5486** —
confirmed live in `WA_LIGHT_SILL` / `WA_LIGHT_HEAD`. The drawer reads those and re-derives
nothing.

## Status — SYNCED

Wired into the production drawings on 3-Sep-2026 and verified on MSPL-26-266:

- **Wall lights** draw on the **SIDE / END WALL SHEETING ELEVATIONS** (PRO-05) via
  `peb-fr-wall-lights` in `MAIMAAR_PEB_Framing.lsp`, gated on the BSF Include tick, at the sill
  the BSF computed, with ONE `NN No. WALL LIGHT - TYPE` leader per wall. The framing elevation
  deliberately does not get them - a wall light is cladding.
- **Sky lights** on the ROOF SHEETING PLAN now call this library's `peb-acc-light-elev` instead
  of the roof plan's own poly + hatch, so roof and wall are ONE drawer (rule 1). The roof opens
  the sheen out to `/4` via `*PEB-ACC-SHEEN-DIV*` because it shows the panel small - a scale
  choice, not a second implementation.
- The library is loaded from **all three** load lists in `services/drawingRender.ts`. Note the
  sheets are NOT built from `drawingData`'s `loadLines`: adding it there alone produced a set
  with no wall lights and no error to say why.

Verified: 266-26's PDF grew 921,087 -> 965,162 bytes and the side-wall sheet shows the band on
both NSW and FSW above the brickwork, head on the clear-height line.

### Still open

- the seam-lock sky light is **a proven product, not a theory**: installed at PAECO Kasur
  (MSPL-169, 2025 and MSPL-224, 2026) and successful in service. What has not happened yet is
  our ENGINE rendering one, because no job currently in the CRM has a lock-seam roof - so the
  drawn output is unverified even though the detail behind it is built and working;
- the wall-light band draws whole panels across the full wall; it does not yet stop short of a
  door or a louver.

