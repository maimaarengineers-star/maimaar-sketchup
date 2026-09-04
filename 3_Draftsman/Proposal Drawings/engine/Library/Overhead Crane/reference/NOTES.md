# Crane reference — what is here and what it proves

Gathered 4/5-Sep-2026 for the Overhead Crane component. Everything below is **quoted from the
drawings**, not inferred. Numbers a drawer uses must be traced to a line in this file (rule 20).

## The files

| file | what it is | why it matters |
|---|---|---|
| `MSPL-032_crane-beams-and-plates.pdf` | **Maimaar's OWN workshop** (032-MSPL, 2021) — single-part drawings, crane beams + plates | the house crane, built and standing |
| `MSPL-032_assembly.pdf` | same job, assembly drawings | how the beam, bracket and column go together |
| `MSPL-032_erection.pdf` | same job, erection drawings (5.2 MB) | the crane in the erected frame |
| `MSPL-125-23_Thal_crane-shed_CLP.pdf` | Thal Industries crane shed — **cited by name in `Plan.lsp` as the house-style CLP** | two cranes on one runway, 10 MT + 50 MT |
| `MSPL-034-23_HBA_crane-shed_CLP.pdf` | HBA crane shed — **the other CLP `Plan.lsp` cites** | gable crane shed |
| `MSPL-210-25_overhead-crane-gantry.dxf` | Style Textile — Supply & Installation of an overhead crane **gantry**, already DXF (8.3 MB) | parseable geometry, a real gantry |
| `MSPL-113-22_crane-beams.pdf` | crane beams | `Crane Beam - 50 grade — 4,522` |
| `MEC-19-040_crane-rail-detail.pdf` | crane **rail** detail | the rail section itself |

DWG originals convert with `scratchpad/dwg2dxf.js <in.dwg> <outDir>` → DXF + PDF + PNG.
**AutoCAD's `-PDFIMPORT` fails on a path containing a space** — copy to a space-free path first.

## Traced numbers

### Thal 125-23 — two cranes, one shed (Clear Span, monoslope)

| | crane 1 | crane 2 |
|---|---|---|
| Capacity | **10 MT** | **50 MT** |
| Crane span | **21.335 m** | 21.335 m |
| Crane run length | **73.144 m** | 27.429 m |
| Type | TR (top running) | TR |
| No. on one runway | 1 | 1 |
| **Max Crane BEAM height from FFL** | **10.044 m** | **14.922 m** |
| Wheel base | TBE | TBE |
| Vertical / horizontal wheel load | As per design | As per design |
| CMAA class | TBE | TBE |

### HBA 034-23 — Clear Span, gable

* **Max Crane HOOK height from FFL — 6.00 m**

### Maimaar standard note, quoted from Thal

> "All runway beams for crane lifts **less than or equal to 15MT are built-up sections with double
> side fillet weld**."

That is a real design rule and it sorts the whole range: ≤ 15 MT built-up, above that rolled or
heavier. Thal's own 50 MT sits the other side of it.

## ⚠ BEAM height and HOOK height are two different fields

Thal's spec states **"Max Crane Beam Height from FFL"**; HBA's states **"Max Crane Hook Height
from FFL"**. They are not the same level — the beam sits above the hook by the bridge girder plus
the hoist and end-truck stack.

The BSF captures only `hookHeight` ("Max Crane Hook Height from FFL (m)"), and the section derives
the beam from it — on MSPL-26-276 it prints `HEIGHT OF CRANE BEAM : 9858` from a 6.0 m hook. So
the engine is doing the right thing, but a job whose customer quotes the **beam** height (as Thal
did, 10.044 / 14.922) has nowhere to put it and it will be entered as a hook height, ~3.8 m too
high. Worth a second BSF field, or at minimum a label that says which one is meant.

## Live case the component is being developed against

MSPL-26-276 Sharif Oxygen (inquiry 5401, area 5172): 10 MT Kone TR, span 17.69 m, run 30.48 m,
hook 6.0 m, wheelbase 3.9 m, CMAA C cat 3, pendant, 84 / 11 kN, grids 1-5 × A-B.
`bridgeDepth` and `lift` are **blank** — the section falls back to a representative bridge depth.

