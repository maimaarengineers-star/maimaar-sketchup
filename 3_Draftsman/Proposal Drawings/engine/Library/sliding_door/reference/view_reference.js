'use strict';
// ── BRING THE OLD REFERENCE INTO VIEW ────────────────────────────────────────────────────────
//
// GOLDEN RULE 19: read the DRAWING, not the text layer. The seam-lock skylight was traced at
// 637 cover from `pdftotext` output and turned out to be 484 across the finished panel — 637 was
// the developed girth. Every job number in ../README.md was likewise read from the PDF's text
// stream. Run this and check them against the geometry BEFORE quoting any of them as an as-built.
//
// There is no PDF rasteriser on this machine, so AutoCAD does the job: PDFIMPORT turns the sheet
// into real geometry, then DXFOUT keeps it (a DXF can be measured and snapped to; a PDF cannot)
// and PNGOUT rasters it so it can simply be looked at.
//
// Run:  node view_reference.js                 (defaults to MSPL-030 SDS-01, the double door)
//       node view_reference.js MSPL-027_2021_SSD-01_single-sliding-door_erection+shop.pdf
// Out:  a DXF beside this file, and a PNG in the work dir.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';
const NAME = process.argv[2] || 'MSPL-030_2022_SDS-01_sliding-door-elevation+sections.pdf';
const PAGE = process.argv[3] || '1';
const SRC = path.resolve(__dirname, NAME);
if (!fs.existsSync(SRC)) {
  console.error('no such reference:', SRC);
  console.error('available:\n  ' + fs.readdirSync(__dirname).filter((f) => /\.pdf$/i.test(f)).join('\n  '));
  process.exit(1);
}

// FRESH DIR PER RUN, never rmSync: a PDF left open in a viewer makes the delete throw EPERM.
const WORK = 'C:/maimaar_render/sldref_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// ONE substitution: forward slash -> the doubled backslash a LISP string literal needs. Running
// a second pass over the output produced D:\\\\maimaar-os and every path silently missed.
const q = (s) => s.split('/').join('\\\\');
const png = WORK + '/REFERENCE.png';
const dxf = path.resolve(__dirname, NAME.replace(/\.pdf$/i, '') + '_p' + PAGE + '.dxf')
  .split('\\').join('/');

const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)', '(setvar "CMDECHO" 1)',
  // RAW path here, NOT q(): a SCRIPT line is plain text typed at the prompt, so its backslashes
  // must be SINGLE. Doubling them made PDFIMPORT report 'file does not exist' and re-prompt
  // forever, eating every line after it — the open-prompt trap of golden rule 10.
  // QUOTED, because "Proposal Drawings" contains a space and a script line splits on spaces.
  '_.-PDFIMPORT', 'F', '"' + SRC.split('/').join(String.fromCharCode(92)) + '"', PAGE, '0,0', '1', '0',
  '(command "_.ZOOM" "_E")',
  '(if (findfile "' + q(dxf) + '") (vl-file-delete "' + q(dxf) + '"))',
  '(if (findfile "' + q(png) + '") (vl-file-delete "' + q(png) + '"))',
  '(command "_.DXFOUT" "' + q(dxf) + '" "16")',
  '(command "_.PNGOUT" "' + q(png) + '" "")',
  'QUIT', 'Y', '',
].join('\r\n');
const scrPath = path.join(WORK, '_sldref.scr');
fs.writeFileSync(scrPath, scr);

try {
  execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 240000, stdio: 'ignore' });
} catch (e) { /* QUIT exits non-zero; the files are the check */ }
console.log('SOURCE:', NAME, 'page', PAGE);
console.log('WORK:', WORK);
fs.readdirSync(WORK).forEach((f) => console.log('  ', f, fs.statSync(path.join(WORK, f)).size));
if (fs.existsSync(dxf)) console.log('DXF kept:', dxf);
else console.log('NO DXF — PDFIMPORT did not complete. Read _sldref.scr and the acad log.');
