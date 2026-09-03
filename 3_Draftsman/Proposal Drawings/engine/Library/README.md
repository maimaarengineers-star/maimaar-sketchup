# PEB COMPONENT LIBRARY

> "Let's make the Folders for Lisp Coding for Different Components ... we will keep working on
> different terminals with different reference to develop the PEB Components and then once they
> will be refined & developed we will sync with Main PEB Building Lisp Coding and sync along
> with Rules for the placement. It will save a lot of time, we will keep working on even
> different computer and different terminal to speed up of Full Size Automation Works."
> - Nasir, 3-Sep-2026

## Read this first

**[GOLDEN_RULES.md](GOLDEN_RULES.md)** - the binding contract for building a component. Twenty-four
rules, each traceable to a specific failure. Most of those failures are SILENT: the render
"succeeds" and the sheet is blank or wrong. Read it before writing a drawer.

## Why the library exists

The engine grew as seven big sheet files (`MAIMAAR_PEB_Plan.lsp` is 8,000+ lines), so every
component change landed in a file somebody else was also editing. And a component could only be
SEEN by rendering a whole building - about two minutes of AutoCAD to look at one louver.

A component in its own folder is developed on its own terminal, on its own machine, against its
own reference, and rendered on its own in about fifteen seconds. **This development code is
separate from the BSF-synchronised drawing engine**; a finished component is synced in
deliberately, in three small edits (see GOLDEN_RULES, last section).

## Shape

```
Library/<name>/
  MAIMAAR_PEB_<Name>.lsp   drawers - pure geometry, no BSF, no sheet
  reference/               traced sources + view_reference.js (PDF -> DXF + PNG)
  sample/                  render_sample.js + last_render.png
  README.md                what it draws, its numbers, traced vs stylised
```

Start a new component by copying `_template/`. It already obeys the scripting rules (10-13) and
the "look at it" rule (22), which are the ones that waste a day.

## Working in parallel

One component per terminal, one branch per component. A component folder is touched by nobody
else, so two terminals never collide. Stage by path, never `git add -A`.

The only shared files a sync touches are the load list and the dispatch - so a sync is a small,
reviewable diff, not a merge.

## Status

| Component | Folder | State |
|---|---|---|
| Sky lights & wall lights | `skylights_and_wall_lights/` | drawer + section + sample done and verified; seam-lock sky light drawn at the corrected 484 cover but webs still straight and the stiffener tube not drawn; not yet synced into the building drawings |
| Louver | `louver/` | **drawers built and rendering** (`MAIMAAR_PEB_Louver.lsp`). Fixed, adjustable and sand-trap from one drawer, at ANY size - the framed opening, blade count, girt span and free area are all derived, and the manual's own worked example (73.4 m2 -> 210 louvers) reproduces from the formulas. Elevation split by a diagonal break, mesh one side / blades the other, as the reference draws it. Reference = Technical Manual Section 13.8, chosen after scanning the whole job archive (1,873 DWG/DXF + 24,526 PDFs) found NO Maimaar wall-louver detail. `LV_*` keys emitted by `drawingData.ts`; `LOUVER` added to `PEB_LAYERS.csv`. NOT yet synced into the building drawings. |
| Sliding door | `sliding_door/` | **drawers built and rendering** (`MAIMAAR_PEB_SlidingDoor.lsp`). SSD and DSD from one drawer; plan symbol TRACED from the approval sheet Maimaar issues; sample is a DSD 6000 x 6000 - the manual's own worked case - in ~18 s. Reference dug from the whole job archive (29,287 PDFs, 2,297 DWGs, 2016-2026) + the manual's jamb chapter. NOT yet synced into the building drawings. |

> **CLOSED, 3-Sep-2026.** `SLIDING DOOR,30,Continuous,0.50` is now in
> `_PEB_LAYERS_generated.lsp`, so the layer carries its 0.50 pen instead of inheriting
> `LWDEFAULT` 0.25. **Rule 9 fired exactly as predicted**: the regeneration also carried
> `FRAME` 1/0.30 -> 7/0.50 (the frame weight on every sheet Maimaar has ever produced) and
> `COMP-MEZZ-BEAM` 0.50 -> 0.40. **Both reverted in the generated file**; the diff against the
> previous version is now purely additive - `SLIDING DOOR`, plus `LOUVER` which the louver
> terminal had already put in the CSV. The CSV still disagrees with the engine on `FRAME`,
> `COMP-MEZZ-BEAM`, `COMP-MEZZ-JOIST`, `COMP-MEZZ-JOIST-SEC`, `FALL` and `GRID`; that drift is
> reported, not silently fixed, and the next person to regenerate must revert it again until
> somebody decides which side is right.
