# Proposal Drawings — 2D AutoCAD Engine (Draftsman Module)

Generates Maimaar PEB **Proposal Drawings** (Cross Section + Column Layout Plan, with the
Mammut-style right-edge title block) from the web Inquiry Form. The IF is the single source
of truth — `drawingData.ts` (in the Sales CRM app) serialises an inquiry into a flat
`PEB_Data_B<n>_A<m>.txt`, and the AutoLISP engine here draws from it.

## Folder layout

| Folder | Contents |
|---|---|
| `engine/` | **The AutoLISP engine** — `MAIMAAR_PEB_Section.lsp`, `MAIMAAR_PEB_Plan.lsp`, `MAIMAAR_PEB_Standard.lsp`, `MAIMAAR_PEB_Cover.lsp`. Edit these. |
| `assets/` | Branding assets. `MAIMAAR_LOGO_REAL.dwg` is the production logo (`-INSERT`ed by the title block); `MAIMAAR_LOGO.dwg` is the older block. `assets/_build/` holds the logo-build scripts. |
| `sample_data/` | Sample `PEB_Data_*.txt` files for testing. |
| `output/<proposal-no>/` | Generated drawings (`.dxf`) + the `PEB_Data_*.txt` they were built from + `PREVIEW_*.png`. |
| `legacy_input_tooling/` | The OLD standalone Excel/Python input (`Maimaar_PEB_Input.xlsm/.xlsx/.py`, `build_xlsm.py`, `Rebuild_Workbook.bat`) — **superseded by the web IF**, kept for reference. |
| `docs/` | LISP visual overviews + the old proposal template doc. |
| `reference/` | PEB reference library (manuals, past proposals/drawings). Not git-tracked (see its README). |
| `vba/` | VBA helpers. |

## How to generate drawings

**Production:** Draftsman portal → 📐 **Drawing Data** on an inquiry → unzip → run the bundled
`_run.scr` in AutoCAD (`SCRIPT` command). The title block links every field to the IF
(project, customer, date, design loads, **design code**) and inserts the real Maimaar logo.

**Manual / dev:** load `engine/MAIMAAR_PEB_Section.lsp` + `engine/MAIMAAR_PEB_Plan.lsp`, then
`(peb-section-from-file "…PEB_Data….txt")` / `(peb-plan-from-file "…")`.

## ⚠️ Headless render gotchas (`acad /b`) — READ BEFORE BATCH RENDERING

1. **The `.scr` file path AND the `_DXFOUT` output path must be SPACE-FREE.** This folder name
   (`Proposal Drawings`) contains a space, which silently breaks `acad /b`: it splits the path
   and AutoCAD sits idle at the `Command:` prompt. Put the script + DXF output in a space-free
   scratch dir (e.g. `D:\maimaar-os\_render\`) and copy results back here afterwards.
   The `(load "…")` and `(peb-…-from-file "…")` paths INSIDE the script CAN have spaces
   (they are quoted LISP strings).
2. **Use Windows drive paths** in the script: `D:/maimaar-os/…` (forward slashes are fine).
   A Unix-style `/d/maimaar-os/…` makes `(load)` fail silently → `no function definition`.
3. **Kill stray `acad.exe` first** and clear the Drawing-Recovery state; a force-killed acad
   triggers a recovery dialog that blocks the next script. Launch via
   `Start-Process acad.exe -ArgumentList '/nologo','/b','D:\…\x.scr' -Wait`.
4. `accoreconsole` is NOT usable — the engine relies on `vlax-get-acad-object` (COM), which
   accoreconsole stalls on. Use full `acad /b`.
5. Render a DXF to PNG with ezdxf + matplotlib using **`facecolor="black"`** — title text is
   ACI color-7 (black/white), invisible on a white preview but correct in AutoCAD.

## Engine notes
- One building = one drawing.
- The logo path is hardcoded in `engine/*.lsp` as
  `…/Proposal Drawings/assets/MAIMAAR_LOGO_REAL.dwg` — update both files if assets move.
