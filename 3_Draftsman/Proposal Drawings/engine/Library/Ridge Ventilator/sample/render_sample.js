'use strict';
// == SAMPLE HARNESS - RIDGE VENTILATOR ───────────────────────────────────────────────────────────
//
// THIS IS DEVELOPMENT CODE, SEPARATE FROM THE BSF-SYNCHRONISED DRAWING ENGINE
// (owner, 3-Sep-2026: "this develop coding will be separate from Synchronized Coding of BSF
// Based generated Drawings"). Nothing here is loaded by the proposal set. It exists so the
// component can be drawn and LOOKED at in ~25 seconds instead of rendering a whole building,
// and so two terminals can develop two components without touching the same file.
//
// WHAT IT PROVES: that the SYMBOL is the real profile. It draws the ventilator at TRUE SIZE on a
// piece of ridge with the traced chain (600 overall / 542 high / 288 throat / 203 wind band)
// beside the same symbol drawn as it is actually placed, so the two can be compared against
// reference/sectionAA_zoom.png. Symbol only - the fabricated parts are a later phase.
//
// Run:  node render_sample.js        (from anywhere)
// Out:  C:\maimaar_render\rv_<stamp>\RV_SAMPLE.png  +  .dwg
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// Forward slashes throughout: Node accepts them on Windows, and they cannot be eaten as escape
// sequences the way a hand-written "\2_Sales" was (it parsed as an octal escape).
const CRM = 'D:/maimaar-os/2_Sales CRM';
const ENGINE = 'D:/maimaar-os/3_Draftsman/Proposal Drawings/engine';
const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';
const INQUIRY = Number(process.env.INQUIRY || 5403);   // MSPL-26-266 — a real BSF, real numbers

require(CRM + '/node_modules/dotenv').config({ path: CRM + '/.env', quiet: true });

// FRESH DIR PER RUN, never rmSync: a PDF left open in a viewer makes the delete throw EPERM.
const WORK = 'C:/maimaar_render/lv_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// The BSF data file. The ridge-vent drawers take everything as arguments and read nothing, so the
// sample runs WITHOUT this too. The symbol is one traced size, so the data changes nothing here
// yet - it is generated so the harness stays identical to every other component's.
let dataFile = null;
try {
  const dd = require(CRM + '/dist/services/drawingData');
  const gen = (dd.default || dd).generate(INQUIRY, { engineDir: ENGINE, dataDir: WORK, format: 'dxf' });
  gen.files.forEach((f) => fs.writeFileSync(path.join(WORK, f.name), f.content));
  dataFile = gen.files[0].name;
} catch (e) {
  console.log('no BSF data (' + e.message + ') - drawing the traced symbol only');
}

// Forward slash -> the DOUBLED backslash a LISP string literal needs. ONE substitution: an
// earlier version ran a second pass over its own output and produced D:\\\maimaar-os, so every
// (load) failed and the sheet came out blank with no error the harness could see.
const q = (s) => s.split('/').join('\\\\');
const load = (f) => '(load "' + q(ENGINE + '/' + f) + '")';
const dwg = WORK + '/RV_SAMPLE.dwg';
const png = WORK + '/RV_SAMPLE.png';

const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)',
  load('MAIMAAR_PEB_Standard.lsp'), load('MAIMAAR_PEB_Section.lsp'), load('MAIMAAR_PEB_Plan.lsp'),
  load('MAIMAAR_PEB_Roof.lsp'), load('MAIMAAR_PEB_Elevation.lsp'), load('MAIMAAR_PEB_Framing.lsp'),
  load('MAIMAAR_PEB_Cover.lsp'),
  load('Library/Ridge Ventilator/MAIMAAR_PEB_RidgeVent.lsp'),
  load('MAIMAAR_PEB_PDF.lsp'),
  dataFile
    ? '(peb-rv-sample-from-file "' + q(WORK + '/' + dataFile) + '")'
    : '(progn (setq *PEB-TEXT-SCALE* 0.30 *PEB-DIM-SCALE* 0.30) (peb-draw-rv-sample nil 0.0 0.0))',
  '(command "_.ZOOM" "_E")',
  // DELETE BEFORE WRITING — what the engine's own _pebout does. SAVEAS onto an existing file
  // asks "replace? <N>", and that OPEN PROMPT swallows every line after it: an earlier run lost
  // its PNGOUT to exactly this and then hung for 10 minutes.
  '(if (findfile "' + q(dwg) + '") (vl-file-delete "' + q(dwg) + '"))',
  '(if (findfile "' + q(png) + '") (vl-file-delete "' + q(png) + '"))',
  '(command "_.SAVEAS" "2018" "' + q(dwg) + '")',
  '(command "_.PNGOUT" "' + q(png) + '" "")',
  'QUIT', 'Y', '',
].join('\r\n');
const scrPath = path.join(WORK, '_rv.scr');
fs.writeFileSync(scrPath, scr);

const t0 = Date.now();
try {
  execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 300000, stdio: 'ignore' });
} catch (e) { /* acad exits non-zero on QUIT; the files below are the real check */ }
console.log('WORK:', WORK, '| seconds:', Math.round((Date.now() - t0) / 1000));
fs.readdirSync(WORK).forEach((f) => console.log('  ', f, fs.statSync(path.join(WORK, f)).size));

// KEEP THE LAST RENDER IN THE LIBRARY. A drawing nobody can see has not been verified, and the
// next terminal to open this folder should be able to see what it looked like without AutoCAD.
if (fs.existsSync(png)) {
  fs.copyFileSync(png, path.join(__dirname, 'last_render.png'));
  console.log('copied -> sample/last_render.png');
}
