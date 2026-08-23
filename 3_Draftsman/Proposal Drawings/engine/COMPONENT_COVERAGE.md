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
<!-- 25-Jul: the SECTION now draws the Standard Vertical fascia too — `draw-fascia-vertical`
     / `peb-fascia-side` in MAIMAAR_PEB_Section.lsp, on the NSW/FSW eaves of every non-RC
     frame.  Geometry per Manual Ch.10 §10.4 p.240 (600 projection from the steel line,
     200 cage, height = FA_<W>_HT else the roof rise); member names per our own archive
     (FASCIA COLUMN / FASCIA PANEL / SOFFIT PANEL / CAP FLASHING).  It also consumes the
     previously-unused FA_<W>_{HT, SOFFIT, BACKUP, PANEL}.  Curved + parapet types are NOT
     drawn in section yet — they keep the plan band only. -->

| Roof monitor | `peb-draw-monitor` | COMP-MONITOR (4) | `RM_TOGGLE`, `RM_{OVERALL_WIDTH, LENGTH}` |
| Mezzanine | `peb-draw-mezzanine` | COMP-MEZZ (6) | `MZ_TOGGLE`, `MZ_COL_SPACING`, `MZ<n>_{LEN, WID, CH_FFL_BEAM}` |
| Crane | `peb-draw-crane` | COMP-CRANE (1) | `CR_TOGGLE`, `CR<n>_{SPAN, RUN_LENGTH, CAP, TYPE, CMAA_CLASS, GRID_LOC}` |
| Partition | `peb-draw-partition` | COMP-PARTITION (6) | `PT_TOGGLE`, `PT<n>_{TYPE, LENGTH, LOCATION, OPEN}` |
| Stairs | `peb-draw-stairs` | COMP-STAIRS (6) | `ST_TOGGLE`, `ST<n>_{WIDTH, HEIGHT, TYPE, TOP_LANDING}` |

Plus two non-tabular drawers/branches:
- **Roof accessories** (`peb-draw-roof-accessories`, COMP-ROOF-ACC): `RA_SKYLIGHTS`/`RA_TURBOVENTS` counts →
  distributed X-marked squares (up to 15 drawn) + ridge-line vent circles + count labels; `RA_ROOF_OPENING`
  m² → note. (Grid-located accessories still flow through `PL_` placements.)
- **Single Slope** — full-width high→low fall arrows + HIGH/LOW EAVE tags, keyed off `RA_MONO_HIGH`
  (`a.msHighSide`, else FSW). **Flat Roof** — inward-fall arrows to a central dash-dot drain line.

## Coverage gate
`component_coverage_gate.py` compares every key the CRM writes (`drawingData.js` `push('KEY',…)`) against
every key the engine consumes, resolving dynamic reads (`(strcat pre "SPAN")`, per-wall/per-index). Run:
`python component_coverage_gate.py`. Current: **~86% of plan-relevant keys consumed** — the remaining ~14%
are NOT plan geometry (estimation loads, section-only details like partition height / monitor throat / mezz
handrail, proposal header, panel skins) or the one data-blocked field below.

## Already covered (not components)
- **Dimension BASIS** — `peb-basis-suffix`/`peb-basis-offsets` shift dim witness lines to the chosen plane
  (O/O steel / C/C / In-In / sheeting / brickwork) from `BP_LENGTH_REF`/`BP_WIDTH_REF`.
- **Identical count** — `HD_IDENTICAL` → title block "No. Of Identical Bldg.".
- **Frame types** CS/MS/MG/RC/CC/BF/SS/FR + arched; multi-area joining, bracing, doors/windows.

## Closed 6-Jul (RA_* wiring, commit 552e811)
- **Roof accessories** (skylights, turbo-vents, roof opening/cut-out area) — now pushed by `drawingData.ts`
  (`RA_SKYLIGHTS`/`RA_TURBOVENTS`/`RA_ROOF_OPENING` from `a.skylights`/`turboVents`/`roofOpeningArea`) + drawn.
- **Single-Slope directional fall** — `RA_MONO_HIGH` (from `a.msHighSide`, else FSW default) drives the
  high→low arrows + eave tags. The engine is ready for a real `msHighSide` the moment the IF captures it.

## Still data-blocked (1 item — engine ready, but no IF field exists)
- **`ridgeOffset`** — an off-centre ridge line. There is NO `ridgeOffset` field in the IF/area schema and it
  is a rare requirement, so no `push()` was added. To enable: add the field to the IF + area, push
  `BP_RIDGE_OFFSET`, then shift the ridge Y in `peb-ridge-line`/`peb-ridge-callout` by that offset.
