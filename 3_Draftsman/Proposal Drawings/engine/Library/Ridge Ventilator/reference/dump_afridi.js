'use strict';
// Pull the RIDGE VENTILATOR detail out of a real Maimaar approval drawing.
// 203-MSPL (Afridi Markets / DHL Warehouse, 2025) had the ridge ventilator IN OUR SCOPE, so its
// approval set carries a detail drawn to Maimaar's own standard rather than the manual's.
// The DWG is R2004+, so its text is compressed and `strings` finds nothing — AutoCAD has to
// open it. Pass 1 dumps every TEXT/MTEXT with a bounding box so the detail can be LOCATED;
// pass 2 (view_afridi.js) zooms to it and rasters.
const fs = require('fs'); const path = require('path');
const { execFileSync } = require('child_process');
const ACAD = process.env.AUTOCAD_EXE || 'C:/Program Files/Autodesk/AutoCAD 2021/acad.exe';
const SRC = 'E:/Maimaar Steel Pvt Ltd/Jobs/_approval_dwg_for_claude/2025_203-MSPL_Afridi Markets, Rawat, Main GT- Road, Rawalpindi -  DHL Warehouse @ Islamabad.dwg';
const WORK = 'C:/maimaar_render/rv_ref_' + Date.now().toString(36);
fs.mkdirSync(WORK, { recursive: true });
const q = (s) => s.split('/').join('\\');
const out = WORK + '/AFRIDI_TEXT.txt';
// Walk model space AND every layout block, because an approval detail usually lives on a sheet.
const scr = [
  'FILEDIA', '0', 'CMDDIA', '0', '(setvar "SECURELOAD" 0)', '(vl-load-com)',
  '(defun dumpall (fn / f e o p1 p2 ed s lay)',
  '  (setq f (open fn "w"))',
  '  (vlax-for bk (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))',
  '    (vlax-for o bk',
  '      (setq s (vl-catch-all-apply (function (lambda () (vla-get-TextString o)))))',
  '      (if (and s (not (vl-catch-all-error-p s)) (/= s ""))',
  '        (vl-catch-all-apply (function (lambda ()',
  '          (vla-GetBoundingBox o (quote p1) (quote p2))',
  '          (setq p1 (vlax-safearray->list p1) p2 (vlax-safearray->list p2))',
  '          (write-line (strcat (vla-get-Name bk) "|" s "|"',
  '            (rtos (car p1) 2 1) "|" (rtos (cadr p1) 2 1) "|"',
  '            (rtos (car p2) 2 1) "|" (rtos (cadr p2) 2 1)) f)))))))',
  '  (close f))',
  '(dumpall "' + q(out) + '")',
  '_.QUIT', '_N', '',
].join('\r\n');
const sp = path.join(WORK, '_dump.scr');
fs.writeFileSync(sp, scr);
try {
  execFileSync(ACAD, [SRC.split('/').join(String.fromCharCode(92)), '/nologo', '/b', sp],
    { cwd: WORK, timeout: 600000, stdio: 'ignore' });
} catch (e) {}
console.log('WORK:', WORK);
if (fs.existsSync(out)) {
  const lines = fs.readFileSync(out, 'utf8').split(/\r?\n/).filter(Boolean);
  console.log('text entities:', lines.length);
  fs.writeFileSync(path.join(__dirname, 'afridi_text.txt'), lines.join('\n'));
  lines.filter((l) => /vent|ridge/i.test(l)).slice(0, 40).forEach((l) => console.log('  ', l));
} else console.log('NO DUMP - check', WORK);
