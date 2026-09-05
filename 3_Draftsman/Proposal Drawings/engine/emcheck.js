'use strict';
// emcheck.js — there is ONE character-width constant in this engine, and it is 0.94.
//
//   node emcheck.js            (scans engine/*.lsp, Library/**/*.lsp and engine/*.js)
//
// WHY.  A ROMAND character is 0.9417 em wide, measured with vla-GetBoundingBox (GOLDEN_RULES 37).
// For months this engine believed 0.62. A routine that thinks a string is a third narrower than
// it is will fit a note into a gap it does not fit, report a clearance that is not there, and
// pass a clash check on a sheet that clashes - silently, every time. That single wrong number is
// why "checked for collisions" kept coming back clean on drawings the owner could see were not.
//
// The constant was corrected in peb-fit-txt-h and in the checkers, but a survey on 5-Sep-2026
// found 0.62 still live in five more places, plus a 0.90 and a 0.85 - each one an independent
// guess at the same physical quantity. This makes that impossible to reintroduce quietly.
//
// It flags a suspicious literal only where it is doing WIDTH arithmetic - multiplied by a string
// length or a text height - so ordinary geometry factors are not dragged in.

const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const GOOD = 0.94;
const files = [];
(function walk(dir, depth) {
  if (depth > 4) return;
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    if (f.name === 'node_modules' || f.name.startsWith('_checkpoints')) continue;
    const p = path.join(dir, f.name);
    if (f.isDirectory()) walk(p, depth + 1);
    else if (/\.(lsp|js)$/i.test(f.name) && f.name !== 'emcheck.js') files.push(p);
  }
})(ROOT, 0);

// A literal between 0.55 and 1.0 in an expression that is measuring a STRING'S WIDTH - that is,
// one that multiplies by a character COUNT. Requiring strlen (or one of the named width helpers)
// is what keeps ordinary geometry factors out: "(* wid 0.78)" is a position along a building, not
// a character width, and a checker that cannot tell them apart reports 189 hits and gets ignored.
const SUSPECT = /(0\.\d+)/g;
const WIDTHY = /strlen|wPerCh|peb-crn-em|mzd-tw|\bEM\b|per-char|advance width/i;

let bad = 0, checked = 0;
files.forEach((p) => {
  const rel = path.relative(ROOT, p);
  const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
  // -- A CHARACTER COUNT OUTLIVES ITS LINE -------------------------------------------------
  // Requiring `strlen` on the SAME line as the constant is what let peb-head-h keep 0.62
  // while this check reported the engine clean:
  //     n  (max 1 (strlen s))
  //     hmax (/ (* 0.34 faceLen) (* n 0.62 ts))
  // The count is taken on one line and spent on the next, which is how anyone would write it.
  // So collect the names that appear where a strlen was taken, and treat multiplication
  // involving those names as width context too.  A checker that only sees single-line width
  // maths hands a clean bill of health to the exact constant it exists to catch, and a false
  // clean is worse than no check at all - this one reported 0 while 0.62 was live.
  const isWordCh = (c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                          (c >= '0' && c <= '9') || c === '_' || c === '-';
  const tokens = (ln) => { const out = []; let cur = '';
    for (const c of ln) { if (isWordCh(c)) { cur += c; } else { if (cur) out.push(cur); cur = ''; } }
    if (cur) out.push(cur); return out; };
  // SCOPED TO THE DEFUN IT LIVES IN.  File-wide, one function that happens to store a strlen
  // in `wid` made every (* wid 0.72) in the file a suspect - 54 hits, nearly all of them the
  // building width. A character count is a local, so the set resets at each defun.
  let lenVars = new Set();
  // A WIDTH CAP DIVIDES BY (count x em).  Both real cases are of the form
  //     (/ (* 0.34 faceLen) (* n 0.94 ts))
  // whereas every false positive was a plain fraction of a length - (* wid 0.55), (* span 0.9).
  // Requiring the division as well takes the noise from 15 lines to 2, which is the difference
  // between a check that gets read and one that gets skipped.
  const usesLenVar = (code) => code.indexOf('*') >= 0 && code.indexOf('(/') >= 0 &&
                               tokens(code).some((t) => lenVars.has(t));
  lines.forEach((ln, i) => {
    if (ln.startsWith('(defun')) lenVars = new Set();
    if (ln.indexOf('strlen') >= 0) {
      const t0 = tokens(ln.replace(/;.*$/, '')).filter((x) => x !== 'setq' && x !== 'defun');
      if (t0.length && !/^[0-9]/.test(t0[0]) && t0[0] !== 'strlen') lenVars.add(t0[0]);
    }
    // An explicit, readable exemption for the handful of constants that are NOT advance widths -
    // a fraction of a bubble's radius, or a deliberate tightening applied on top of the real em.
    // Written in the source next to the number, so the reason travels with it.
    if (/emcheck-ok/.test(ln)) return;
    const code = ln.replace(/;.*$/, '');                 // drop lisp comments
    if (!WIDTHY.test(code) && !usesLenVar(code)) return;
    if (!/[*(]/.test(code)) return;
    let m;
    SUSPECT.lastIndex = 0;
    while ((m = SUSPECT.exec(code))) {
      const v = parseFloat(m[1]);
      if (!(v >= 0.55 && v <= 1.0)) continue;
      checked++;
      if (Math.abs(v - GOOD) < 1e-9) continue;
      bad++;
      console.log(`  ${rel}:${i + 1}  ${m[1]}   ${ln.trim().slice(0, 96)}`);
    }
  });
});

console.log(`\nemcheck: ${files.length} files, ${checked} width-context constants, ${bad} not ${GOOD}`);
if (bad) console.log('A character width is a MEASUREMENT, not a guess. See GOLDEN_RULES 37.');
process.exitCode = bad ? 1 : 0;
