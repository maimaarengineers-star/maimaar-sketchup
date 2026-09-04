# Printing the merged PDF from inside AutoCAD

Owner, 27-Aug-2026: *"i have a Autocad Drawings & there is option or button on Autocad File that
generate the pdf"* — i.e. **without going back to the BSF page**.

Open the drawing, press the button, get one merged PDF of every sheet. Nothing is regenerated from
the BSF, so **whatever you changed by hand is exactly what prints**.

---

## 1. The command — already set up, nothing to do

`acaddoc.lsp` was installed at:

```
C:\Users\nasir\AppData\Roaming\Autodesk\AutoCAD 2021\R24.0\enu\Support\acaddoc.lsp
```

AutoCAD reads that folder automatically for **every drawing you open**, so the command loads itself.
No APPLOAD, no Startup Suite, nothing to remember.

**Restart AutoCAD once** for it to take effect. You should see this on the command line:

```
MAIMAAR PEB PDF loaded.  Commands:  MPDF / MSPLPDF  (build/append)   MSPLPDFNEW  (reset)
```

Then just type **`MPDF`** and press Enter. The PDF is written **next to the drawing** as
`MSPL-Proposal-Drawings.pdf` and opens by itself.

---

## 2. Making it an actual button — about one minute, once

### The quickest: Quick Access Toolbar (the small bar at the very top, always visible)

1. Type **`CUI`** and press Enter.
2. Bottom-left, in the **Command List** panel, click the **star icon** (*Create a new command*).
3. On the right, in **Properties**, fill in:

   | Field | Value |
   |---|---|
   | **Name** | `Merged PDF` |
   | **Macro** | `^C^CMPDF` |
   | **Description** | `Print every sheet of this drawing to one merged PDF` |

   > The `^C^C` at the front is not optional — it cancels whatever command is half-finished before
   > yours starts. Without it the button does nothing whenever you happen to be mid-command.

4. Top-left, expand **Quick Access Toolbars → Quick Access Toolbar 1**.
5. **Drag** `Merged PDF` from the Command List up onto it.
6. Click **Apply**, then **OK**.

The button is now at the top of the window. Click it — that is the whole job.

### If you would rather have it on the ribbon

Same steps 1–3, then:

- **Ribbon → Panels →** right-click → **New Panel**, name it `Maimaar`.
- Drag `Merged PDF` into the new panel's **Row 1**.
- **Ribbon → Tabs →** open the tab you want it on (e.g. *Output*), right-click → **New Panel**, and
  pick `Maimaar` from the list.
- **Apply → OK**.

### Want an icon on it

In step 3, use **Small image** / **Large image** in the Properties panel and pick any `.bmp`/`.png`.
Skip it if you do not care — a text button works the same.

---

## 3. Several options in one PDF

AutoCAD will not let one command jump between open drawings, so the set is built up on disk instead:

1. **`MSPLPDFNEW`** — once, to start a fresh set
2. **`MPDF`** in Option 01's drawing → PDF has Option 01
3. **`MPDF`** in Option 02's drawing → PDF now has **both**

Each run adds the current drawing's sheets and re-merges the whole set.

---

## 4. What it prints, and what to watch

- **Sheet tabs are the sheets.** Sheets are plotted in **tab order** — the order the tabs sit along
  the bottom of the AutoCAD window — not alphabetically. Alphabetical would put *Section* before
  *Plan* and hand the customer a shuffled document that looks deliberate. **Model is skipped**: it
  is the workspace, not a page.
- **Older drawings still work.** Drawings made before the A4 layout system have their sheets tiled
  in model space inside rectangles on layer `BORDER`; those are detected and plotted A1 as before.
  That fallback exists for the archive — the old jobs are exactly the ones you re-open years later.
- **A sheet that fails to plot is skipped, the rest still merge.** A partial set you can look at
  beats an error you cannot act on. Check the page count if something looks short.
- **It needs Node.js** (already installed — the CRM runs on it) for the merge step. If the merge
  fails, the individual pages are left in `%TEMP%\mspl_pdf` and the command tells you so.
- **It never modifies the drawing.** It also puts you back on the tab you were working on.

---

## 5. The same thing from the BSF page

There is now a **🔄 Re-print PDF from AutoCAD** button on the Building Specifications Form. It does
the same job server-side: finds the DWG you edited (newest save wins, across the proposal folder and
the work folders) and re-plots it without regenerating anything.

Use whichever is in front of you. **In AutoCAD** is better when the drawing is already open —
which is the case the owner asked about.
