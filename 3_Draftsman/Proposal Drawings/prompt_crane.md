# HANDOFF PROMPT — CRANE (unify BS → Section frame + Plan)

TASK: Make the CRANE a single BS-driven feature that draws consistently in BOTH the cross-section
(frame) engine and the column-plan engine from ONE BS crane block, so section and plan register the
same crane on the same column lines. Work in a git worktree off `main` (owner is concurrently editing
MAIMAAR_PEB_Section.lsp — coordinate, do not blind-commit the shared file).

## SINGLE SOURCE OF TRUTH (BS → engine)
- BS input fields: `D:\maimaar-os\2_Sales CRM\public\modules\sales\components.js`
  `COMPONENT_SCHEMAS.crane_system` (lines ~396-439): serviceClass (CMAA A-F), loadingCategory (1-4),
  manufacturer, capacity, qty, span, runwayLength, gridFrom, gridTo, gridFromW (A-N), gridToW,
  type (Top Running TR / Under Hung UH / Monorail / Semi / Full Gantry / Jib), hookHeight, wheelBase,
  operationType, vertLoad, horizLoad.
- Serializer: `D:\maimaar-os\2_Sales CRM\services\drawingData.ts`, CR_* block (lines ~448-477).
  Emits CR_TOGGLE, CRn_TOGGLE, CRn_CMAA_CLASS, CRn_CMAA_CAT, CRn_MANUFACTURER, CRn_CAP,
  CRn_QTY_PER_RUNWAY, CRn_TYPE, CRn_OP, CRn_SPAN(mm), CRn_RUN_LENGTH(mm), CRn_GRID_LOC ("Grid a to b"),
  CRn_GRID_FROM_W, CRn_GRID_TO_W, CRn_HOOK_HEIGHT(mm), CRn_WHEEL_BASE(mm), CRn_MAX_VERT_LOAD,
  CRn_MAX_HORIZ_LOAD, CRn_LIFT(hardcoded '0'), CRn_BRIDGE(hardcoded '0'). n = 1..(qty). Toggle = "Yes"/"No".

## ** CRITICAL BUG — FIX FIRST **
Section MAIMAAR_PEB_Section.lsp v3→legacy passthrough (foreach at lines ~650-655) forwards only PL*,
BR*, RM* keys — it DROPS all CR* keys. So CR_TOGGLE is always "" and the crane NEVER draws in the
section. Add CR* (and CRn_*) to that `wcmatch` passthrough so the crane block reaches the section engine.

## SECTION engine — MAIMAAR_PEB_Section.lsp
- Drawer `peb-draw-crane-section` (line ~6939); called ~7522 (unconditional; internal guard CR_TOGGLE=
  "YES" at ~6945; loops CR1_..CR3_ each gated CRn_TOGGLE="YES"). Reads CRn_CAP, CRn_CMAA_CLASS,
  CRn_HOOK_HEIGHT, CRn_GRID_FROM_W, CRn_GRID_TO_W, CRn_TYPE.
- Across-width position: rail X lands on the column inner flanges from `cols` (`compute-section-layout`
  ~1833) selected by CRn_GRID_FROM_W/TO_W (grid letters → col index, ~6987-6993). This is the SAME
  grid-letter key the plan uses — keep it the shared across-width anchor.
- **STANDING RULE "crane bridge never overlaps the rafters":** Top-Running clamps bridgeTop under the
  roof (capY = clearHt - 0.60u); Under-Hung hangs from `peb-crane-raf-y` (~6928, a straight-line rafter
  approx). Re-anchor the clearance to the TRUE rafter underside `cigar-rafter-underside-y` (~1991) so
  it's correct on off-centre ridge / tapered rafters; reduce hook headroom if needed so the bridge top
  never crosses the rafter line.

## PLAN engine — MAIMAAR_PEB_Plan.lsp
- Drawer `peb-draw-crane` (line ~3019); called ~2098, guarded CR_TOGGLE="YES", loops n=1..3
  CRn_TOGGLE="YES". Reads CRn_SPAN, CRn_CAP, CRn_TYPE, CRn_CMAA_CLASS, CRn_GRID_LOC, CRn_RUN_LENGTH,
  CRn_BY_OTHERS, CRn_GRID_FROM_W, CRn_GRID_TO_W.
- Along-length runway X from CRn_GRID_LOC into bay stations (`peb-mzfp-bays` / NUMBAYS+BAYn); across-width
  runway Y from `peb-comp-width-pts` (~2107) + grid letters CRn_GRID_FROM_W/TO_W. Draws runway beams,
  end carriages, bridge, hoist on COMP-CRANE-FP + labels on COMP-CRANE.

## UNIFICATION RULES (both engines read the ONE CRn_ block)
- Shared keys that MUST drive both: CRn_CAP, CRn_CMAA_CLASS, CRn_TYPE, and especially CRn_GRID_FROM_W /
  CRn_GRID_TO_W — the across-width grid letters are what make the section's rail X and the plan's runway
  Y land on the SAME column lines. Confirm both resolve the letters through the same grid-letter index
  and offset.
- Section-only (elevation): CRn_HOOK_HEIGHT, CRn_LIFT, CRn_BRIDGE, CRn_WHEEL_BASE, CRn_MAX_*_LOAD.
  Plan-only (length): CRn_SPAN, CRn_RUN_LENGTH, CRn_GRID_LOC. That's the correct split — but they must
  come from the ONE crane component, not separate inputs.

## GAPS TO CLOSE
1. CR* passthrough bug (above) — without it the whole section crane is dead.
2. CRn_BRIDGE and CRn_LIFT are hardcoded '0'. Bridge girder depth (and thus the rafter-clearance check)
   and hoist lift are real inputs — wire them from BS (add fields if missing) instead of '0'.
3. Plan reads CRn_BY_OTHERS but the serializer never emits it — either emit CRn_BY_OTHERS (derive from
   manufacturer == "By Others") or change the plan to read CRn_MANUFACTURER.
4. Fallback mismatches to align: CRn_CMAA_CAT default '2' vs BS loadingCategory def '3'; CRn_CAP default
   '5' vs BS capacity def '10'; CRn_OP default 'Pendant (P)' vs BS bare 'Pendant' (make the engine
   accept both spellings).

## VERIFICATION
Build one BS test .txt with CR_TOGGLE=Yes, CR1 = Top-Running, CRn_GRID_FROM_W/TO_W across an interior
module, a real CRn_HOOK_HEIGHT, plus an off-centre BP_RIDGE_OFFSET. Render the Section AND the Plan to
fresh `_verify` names (PowerShell `Start-Process acad /nologo /b <scr>`, NEVER git-bash), rasterize with
PyMuPDF, and confirm: the crane now APPEARS in the section (passthrough fixed); the bridge top sits clear
below the rafter underside at the off-centre ridge; the section rail X and the plan runway Y fall on the
SAME across-width column lines (grid letters). Then repeat for Under-Hung. Show the owner both PNGs before
committing.
