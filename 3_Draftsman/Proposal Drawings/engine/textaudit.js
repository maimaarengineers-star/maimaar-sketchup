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

// SECOND PASS, over the JOINED source.  The line-scanner below needs the justification to be a
// literal "XX" on the same line as the height, and the two calls that most need catching are
// neither: rm-mladder writes (txt-rom (if right "ML" "MR") ... 150 0 txt), and rm-label spreads
// (txt just (list ...) / 160 0 str) across two lines.  Both hand a bare number to a text helper -
// 150 and 160, about 0.54 mm on paper, under the smallest rung on the ladder - and both slipped
// past every audit for exactly this reason.  Here the file is joined and the height argument is
// found by walking the call, so how the call is laid out stops mattering.
function joinedPass(name, src, rows) {
  const HELPERS = /\((txt|txt-bold|txt-rom|txt-dim|mzd-txt|mzd-txt-b|mzd-txt-d)\s/g;
  const flat = src.split('\n').map(function (l) { return l.replace(/;.*$/, ''); }).join('\n');
  let m;
  while ((m = HELPERS.exec(flat))) {
    let d = 0, start = -1;
    const args = [];
    for (let j = m.index; j < flat.length; j++) {
      const c = flat[j];
      if (c === '(') { d++; if (d === 2 && start < 0) start = j; }
      else if (c === ')') {
        d--;
        if (d === 0) break;
        if (d === 1 && start >= 0) { args.push(flat.slice(start, j + 1)); start = -1; }
      } else if (d === 1 && start < 0 && /\S/.test(c)) {
        let k = j; while (k < flat.length && !/[\s)]/.test(flat[k])) k++;
        args.push(flat.slice(j, k)); j = k - 1;
      }
    }
    const h = args[3];                       // helper, justification, point, HEIGHT
    if (h && /^-?\d+(\.\d+)?$/.test(h)) {
      const line = flat.slice(0, m.index).split('\n').length;
      rows.push({ f: name, line, h: parseFloat(h),
                  src: flat.slice(m.index, m.index + 92).replace(/\n\s*/g, ' ') });
    }
  }
}

for (const f of process.argv.slice(2)) {
  const name = f.split(/[\\/]/).pop();
  joinedPass(name, fs.readFileSync(f, 'utf8'), rows);
  fs.readFileSync(f, 'utf8').split('\n').forEach((raw, i) => {
    const line = raw.replace(/;.*$/, '');
    // (txt "ML" <pt> <height> <rot> <string>)  and every sibling that draws text.
    // It used to match txt and txt-bold only, which left txt-rom, txt-dim and the mezzanine
    // wrappers free to pick their own sizes - and that is where the two M-Ladder heights that
    // bypass the ladder entirely live (rm-mladder passes a raw 150, rm-label a raw 160; at
    // TS ~ 1 those plot about 0.54 mm, well under the smallest defined rung). Owner 5-Sep-2026:
    // "Size of Text for Different Labelling are too small, too big."
    const m = /\((txt|txt-bold|txt-rom|txt-dim|mzd-txt|mzd-txt-b|mzd-txt-d)\s+"[A-Z]{2}"\s+(.+)$/.exec(line);
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

// The two passes overlap on calls that fit on one line - keep one row per site, so a defect is
// reported once and the count means what it says.
{
  const seen = new Set();
  for (let i = rows.length - 1; i >= 0; i--) {
    const k = rows[i].f + ':' + rows[i].line + ':' + rows[i].h;
    if (seen.has(k)) rows.splice(i, 1); else seen.add(k);
  }
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
