'use strict';
// Bring the OLD REFERENCE into view. The approval drawing is a PDF and there is no PDF
// rasteriser on this machine, so AutoCAD does the job: PDFIMPORT turns the sheet into real
// geometry, then PNGOUT rasters it. That way the traced numbers can be checked against the
// drawing they came from instead of against extracted text.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';
const SRC = path.resolve(__dirname, 'MSPL-224_seamlock-skylight-profile.pdf');
const WORK = 'C:/maimaar_render/ref_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });

// ONE substitution: forward slash -> the doubled backslash a LISP string literal needs. Running
// a second pass over the output produced D:\\\\maimaar-os and every path silently missed.
const q = (s) => s.split('/').join('\\\\');
const png = WORK + '/REFERENCE.png';
// KEEP THE CONVERTED DRAWING IN THE LIBRARY (owner: "convert it dxf file if required, but keep
// here in library"). The PDF is a picture; the DXF is geometry that can be measured, snapped to
// and traced from — which is what a reference is for.
const dxf = path.resolve(__dirname, 'MSPL-224_seamlock-skylight-profile.dxf').split('\\').join('/');

// -PDFIMPORT is the command-line form: File -> path -> page -> insertion pt -> scale -> rotation.
const scr = [
  'FILEDIA', '0', '(setvar "SECURELOAD" 0)', '(setvar "CMDECHO" 1)',
  // RAW path here, NOT q(): a SCRIPT line is plain text typed at the prompt, so its
  // backslashes must be single. q() is for LISP string literals only, where they double.
  // Doubling them made PDFIMPORT report 'file does not exist' and re-prompt forever,
  // eating every line after it - the same open-prompt trap as the SAVEAS overwrite.
  // QUOTED, because "Proposal Drawings" contains a space and a SCRIPT line is split on spaces:
  // unquoted, the path arrived as two separate answers and the prompt loop ate the rest of the
  // file. (This is the same space-in-the-path trap the render output dir has a rule about.)
  '_.-PDFIMPORT', 'F', '"' + SRC.split('/').join(String.fromCharCode(92)) + '"', '1', '0,0', '1', '0',
  '(command "_.ZOOM" "_E")',
  '(if (findfile "' + q(dxf) + '") (vl-file-delete "' + q(dxf) + '"))',
  '(if (findfile "' + q(png) + '") (vl-file-delete "' + q(png) + '"))',
  '(command "_.DXFOUT" "' + q(dxf) + '" "16")',
  '(command "_.PNGOUT" "' + q(png) + '" "")',
  'QUIT', 'Y', '',
].join('\r\n');
const scrPath = path.join(WORK, '_ref.scr');
fs.writeFileSync(scrPath, scr);

try {
  execFileSync(ACAD, ['/nologo', '/b', scrPath], { cwd: WORK, timeout: 240000, stdio: 'ignore' });
} catch (e) { /* QUIT exits non-zero; the files are the check */ }
console.log('WORK:', WORK);
fs.readdirSync(WORK).forEach((f) => console.log('  ', f, fs.statSync(path.join(WORK, f)).size));