## Still wanted

* A **SketchUp / rendered view** of a crane building — not yet found.
* The **Mammut design manual crane chapter** (`D:\Design Manual\mammut design manual.pdf`):
  capacity/span tables, hook approach, clearance under the haunch, bracket and runway sizing.
* Crane **bracket** geometry from `MSPL-032_assembly.pdf` — the cantilever off the column that
  carries the runway beam.

---

# AUDIT — the top view against the Mammut manual (5-Sep-2026)

## What the manual actually contains

`D:\Design Manual\mammut design manual.pdf`, **chapter 8 "Crane Loads" (MBMA 02 / MBMA 06)**,
extracted with `pdftotext -layout` — 473 crane hits, chapter opens at line 20931.

**It is a LOADS chapter, not a detailing chapter.** It specifies service classes, impact factors,
wheel loads, lateral and longitudinal forces, fatigue categories and runway beam stresses. It does
**not** give bridge girder proportions, end-truck dimensions, hook approach or clearances. So
"100% match the manual" is achievable for everything the manual states — and it is now matched —
but the manual cannot settle the geometry. That has to come from the drawings, which is why
MSPL-032, the Thal/HBA CLPs and the 210-25 gantry DXF are in this folder.

## Matched — every item the manual states about a bridge

| item | manual | drawn / stated |
|---|---|---|
| Crane types | ch.8: Top Running (Gantry), Monorail, Underhung, Jib, Semi-Gantry | TR stated, all five named on the sheet |
| **End truck wheels** | **"NWb = Number of end truck wheels at ONE END of the bridge"; worked 10 MT example: "Number of end truck wheels = 2"** | **2 per end truck, 4 total — DRAWN in the top view** |
| Vertical impact | table 8.3: pendant operated bridge cranes = **10%** (cab/radio 25%, hand geared 0) | stated on the sheet |
| CMAA service class | table 8.1, classes A–F | C stated |
| Worked example | RC 10 MT, HT 0.74 MT, crane 8.30 MT, CW 7.56 MT, WL = (RC + HT + 0.5CW) / NWb = 7.26 MT | the sample is built at 10 MT, the same case |
| Eave height driver | "Clearance above Crane beam / Crane hook height requirement" | the section already derives the beam from hook height |

## Traced from the drawings, not the manual

| item | value | source |
|---|---|---|
| Span | 21,335 | Thal 125-23, both cranes |
| Capacity | 10 MT / 50 MT | Thal 125-23 |
| Runway beam construction | built-up, double side fillet weld, **≤ 15 MT** | Thal 125-23 spec note |
| Wheel base | 3,900 | MSPL-26-276 BSF (the manual gives the wheel COUNT, a job gives the base) |

## Declared STYLISED (rule 20) — not traced, and said so on the drawing itself

* **Girder depth = span / 18.** A working proportion for a welded box girder in this capacity
  range. The sheet prints "(STYLISED – SPAN/18)" next to the dimension so nobody reads it as
  traced. A job's own `CRn_BRIDGE` overrides it.
* Girder width in plan = 0.72 × depth; end-truck stand-off, wheel radius and trolley length are
  proportions of the girder.

## Still open before sync

* **Hook approach** — the minimum distance the hook can reach toward the rail. Not in the manual,
  not yet traced from a drawing; the top view does not show it.
