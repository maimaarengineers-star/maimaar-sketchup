# MAIMAAR PEB — THE FOUNDATION
### The single, universal base every proposal drawing is built on (strict + dynamic, from the IF)

This is the **strong basic foundation**. Lock it once → every sheet type (Plan,
Section, Elevation, Framing, Cover) inherits it, stays consistent, and improves
together. It unifies the three things that are really one thing:
**the NAME of each line/label · its AutoCAD native object · its fixed style.**

It exists in two synchronized forms:
- **Human:** this file + the visual `reference/03_proposal_drawings/LINE_DATABASE/`.
- **Code:** `engine/MAIMAAR_PEB_Standard.lsp` — the layer table (§1) **and** the
  primitive draw library (§7).

---

## The 3 layers of the foundation

1. **STANDARD (the DNA)** — `*PEB-LAYERS*` in `Standard.lsp`. One row per element
   fixing layer name + colour + linetype + lineweight.
2. **PRIMITIVE LIBRARY (the toolkit)** — the `peb-*` draw helpers in `Standard.lsp` §7.
   One function per AutoCAD native object; all draw **BYLAYER** so the STANDARD governs.
3. **SHEET ENGINES (the products)** — Plan/Section/Elevation/Framing/Cover. They
   **only** call primitives; they decide *what* and *where*, never the raw style.

> **THE STRICT RULE:** No sheet engine ever calls raw `entmake` or `command "LINE"`.
> Everything goes through a `peb-*` primitive. That one rule = consistency forever.

---

## MASTER ROW-SET — every line & label

| Element | Layer NAME | AutoCAD object (DXF / AcDb) | Colour | Linetype | LW mm | Primitive | Sheets |
|---|---|---|---|---|---|---|---|
| Building outline | `SHEETING` | LWPOLYLINE / AcDbPolyline | blue 5 | Continuous | 0.09 | `peb-rect` | Plan, Elev |
| Sheet border | `BORDER` | LWPOLYLINE | white 7 | Continuous | 0.50 | `peb-rect` | all |
| Grid axis line | `GRID-LINES` | LINE / AcDbLine | green 3 | CENTER | 0.09 | `peb-line` | Plan, Sec, Elev, Fram |
| Grid bubble (pentagon) | `GRID` | LWPOLYLINE | green 3 | Continuous | 0.13 | `peb-pent` / `peb-bubble` | all |
| Grid number / letter | `GRID-TEXT` | TEXT / AcDbText | red 1 | Continuous | 0.09 | `peb-text` (via `peb-bubble`) | all |
| Column (I-section) | `COLUMNS` | LWPOLYLINE + SOLID | red 1 | Continuous | **0.50** | `peb-poly`+`peb-solid` | Plan, Sec |
| Column centre-line | `COL-CENTER` | LINE | red 1 | CENTER | 0.09 | `peb-line` | Plan |
| Base plate | `PLATES` | LWPOLYLINE | white 7 | Continuous | 0.35 | `peb-rect` | Plan(AB) |
| Anchor bolt | `BOLTS` | CIRCLE / AcDbCircle | white 7 | Continuous | 0.09 | `peb-circle` | Plan(AB) |
| Cross-bracing X | `CROSS` | LINE | cyan 4 | DASHED | 0.18 | `peb-line` | Plan |
| Ridge line | `RIDGE` | LINE | blue 5 | HIDDEN | 0.18 | `peb-line` | Plan, Sec |
| Rafter centre-line | `RAFTER` | LINE | grey 8 | HIDDEN | 0.09 | `peb-line` | Plan |
| Slope / FALL arrow | `ARROWS` | SOLID + TEXT | green 3 | Continuous | 0.13 | `peb-solid`+`peb-text` | Plan, Roof |
| Dimension chain | `DIMENSIONS` | DIMENSION / AcDbRotatedDimension | magenta* | Continuous | 0.13 | `peb-dim` (engine) | all |
| Dim tick / arrowhead | `ARROWS` | (in the DIMENSION style) | — | — | 0.13 | — | all |
| Wall / note text | `TEXT` | TEXT / MTEXT | white 7 | Continuous | 0.13 | `peb-text` / `peb-mtext` | all |
| Leader callout | `TEXT` | MULTILEADER / AcDbMLeader | white 7 | Continuous | 0.13 | `peb-leader` | all |
| Area tag | `AREA-MARK` | LWPOLYLINE + TEXT | grey 8 | Continuous | 0.18 | `peb-rect`+`peb-text` | Plan |
| BRACED BAY label | `TEXT`(SECONDARY) | TEXT | magenta 6 | Continuous | 0.13 | `peb-text` | Plan |
| Door / window / opening | `OPEN` | LWPOLYLINE + ARC | magenta 6 | Continuous | 0.18 | `peb-poly`+`peb-arc` | Plan, Elev |
| Concrete / RCC poché | `HATCHR` | HATCH / AcDbHatch | orange 32 | Continuous | 0.30 | (hatch dispatch) | Sec |
| Logo / symbol | (current) | INSERT / AcDbBlockReference | — | — | — | `peb-insert` | Cover, TB |
| Title-block body | `TITLEBLOCK` | LINE + TEXT | red 1 | Continuous | 0.35 | `peb-line`+`peb-text` | all |

\* Dimensions: the real Mammut chain reads **magenta**; our `DIMENSIONS` layer is
currently green 3 — reconcile when wiring `peb-dim` (set the dim layer/colour here).

---

## How a sheet engine uses the foundation (the pattern)

```lisp
(peb-std-setup)                                   ; lay down layers + styles + load primitives
;; building outline
(peb-rect 0 0 len wid "SHEETING")
;; grid line + bubble (dynamic from IF)
(peb-line gx 0 gx (- gtop 600) "GRID-LINES")
(peb-bubble gx gtop 600 "1" "D")                  ; pentagon + red number, on GRID/GRID-TEXT
;; column (red, heavy, BYLAYER)
(peb-rect (- cx 180)(- cy 180)(+ cx 180)(+ cy 180) "COLUMNS")
;; cross-bracing (single full X)
(peb-line x0 0 x1 wid "CROSS") (peb-line x0 wid x1 0 "CROSS")
;; leader label
(peb-leader tipx tipy elbx elby "RIDGE LINE" "TEXT")
```
The engine sets only geometry + which layer. Colour/linetype/lineweight come from
the STANDARD. Change `("COLUMNS" 1 "Continuous" 0.50)` once → every column on every
sheet updates.

## Primitive library reference (`Standard.lsp` §7)
`peb-line` · `peb-poly` · `peb-rect` · `peb-circle` · `peb-arc` · `peb-solid` ·
`peb-text` / `peb-text-j` · `peb-mtext` · `peb-insert` · `peb-pent` · `peb-bubble` ·
`peb-leader` · `peb-d2r`. (Dimensions = `peb-dim`, to be wired from the engine's
native-dim block onto the `DIMENSIONS` layer.)

## Validation
Generate the Plan for the **Zealcon IF fixture** and overlay on the real parent
`LINE_DATABASE/00_MASTER_real_zealcon_plan.png`. When ours lands on top, the
foundation is proven — measured, not eyeballed.
