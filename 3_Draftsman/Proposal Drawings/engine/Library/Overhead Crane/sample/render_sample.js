'use strict';
// ── SAMPLE HARNESS — OVERHEAD CRANE BRIDGE ──────────────────────────────────────────────────
//
// DEVELOPMENT CODE, SEPARATE FROM THE BSF-SYNCHRONISED DRAWING ENGINE (owner 3-Sep-2026:
// "this develop coding will be separate from Synchronized Coding of BSF Based generated
// Drawings"). Nothing here is loaded by the proposal set.
//
// It draws the bridge TOP and SIDE view at size and rasters a PNG, because a drawing nobody can
// see has not been verified — and on an A4 at 1:209 the girder is 1.7 mm tall, which is no way
// to develop it.
//
//   node render_sample.js
// Out: C:/maimaar_render/crn_<stamp>/CRANE_BRIDGE.png  +  .dwg
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ENGINE = 'D:/maimaar-os/3_Draftsman/Proposal Drawings/engine';
const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';

const WORK = 'C:/maimaar_render/crn_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// ESCAPING — the thing that bites. A .scr line takes a RAW single backslash and must be QUOTED
// when the path holds a space; a LISP string literal needs it DOUBLED. Mixing the two leaves an
// open prompt that silently eats the rest of the script.
const q = (s) => s.split('/').join('\\\\');
const png = WORK + '/CRANE_BRIDGE.png';
const dwg = WORK + '/CRANE_BRIDGE.dwg';
const pdf = WORK + '/CRANE_BRIDGE.pdf';

const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)',
  '(load "' + q(ENGINE + '/MAIMAAR_PEB_Standard.lsp') + '")',
  '(load "' + q(ENGINE + '/MAIMAAR_PEB_Plan.lsp') + '")',
  '(load "' + q(ENGINE + '/Library/Overhead Crane/MAIMAAR_PEB_Crane.lsp') + '")',
  '(C:PEB-CRANE-SAMPLE)',
  '(command "_.ZOOM" "_E")',
  '(if (findfile "' + q(png) + '") (vl-file-delete "' + q(png) + '"))',
  '(command "_.PNGOUT" "' + q(png) + '" "")',
  // A3 landscape PDF of the sheet, monochrome like the deliverable, so the crane can be looked
  // at on paper at a size where its detail is visible.
  '(vl-load-com)',
  '(defun plotpdf (fn / doc lay plt)',
  '  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) lay (vla-get-ActiveLayout doc))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-ConfigName lay "DWG To PDF.pc3"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-StyleSheet lay "monochrome.ctb"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotWithPlotStyles lay :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotType lay 1))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-UseStandardScale lay :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-StandardScale lay 0))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CenterPlot lay :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-CanonicalMediaName lay "ISO_full_bleed_A3_(420.00_x_297.00_MM)"))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-PlotRotation lay 0))))',
  '  (setq plt (vla-get-Plot doc))',
  '  (vl-catch-all-apply (quote (lambda () (vla-put-QuietErrorMode plt :vlax-true))))',
  '  (vl-catch-all-apply (quote (lambda () (vla-PlotToFile plt fn)))))',
  '(if (findfile "' + q(pdf) + '") (vl-file-delete "' + q(pdf) + '"))',
  '(plotpdf "' + q(pdf) + '")',
  '(if (findfile "' + q(dwg) + '") (vl-file-delete "' + q(dwg) + '"))',
  '(command "_.SAVEAS" "2018" "' + q(dwg) + '")',
  'QUIT', 'Y', '',
].join('\r\n');

const scrPath = path.join(WORK, '_crn.scr');
fs.writeFileSync(scrPath, scr);
try { execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 240000, stdio: 'ignore' }); } catch (e) {}
const ok = (f) => (fs.existsSync(f) ? Math.round(fs.statSync(f).size / 1024) + ' KB' : 'FAILED');
console.log('PNG ' + ok(png) + '  ' + png);
console.log('DWG ' + ok(dwg) + '  ' + dwg);
console.log('PDF ' + ok(pdf) + '  ' + pdf);
