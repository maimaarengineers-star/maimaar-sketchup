'use strict';
// ── SAMPLE HARNESS — OVERHEAD CRANE BRIDGE ──────────────────────────────────────────────────
//
// DEVELOPMENT CODE, SEPARATE FROM THE BSF-SYNCHRONISED DRAWING ENGINE (owner 3-Sep-2026:
// "this develop coding will be separate from Synchronized Coding of BSF Based generated
// Drawings"). Nothing here is loaded by the proposal set.
//
// FOUR PAGES, ONE DRAWING EACH (owner 5-Sep-2026: "Better to Expand the Drawings on 4 Pages so
// that you may Review It Closely To Develop the Right Product" / "Expand All Drawings During
// Development so that you can do the Proper Audit").
//
//   1  TOP VIEW          2  SIDE VIEW + HOIST DETAIL
//   3  CRANE BEAM        4  END CARRIAGE + DATA
//
// The LISP records the four plot windows in *PEB-CRN-PAGES*; this plots one A1 page per window
// and merges them into a single PDF. Each drawing is therefore fitted to its OWN page instead of
// sharing a scale set by the 21 m span — which is the whole difference between a detail that is
// present and one that can be audited.
//
//   node render_sample.js
// Out: C:/maimaar_render/crn_<stamp>/CRANE_BRIDGE.pdf (4 pages) + per-page PNGs + .dwg
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ENGINE = 'D:/maimaar-os/3_Draftsman/Proposal Drawings/engine';
const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';
const PDFLIB = 'D:/maimaar-os/2_Sales CRM/node_modules/pdf-lib';

const WORK = 'C:/maimaar_render/crn_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// ESCAPING — the thing that bites. A .scr line takes a RAW single backslash and must be QUOTED
// when the path holds a space; a LISP string literal needs it DOUBLED. Mixing the two leaves an
// open prompt that silently eats the rest of the script.
const q = (s) => s.split('/').join('\\\\');
const dwg = WORK + '/CRANE_BRIDGE.dwg';
const pdf = WORK + '/CRANE_BRIDGE.pdf';
const NPAGE = 4;
const pagePdf = (i) => WORK + '/page' + i + '.pdf';
const pagePng = (i) => WORK + '/page' + i + '.png';

const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)',
  '(load "' + q(ENGINE + '/MAIMAAR_PEB_Standard.lsp') + '")',
  '(load "' + q(ENGINE + '/MAIMAAR_PEB_Plan.lsp') + '")',
  '(load "' + q(ENGINE + '/Library/Overhead Crane/MAIMAAR_PEB_Crane.lsp') + '")',
  '(C:PEB-CRANE-SAMPLE)',
  '(vl-load-com)',
  // a 2-element safearray is what SetWindowToPlot wants; vlax-3d-point is the wrong shape
  '(defun mkpt (x y / sa)',
  '  (setq sa (vlax-make-safearray vlax-vbDouble (quote (0 . 1))))',
  '  (vlax-safearray-fill sa (list x y)) sa)',
  // plot ONE window to its own A1 page. acWindow = 4.
  '(defun plotwin (fn w / doc lay plt)',
  '  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) lay (vla-get-ActiveLayout doc))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-ConfigName lay "DWG To PDF.pc3"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-StyleSheet lay "monochrome.ctb"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotWithPlotStyles lay :vlax-true))))',
  // A1 = 841 x 594, exactly A3 doubled in each direction. Tried in order; each put is caught, so
  // a media name this plotter does not know is skipped and the one before it stands.
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CanonicalMediaName lay "ISO_full_bleed_A3_(420.00_x_297.00_MM)"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CanonicalMediaName lay "ISO_A1_(841.00_x_594.00_MM)"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CanonicalMediaName lay "ISO_expand_A1_(841.00_x_594.00_MM)"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CanonicalMediaName lay "ISO_full_bleed_A1_(841.00_x_594.00_MM)"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-SetWindowToPlot lay (mkpt (nth 0 w) (nth 1 w)) (mkpt (nth 2 w) (nth 3 w))))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotType lay 4))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-UseStandardScale lay :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-StandardScale lay 0))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CenterPlot lay :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotRotation lay 0))))',
  '  (setq plt (vla-get-Plot doc))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-QuietErrorMode plt :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-PlotToFile plt fn)))))',
  // one page per recorded window, plus a PNG of each so it can simply be looked at
  ...Array.from({ length: NPAGE }, (_, k) => [
    '(if (findfile "' + q(pagePdf(k + 1)) + '") (vl-file-delete "' + q(pagePdf(k + 1)) + '"))',
    '(plotwin "' + q(pagePdf(k + 1)) + '" (nth ' + k + ' *PEB-CRN-PAGES*))',
    '(command "_.ZOOM" "_W" (list (nth 0 (nth ' + k + ' *PEB-CRN-PAGES*)) (nth 1 (nth ' + k + ' *PEB-CRN-PAGES*)))'
      + ' (list (nth 2 (nth ' + k + ' *PEB-CRN-PAGES*)) (nth 3 (nth ' + k + ' *PEB-CRN-PAGES*))))',
    '(if (findfile "' + q(pagePng(k + 1)) + '") (vl-file-delete "' + q(pagePng(k + 1)) + '"))',
    '(command "_.PNGOUT" "' + q(pagePng(k + 1)) + '" "")',
  ]).flat(),
  '(if (findfile "' + q(dwg) + '") (vl-file-delete "' + q(dwg) + '"))',
  '(command "_.SAVEAS" "2018" "' + q(dwg) + '")',
  'QUIT', 'Y', '',
].join('\r\n');

const scrPath = path.join(WORK, '_crn.scr');
fs.writeFileSync(scrPath, scr);
try { execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 480000, stdio: 'ignore' }); } catch (e) {}

const ok = (f) => (fs.existsSync(f) ? Math.round(fs.statSync(f).size / 1024) + ' KB' : 'FAILED');
for (let i = 1; i <= NPAGE; i++) console.log('page ' + i + '  ' + ok(pagePdf(i)) + '   PNG ' + ok(pagePng(i)));

// merge the four single-page plots into one PDF. AutoCAD headless will not publish a multi-page
// PDF without a sheet set, so the merge happens here instead.
(async () => {
  try {
    const { PDFDocument } = require(PDFLIB);
    const out = await PDFDocument.create();
    for (let i = 1; i <= NPAGE; i++) {
      if (!fs.existsSync(pagePdf(i))) { console.log('page ' + i + ' missing - not merged'); continue; }
      const src = await PDFDocument.load(fs.readFileSync(pagePdf(i)));
      const pages = await out.copyPages(src, src.getPageIndices());
      pages.forEach((pg) => out.addPage(pg));
    }
    fs.writeFileSync(pdf, await out.save());
    console.log('PDF ' + ok(pdf) + '  ' + out.getPageCount() + ' pages  ' + pdf);
  } catch (e) { console.log('MERGE FAILED: ' + e.message); }
  console.log('DWG ' + ok(dwg) + '  ' + dwg);
})();
