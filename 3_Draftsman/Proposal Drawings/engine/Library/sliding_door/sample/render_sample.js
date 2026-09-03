'use strict';
// ── SAMPLE HARNESS — SLIDING DOOR ───────────────────────────────────────────────────────────
//
// THIS IS DEVELOPMENT CODE, SEPARATE FROM THE BSF-SYNCHRONISED DRAWING ENGINE.
// Nothing here is loaded by the proposal set. It exists so the component can be drawn and
// LOOKED at in ~25 seconds instead of rendering a whole building, and so two terminals can
// develop two components without touching the same file.
//
// It draws ONE door: a DOUBLE SLIDING DOOR in a 6000 x 6000 framed opening — the exact case
// the reference manual designs on p753-758, so every member on the sample has a published
// calculation behind it (see ../README.md).
//
// Unlike the light-panel harness this needs NO BSF and NO inquiry: peb-sld-* is pure geometry
// and takes its size as arguments, which is the whole point of the component contract. It
// loads the engine only to reach the SHARED sandwich-panel module the leaf is clad in.
//
// Run:  node render_sample.js
// Out:  C:\maimaar_render\sld_<stamp>\SLD_SAMPLE.png  +  .dwg
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// Forward slashes throughout: Node accepts them on Windows, and they cannot be eaten as escape
// sequences the way a hand-written "\2_Sales" was (it parsed as an octal escape).
const ENGINE = 'D:/maimaar-os/3_Draftsman/Proposal Drawings/engine';
const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';

// FRESH DIR PER RUN, never rmSync: a PDF left open in a viewer makes the delete throw EPERM.
const WORK = 'C:/maimaar_render/sld_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// Forward slash -> the DOUBLED backslash a LISP string literal needs. ONE substitution: an
// earlier version ran a second pass over its own output and produced D:\\\maimaar-os, so every
// (load) failed and the sheet came out blank with no error the harness could see.
const q = (s) => s.split('/').join('\\\\');
const load = (f) => '(load "' + q(ENGINE + '/' + f) + '")';
const dwg = WORK + '/SLD_SAMPLE.dwg';
const png = WORK + '/SLD_SAMPLE.png';

const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)',
  '(setvar "LWDISPLAY" 1)',
  load('MAIMAAR_PEB_Standard.lsp'),
  // Framing.lsp is loaded for ONE thing: peb-sandwich-module, the single declared source for the
  // sandwich profile the leaf is clad in (golden rule 3 - one source, never two equal numbers).
  // Framing.lsp needs Plan.lsp and Section.lsp on its own load path, so they come first.
  load('MAIMAAR_PEB_Section.lsp'), load('MAIMAAR_PEB_Plan.lsp'), load('MAIMAAR_PEB_Framing.lsp'),
  load('Library/sliding_door/MAIMAAR_PEB_SlidingDoor.lsp'),
  '(peb-sld-sample)',
  '(command "_.ZOOM" "_E")',
  '(command "_.ZOOM" "0.92x")',
  // DELETE BEFORE WRITING — what the engine's own _pebout does. SAVEAS onto an existing file
  // asks "replace? <N>", and that OPEN PROMPT swallows every line after it: an earlier run lost
  // its PNGOUT to exactly this and then hung for 10 minutes.
  '(if (findfile "' + q(dwg) + '") (vl-file-delete "' + q(dwg) + '"))',
  '(if (findfile "' + q(png) + '") (vl-file-delete "' + q(png) + '"))',
  '(command "_.SAVEAS" "2018" "' + q(dwg) + '")',
  '(command "_.PNGOUT" "' + q(png) + '" "")',
  'QUIT', 'Y', '',
].join('\r\n');
const scrPath = path.join(WORK, '_sld.scr');
fs.writeFileSync(scrPath, scr);

const t0 = Date.now();
try {
  execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 300000, stdio: 'ignore' });
} catch (e) { /* acad exits non-zero on QUIT; the files below are the real check */ }
console.log('WORK:', WORK, '| seconds:', Math.round((Date.now() - t0) / 1000));
fs.readdirSync(WORK).forEach((f) => console.log('  ', f, fs.statSync(path.join(WORK, f)).size));

// Copy the PNG back beside this harness so the last render is always reviewable in the repo.
const out = path.join(__dirname, 'last_render.png');
if (fs.existsSync(png)) { fs.copyFileSync(png, out); console.log('copied ->', out); }
else { console.log('NO PNG — the script did not reach PNGOUT. Read _sld.scr and the acad log.'); }
