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
  lines.forEach((ln, i) => {
    const code = ln.replace(/;.*$/, '');                 // drop lisp comments
    if (!WIDTHY.test(code)) return;
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
