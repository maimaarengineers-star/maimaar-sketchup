# HANDOFF PROMPT — ROOF MONITOR (unify BS → Section frame + Plan)

TASK: Make the ROOF MONITOR a single BS-driven feature that draws consistently in BOTH the
cross-section (frame) engine and the column-plan engine, so one BS entry can never produce a
section and a plan that disagree. Work in a git worktree off `main` (the owner is concurrently
editing MAIMAAR_PEB_Section.lsp — do NOT blind-commit the shared file; coordinate).

## SINGLE SOURCE OF TRUTH (BS → engine)
- BS input fields: `D:\maimaar-os\2_Sales CRM\public\modules\sales\components.js`
  `COMPONENT_SCHEMAS.roof_monitor` (lines ~371-391): throat, constructionType (Hot-Rolled IPEa /
  Cold-Formed C20G / Built-up BU), baySpacing, gridFrom, gridTo, length, height (auto = throat/2,
  readonly), overallWidth, eaveCondition (Curved Eave Panel / Eave Trim), openWall, birdMesh,
  insulation.
- Serializer: `D:\maimaar-os\2_Sales CRM\services\drawingData.ts`, RM_* block (lines ~433-446).
  Emits RM_TOGGLE, RM_THROAT_WIDTH(mm), RM_LENGTH(mm), RM_GRID_FROM, RM_GRID_TO, RM_HEIGHT(mm),
  RM_OVERALL_WIDTH(mm), RM_WIDTH(hardcoded '0' — dead), RM_EAVE_TYPE, RM_OPEN_WALL_HT, RM_BIRD_MESH,
  RM_INSULATION. Toggle/bool contract = literal "Yes"/"No"; every KEY=value line ends up in the
  PEB_Data_B<n>_A<m>.txt both engines load.

## SECTION engine — MAIMAAR_PEB_Section.lsp
- Drawer `peb-draw-roof-monitor` (line ~6728); helpers `rm-*` (~6657-6725); called at ~7524-7527,
  guarded by (a ridge exists) AND RM_TOGGLE="YES". Reads RM_THROAT_WIDTH (fallback RM_OVERALL_WIDTH),
  RM_OVERALL_WIDTH, RM_HEIGHT (fallback RM_OPEN_WALL_HT), RM_EAVE_TYPE, RM_BIRD_MESH.
- **Anchor FIX (frame sync):** it currently seats the monitor legs on its OWN straight-slope math from
  the passed ridgeX/H/rise/slopeD. Re-anchor the leg seats to the TRUE rafter underside via
  `cigar-rafter-underside-y` (line ~1991) and the ridge X via `peb-ridge-x` (~1829), so on an
  off-centre ridge (BP_RIDGE_OFFSET) or tapered rafter the monitor sits exactly on the frame.

## PLAN engine — MAIMAAR_PEB_Plan.lsp
- Drawer `peb-draw-monitor` (line ~2323); called at ~2096, guarded RM_TOGGLE="YES". Reads
  RM_OVERALL_WIDTH, RM_LENGTH, RM_GRID_FROM/RM_GRID_TO. Length span from `peb-mzfp-bays` (~6277).
- **Anchor FIX (parity):** it hardcodes the ridge at wid/2 (line ~2334). Change to `peb-ridge-y(data wid)`
  (line ~568) so it honors BP_RIDGE_OFFSET and lands on the SAME station the section uses.

## UNIFICATION RULES (both engines read the ONE RM_ block)
- Cross-section width comes from RM_THROAT_WIDTH (vent opening) + RM_OVERALL_WIDTH (eave-to-eave);
  the plan band width MUST use the SAME RM_OVERALL_WIDTH. Along-ridge length (RM_LENGTH + grid) is
  plan-only; the section is a cut, so it has no length — that's expected, not a mismatch.
- Ridge station: section `peb-ridge-x` and plan `peb-ridge-y` must resolve to the same X/Y from the
  same BP_RIDGE_OFFSET, so the monitor registers across both sheets.
- Keep ONE source of the monitor geometry. If the standalone `MAIMAAR_PEB_Monitor.lsp` still exists,
  either fold it fully into the Section engine (the migrated `rm-*` copy) or have both load one shared
  file — do not leave two diverging copies.

## GAPS TO CLOSE
1. `constructionType` (Hot-Rolled / Cold-Formed / Built-up) is NOT serialized — add an RM_CONSTR (or
   RM_SECTION_TYPE) key in drawingData.ts and let the section pick the member profile from it.
2. `baySpacing` is NOT serialized — add RM_BAY_SPACING so the plan's monitor length grid can use the
   monitor's own bay spacing instead of only the area bays.
3. RM_WIDTH is hardcoded '0' (dead) — either wire it to a real field or remove it.
4. RM_HEIGHT ships '0' if the form leaves height blank — ensure the form's "auto = throat/2" actually
   populates height before serialize, or derive throat/2 in the serializer as a fallback.

## VERIFICATION
Build one BS test .txt with RM_TOGGLE=Yes, an off-centre BP_RIDGE_OFFSET, a partial RM_GRID_FROM/TO,
curved eave, bird mesh on. Render the Section AND the Plan to fresh `_verify` names (PowerShell
`Start-Process acad /nologo /b <scr>`, NEVER git-bash), rasterize with PyMuPDF, and confirm: the monitor
sits ON the rafter at the off-centre ridge in the section; the plan opening band centres on the SAME ridge
station; overall width matches on both; the partial length shows the length dim. Show the owner both PNGs
before committing.
