# Column Layout Plan — Component Coverage (100% IF accommodation)

The Column Layout Plan (`MAIMAAR_PEB_Plan.lsp`) is the **master drawing** — Sections, Elevations, Roof Plan
and Foundation Plan all derive from it. Goal: it must be **100% accommodative to the full Inquiry Form (IF)**
— every field/option the estimator can enter maps to something drawn.

## Component overlay pass (6-Jul-2026)
A new sub-system draws overlaid IF **components** on top of the frame/columns. It runs inside `C:PEB-PLAN`
after `peb-draw-placements` (ungated by multi-area mode, so components **ride into the multi-area
render-then-merge** automatically — verified: canopy + monitor from Area 01 appear in the merged 2-area plan).

- **`peb-draw-components (data len wid)`** — dispatch; one `vl-catch-all-apply` line per drawer.
- Shared helpers: `peb-comp-layer` (batch-safe entmake layer), `peb-comp-poly` (closed outline),
  `peb-comp-fall` (slope/FALL arrow, strip-scaled). **Text rule:** `txt-bold` re-applies `*PEB-TEXT-SCALE*`,
  so component text height is `(/ desired *PEB-TEXT-SCALE*)`; all geometry is raw mm.
- Owner rule: **minimal footprint** (outer outline + fall + coverage dims + label); **columns only where the
  component really has them** (mezzanine stub grid, crane separate-column row >20t/>15m).

### Drawers (8) — each on its own layer
| Component | Fn | Layer | IF keys (per wall W = NSW/FSW/LEW/REW) |
|---|---|---|---|
| Canopy | `peb-draw-canopy` | COMP-CANOPY (3) | `CN_TOGGLE`, `CN_<W>_{WIDTH=proj, LEN, EAVE...}` |
| Roof extension | `peb-draw-roof-ext` | COMP-ROOF-EXT (5) | `RX_TOGGLE`, `RX_<W>_{WIDTH, LEN, EAVE}` |
| Fascia / parapet | `peb-draw-fascia` | COMP-FASCIA (2) | `FA_TOGGLE`, `FA_<W>_{PROJ, LEN, TYPE}` |
| Roof monitor | `peb-draw-monitor` | COMP-MONITOR (4) | `RM_TOGGLE`, `RM_{OVERALL_WIDTH, LENGTH}` |
| Mezzanine | `peb-draw-mezzanine` | COMP-MEZZ (6) | `MZ_TOGGLE`, `MZ_COL_SPACING`, `MZ<n>_{LEN, WID, CH_FFL_BEAM}` |
| Crane | `peb-draw-crane` | COMP-CRANE (1) | `CR_TOGGLE`, `CR<n>_{SPAN, RUN_LENGTH, CAP, TYPE, CMAA_CLASS, GRID_LOC}` |
| Partition | `peb-draw-partition` | COMP-PARTITION (6) | `PT_TOGGLE`, `PT<n>_{TYPE, LENGTH, LOCATION, OPEN}` |
| Stairs | `peb-draw-stairs` | COMP-STAIRS (6) | `ST_TOGGLE`, `ST<n>_{WIDTH, HEIGHT, TYPE, TOP_LANDING}` |

Also: **Flat Roof** now draws inward-fall arrows to a central dash-dot drain line (was text only).

## Coverage gate
`component_coverage_gate.py` compares every key the CRM writes (`drawingData.js` `push('KEY',…)`) against
every key the engine consumes, resolving dynamic reads (`(strcat pre "SPAN")`, per-wall/per-index). Run:
`python component_coverage_gate.py`. Current: **~76% of plan-relevant keys consumed** — the remainder are
either NOT plan geometry (estimation loads, section details, proposal header, panel skins) or **data-blocked**.

## Already covered (not components)
- **Dimension BASIS** — `peb-basis-suffix`/`peb-basis-offsets` shift dim witness lines to the chosen plane
  (O/O steel / C/C / In-In / sheeting / brickwork) from `BP_LENGTH_REF`/`BP_WIDTH_REF`.
- **Identical count** — `HD_IDENTICAL` → title block "No. Of Identical Bldg.".
- **Frame types** CS/MS/MG/RC/CC/BF/SS/FR + arched; multi-area joining, bracing, doors/windows.

## Data-blocked (engine ready; CRM must serialize these to the v3 data file first)
`drawingData.js` does not yet `push()` these, so the plan cannot consume them regardless:
- **`msHighSide`** — Single-Slope directional fall (high→low eave tags). Engine draws a default arrow today.
- **`ridgeOffset`** — off-centre ridge line.
- **Roof accessories** — skylights, turbo-vents, roof opening area, cut-outs (framed-opening / notch marks).

To close TRUE 100%: add the corresponding `push()` calls in `drawingData.js`, then wire the small readers
(SS: high-side arrow direction + eave tags; ridge-offset: shift ridge Y; accessories: small roof marks).
