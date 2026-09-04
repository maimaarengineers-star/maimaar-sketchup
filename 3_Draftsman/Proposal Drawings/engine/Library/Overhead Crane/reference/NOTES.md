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