* **End stops / bumpers** on the runway — manual discusses bumper FORCES (ch.8, "the force is
  assumed to act at bumper height or 375 mm above floor level") but not the detail. Not drawn.
* The **210-25 gantry DXF** (8.3 MB, in this folder) carries "MAIN BEAM", "CRANE BRACKET" and
  "X : HOOK LENGTH" callouts — worth parsing for real bracket and hook-approach geometry.

## Parsed: MSPL-210-25 gantry DXF (5-Sep-2026)

16,982 entities, 41 layers, **349 DIMENSION entities carrying 109 distinct measured values**.
Callouts present: `SUPPLY & INSTALLATION OVER HEAD CRANE GANTRY`, **`MAIN BEAM`**,
**`CRANE BRACKET`**, **`X : HOOK LENGTH`**.

Dimensions above 500 mm, grouped by the view they sit in:

| band | values |
|---|---|
| runway chain (appears at **two** Y bands — two views of the same run) | 4520, 4595, 4725, 5060 … total **42496** |
| span-ish | **17898**, 14840, 14461 |
| heights | 9450, 9320, 9044, 9040, 8875, 8000, 7830, 7800, 6884 |
| members | 5426, 5148, 5060, 4750, **3800**, 2852, 2574, 2000, 1800, 1794 |
| details | 1292, 1018, 912, 750, 718, 658, 650, 600, 562 |
| plate / bolt | 109 values from 5 to 380 |

**Honest limit on this parse.** The `MAIN BEAM` and `CRANE BRACKET` labels sit in a differently
scaled coordinate space from the title block, and a dimension's *value* does not say what it
measures. So these are **candidates, not identifications**:

* **3800** — a lone dimension in its own band, the right order for a **wheel base** (the live BSF
  job carries 3900).
* **17898** — the right order for a **crane span**.
* The 5–380 cluster is bracket plate and bolt detailing — the bracket's own geometry is in there.

**`X : HOOK LENGTH` is the hook approach**, and it is written as a VARIABLE (`X :`), not a number
— the drawing parameterises it rather than fixing it. That is itself the finding: hook approach is
crane-maker data, not a Maimaar constant, which is why the manual does not give one either.

**Not drawn, and should not be guessed:** bracket cantilever and hook approach both need the sheet
LOOKED at, not inferred from a value list. Next step is to rasterise the region around the
`CRANE BRACKET` label and read it.

## Audit round 2 — vocabulary and load rules (5-Sep-2026)

Three catches from re-reading the chapter against what the drawing says:

1. **"CRAB" is not the manual's word.** `trolley` appears **35 times**, `crab` **zero**. The
   manual's own symbol is `HT = Weight of hoist with trolley`. The label read "TROLLEY / CRAB";
   it now reads **TROLLEY**.
2. **Longitudinal load rule added.** ch.8 sec 2.4.4: *"horizontal forces calculated as 10% of the
   maximum wheel loads excluding the vertical impact … assumed to act horizontally at the TOP OF
   THE RAILS"*, and the runway "shall also be designed for crane stop forces."
3. **The manual names no motor.** `motor` appears 4 times and never about a crane — only motor
   ROOMS as a building usage. So the hoist and bridge travel motors are drawn from engineering
   practice, not from the manual, and the data block SAYS SO rather than implying provenance.

### Hook height — the owner's point, and the manual's

Owner: *"Motor with Crane Hook. Mostly Gives the Height of Building from FFL to Crane Hook."*
Manual, *Eave Height* guideline: *"Eave height is a function of … 3. Clearance above Crane beam /
Crane hook height requirement."*

The same rule from both ends: **the hook is the datum the building height is set from.** So the
side view now draws the chain that produces it — girder, hoist motor, rope drop, hook — and says
on the sheet that the hook height is measured FFL to there and sets the eave height. The section
sheet already dimensions it (`HOOK HEIGHT : 6000` on MSPL-26-276).

### Pen ladder — density AND weight identify the part

Owner: *"different thickness and density … show the Clear Difference b/w the Different Components
… For the Crane Motor More Denser."* On a monochrome plot colour carries nothing, so density and
lineweight are the only two variables left. Both are used together:

| part | dot pitch | weight |
|---|---|---|
| girder / main beam | 130 | 0.35 |
| end truck, trolley | 90 | 0.30 |
| wheels | 70 | 0.25 |
| **motor** | **40** | **0.50** |

The motor reads almost solid, which is the point — it is the part that must be picked out at a
glance. Everything stays dotted, because none of it is Maimaar's steel.
