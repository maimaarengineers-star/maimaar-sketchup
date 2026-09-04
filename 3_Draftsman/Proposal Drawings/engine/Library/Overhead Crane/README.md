# OVERHEAD CRANE

The crane system — runway beams, brackets, **bridge girder**, trolley and hoist — as it appears on
the **Column Layout Plan** and the **Cross Section**.

**Read `../GOLDEN_RULES.md` first.** Rule 32 governs this component hardest: a proposal drawing is
indicative. A crane is the single most detailed thing a customer will look for on the sheet, and
the temptation to draw an approval-grade bracket detail on an A4 at 1:300 is exactly what that
rule exists to stop.

## What it draws

| drawer | sheet | shows |
|---|---|---|
| *(plan)* `peb-draw-crane` — `MAIMAAR_PEB_Plan.lsp:4540` | PRO-01 Column Layout Plan | running-length arrow, `OVER HEAD CRANE / nn TONES / CMAA CLASS`, and a dashed footprint: 2 runway beams + **bridge girder** + trolley/hook, inside the crane's own grid module |
| *(section)* `peb-crane-sec-*` — `MAIMAAR_PEB_Section.lsp:7831+` | PRO-02 Cross Section | crane beam on its bracket, rail, **bridge end-on**, hoist (`peb-crane-sec-hoist`), hook height and clearance |

Both already exist in the engine. This folder is where the bridge view gets **developed** against
real precedent instead of being extended by eye.

## The data it consumes — the BSF is the single truth

`crane_system` component (up to **three** cranes, CR1–CR3), emitted by
`services/drawingData.ts:676-707` as `CR<n>_*`:

| BSF field | key | emitted as | note |
|---|---|---|---|
| Crane Capacity (MT) | `capacity` | `CRn_CAP` | default 10 |
| No. of Cranes | `qty` | `CRn_QTY_PER_RUNWAY` | per runway |
| Crane Type | `type` | `CRn_TYPE` | `Top Running (TR)` / underhung |
| Crane Span (m) | `span` | `CRn_SPAN` | blank = full width |
| Crane Run Length (m) | `runwayLength` | `CRn_RUN_LENGTH` | blank = full length |
| **Crane Bridge Girder Depth (m)** | `bridgeDepth` | **`CRn_BRIDGE`** | feeds the section's rafter clearance |
| Max Hook Height from FFL (m) | `hookHeight` | `CRn_HOOK_HEIGHT` | |
| Hoist Lift / Lifting Height (m) | `lift` | `CRn_LIFT` | |
| Wheel Base (m) | `wheelBase` | `CRn_WHEEL_BASE` | end-truck centres |
| Max Vertical Wheel Load (kN) | `vertLoad` | `CRn_MAX_VERT_LOAD` | |
| Max Horizontal Wheel Load (kN) | `horizLoad` | `CRn_MAX_HORIZ_LOAD` | |
| CMAA Classification | `serviceClass` | `CRn_CMAA_CLASS` | default C |
| Loading Category | `loadingCategory` | `CRn_CMAA_CAT` | default 3 |
| Manufacturer / Brand | `manufacturer` | `CRn_MANUFACTURER` + `CRn_BY_OTHERS` | "By Others" derives the label |
| Operation Type | `operationType` | `CRn_OP` | Pendant / radio |
| Along Length grids | `gridFrom` / `gridTo` | `CRn_GRID_LOC` | as `"Grid a to b"` |
| Across Width grids | `gridFromW` / `gridToW` | `CRn_GRID_FROM_W` / `_TO_W` | the module the bridge spans |

**A crane runs COLUMN TO COLUMN — one module.** The bridge cannot cross an interior column line,
so a multi-module width range is clamped to adjacent (`Plan.lsp` ~4700).

## Live case to develop against — MSPL-26-276, Sharif Oxygen (inquiry 5401, area 5172)

```
capacity 10 MT · qty 1 · type Top Running (TR) · manufacturer Kone
span 17.69 m · runwayLength 30.48 m · hookHeight 6.0 m · wheelBase 3.9 m
CMAA class C · category 3 · operation Pendant
vertLoad 84 kN · horizLoad 11 kN
grids: length 1-5, width A-B
```

