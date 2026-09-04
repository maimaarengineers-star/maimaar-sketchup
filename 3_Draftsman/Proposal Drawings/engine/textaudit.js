// AUDIT: is every piece of drawn text sized from the DEFINED ladder?
//
// The ladder is *PEB-TEXT-HEIGHTS* in MAIMAAR_PEB_Standard.lsp, read via (peb-th 'NAME):
//   SMALL 550 · DIM 700 · ANNOT 830 · LABEL 970 · HEADING 1400 · TITLE 1650
// Anything drawn at a hard-coded number is a deviation — it will not track the ladder when
// the ladder changes, and it prints at a size nobody chose.
//
//   node textaudit.js MAIMAAR_PEB_*.lsp
const fs = require('fs');

const LADDER = { SMALL: 550, DIM: 700, ANNOT: 830, LABEL: 970, HEADING: 1400, TITLE: 1650 };
const rows = [];
let ok = 0;

for (const f of process.argv.slice(2)) {
  const name = f.split(/[\\/]/).pop();
  fs.readFileSync(f, 'utf8').split('\n').forEach((raw, i) => {
    const line = raw.replace(/;.*$/, '');
    // (txt "ML" <pt> <height> <rot> <string>)  /  (txt-bold ...)
    const m = /\((txt|txt-bold)\s+"[A-Z]{2}"\s+(.+)$/.exec(line);
    if (!m) return;
    const rest = m[2];
    // step past the point expression to the height argument
    let d = 0, j = 0;
    for (; j < rest.length; j++) {
      if (rest[j] === '(') d++;
      else if (rest[j] === ')') d--;
      if (d === 0 && rest[j] === ')') { j++; break; }
    }
    const after = rest.slice(j).trim();
    const h = after.split(/\s+/)[0];
    if (/peb-th|peb-head-h|hLb|hlab|shH|\bh\b/.test(h) || h.startsWith('(')) { ok++; return; }
    if (/^-?\d/.test(h)) rows.push({ f: name, line: i + 1, h: parseFloat(h), src: line.trim().slice(0, 96) });
  });
}

console.log('text calls sized from the ladder (or a computed cap): %d', ok);
console.log('HARD-CODED heights: %d\n', rows.length);
const near = (v) => {
  let best = null, bd = 1e9;
  for (const k of Object.keys(LADDER)) { const d = Math.abs(LADDER[k] - v); if (d < bd) { bd = d; best = k; } }
  return bd === 0 ? best + ' (exact)' : best + ' is ' + LADDER[best];
};
rows.sort((a, b) => a.h - b.h);
for (const r of rows) console.log(r.f + '  ' + r.line + '  h=' + r.h + '  (ladder min 550)  ' + r.src);