Note `bridgeDepth` and `lift` are **blank** on this job — the section's rafter clearance therefore
has nothing to work from. Whatever the bridge view ends up drawing must degrade honestly when the
depth is not given, not invent one (rule 20: a stylised shape under correct dimensions is honest;
invented dimensions are not).

## Reference

Target precedent, being gathered into `reference/`:

* **MSPL-032 — Maimaar's OWN workshop**, which has the crane. The BOQ survives at
  `PMD/BOQ Library/MSPL-32/` (incl. `MSPL-032_Maimaar Workshop _ BOQ_Quotation Tauqeer Bhai.xlsx`)
  — real crane beam / bracket / rail line items with sizes.
* **Mammut / MBS job drawings** — `D:\Misc\Miscellaneous\Personnel\MBS Data`, and `E:\Maimaar
  Steel Pvt Ltd` (**E: is a temp USB — normally unplugged; it is mounted now**).
* **`D:\Design Manual\mammut design manual.pdf`** — crane chapter: types, capacity/span tables,
  hook approach, clearance to underside of haunch, bracket and runway sizing, rail, end stops.
* A **SketchUp / rendered view** of a crane building, for the three-dimensional read.

DWG references convert with `scratchpad/dwg2dxf.js <in.dwg> <outDir>` → DXF + PDF + PNG via
headless AutoCAD (nothing else on this machine reads DWG).

## The numbers, and where each came from

| | value | source |
|---|---|---|
| | | *to be filled — mark each **traced** or **stylised** (rule 20)* |

## Layers and pens

| element | layer | ACI | pen |
|---|---|---|---|
| plan crane symbol + footprint | `COMP-CRANE` | 1 (red) | created on demand by `peb-comp-layer` |
| section crane members | *(see `peb-crane-sec-*`)* | | |

Layers come from `Rule_Book/PEB_LAYERS.csv` (rule 7); a new one goes in the CSV first (rule 8).
The PDF is **monochrome** — only pen distinguishes anything on the deliverable (rule 4).
`COMP-CRANE` is created at draw time and is **not** in the generated layer table — same gap as
`COMP-DOOR`; worth closing when this component is synced.

## Status

**Bridge TOP and SIDE view built and rendering** (5-Sep-2026).

| drawer | view | what it draws |
|---|---|---|
| `peb-crn-bridge-elev` | SIDE — along the girder | outline, top and bottom flanges, end diaphragms + intermediate stiffeners spaced BY DEPTH |
| `peb-crn-bridge-plan` | TOP — from above | girder between the runways, end truck at each end |
| `peb-crn-dash` | — | the pen: CRANEBRG, a TRUE dot (dash of length zero on a 300 pitch) |
| `C:PEB-CRANE-SAMPLE` | both, at size | the development sheet — `sample/render_sample.js` draws and rasters it in seconds |

`sample/last_render.png` is the current state; `sample/CRANE_BRIDGE_TYPICAL.dwg` the drawing.

**Synced to the engine: the SIDE view only.** `MAIMAAR_PEB_Section.lsp` dispatches to
`peb-crn-bridge-elev` under a `boundp` guard, falling back to the plain box it drew before. The
TOP view is written and rendering in the sample but is **not yet wired into the Column Layout
Plan** — the plan still draws its own two dotted girder lines (`peb-crane-dot-line`,
`Plan.lsp` ~4767). That is the remaining sync.

### Two traps this component already hit

* **A component that is not in the load list draws nothing and says nothing.** `drawingData.ts`
  had a hard-coded list of four library files; this was the fifth, the `boundp` guard was simply
  false, and the sheet kept drawing its old box with no error. Both load paths now DISCOVER the
  folder. Adding a component is creating its folder.
* **Never name a local after a function.** `peb-crn-sample-dim` took `txt` as its label
  parameter, shadowing the `txt` FUNCTION — the call threw and killed the rest of the sample
  silently: the side view drew, the span dimension and the entire top view did not.
