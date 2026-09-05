'use strict';
// textstyle.js - what TYPE and SIZE is every piece of text on the drawing, actually?
//
//   node textstyle.js <file.dxf> [--all]
//
// Owner, 5-Sep-2026: "type of Text and Size of all Texts".
//
// TWO PROPERTIES, ONE QUESTION. A drawing reads as one document when the same KIND of text is set
// in the same STYLE at the same SIZE everywhere. textaudit.js checks the size against the ladder in
// the SOURCE; textsize.js checks the rendered size per sheet. Neither has ever looked at the STYLE -
// the font each string is actually set in - and that is half of what a reader notices first.
//
// The engine defines FOUR styles, and - checked, not assumed - all four are romand.shx:
//   ROMAND / PEB-BODY / PEB-TITLE / PEB-DIM      (MAIMAAR_PEB_Standard.lsp, peb-std-textstyle)
//
// So they are SEMANTIC buckets, not different typefaces. My first version of this checker asserted
// "all text is ROMAND" from the engine's rule R9 and reported 188 violations; every one was a string
// legitimately set in PEB-BODY or PEB-TITLE. A checker that does not know the standard it is
// checking against invents defects, and 188 of them is worse than none - nobody reads the 189th.
//
// The failure actually worth catching is a style OUTSIDE that set - AutoCAD's own "Standard" most
// of all, which is what a text call gets when nobody chose a style. That one IS a different font and
// does look wrong on the page.
//
// PEB-DIM on dimensions is reported separately as a STANDARDS note rather than a defect: S58 asks
// for it, but since all four styles share romand.shx a dimension set in ROMAND is invisible on
// paper. Worth tidying, not worth alarming anybody about.
//
// SIZES are reported per style as the DISTINCT rendered heights, because that is the question worth
// asking of a finished sheet - not "what number is in the source" but "how many different sizes does
// a reader actually see". The ladder has 7 rungs; a sheet showing 30 distinct heights is not using it.

const HOUSE = /^(ROMAND|PEB-BODY|PEB-TITLE|PEB-DIM)$/;

const path = require('path');
const A = require(path.join(__dirname, 'dxfannot.js'));

const file = process.argv[2];
const showAll = process.argv.includes('--all');
if (!file) { console.error('usage: node textstyle.js <file.dxf> [--all]'); process.exit(2); }

const LADDER = { MARK: 400, SMALL: 550, DIM: 700, ANNOT: 830, LABEL: 970, HEADING: 1400, TITLE: 1650 };

const ents = A.readDxf(file);

// TEXT/MTEXT carry the style name in group 7 and the height in 40 (TEXT) or 40 (MTEXT nominal).
const rows = [];
for (const e of ents) {
  if (e.t !== 'TEXT' && e.t !== 'MTEXT') continue;
  if (e.blk && !/^\*D/i.test(e.blk)) continue;          // inside a block: not our body text
  const style = (e.g['7'] || '(none)').toUpperCase();
  const h = parseFloat(e.g['40']);
  const lay = e.g['8'] || '?';
  const txt = A.plain(e.g['1'] || e.g['3'] || '').replace(/\s+/g, ' ').trim();
  if (!txt) continue;
  rows.push({ style, h: Number.isFinite(h) ? h : 0, lay, txt });
}

console.log(file);
console.log('  text entities: %d', rows.length);
if (!rows.length) process.exit(0);

// ── by STYLE ────────────────────────────────────────────────────────────────────────────────────
const byStyle = new Map();
for (const r of rows) {
  if (!byStyle.has(r.style)) byStyle.set(r.style, []);
  byStyle.get(r.style).push(r);
}
console.log('\n  TYPE (text style)');
for (const [style, rs] of [...byStyle].sort((a, b) => b[1].length - a[1].length)) {
  const hs = [...new Set(rs.map((r) => Math.round(r.h)))].sort((a, b) => a - b);
  console.log('    %s  %d string(s)   %d distinct height(s): %s',
    style.padEnd(10), rs.length, hs.length, hs.slice(0, 12).join(', ') + (hs.length > 12 ? ' …' : ''));
  if (showAll) {
    for (const r of rs.slice(0, 6)) console.log('        %s  h=%d  [%s]', JSON.stringify(r.txt.slice(0, 44)), Math.round(r.h), r.lay);
  }
}

// ── the two failures worth having ───────────────────────────────────────────────────────────────
const wrongBody = rows.filter((r) => !HOUSE.test(r.style));
const wrongDim = rows.filter((r) => /DIM/i.test(r.lay) && !/PEB-DIM/.test(r.style));
console.log('\n  STYLE VIOLATIONS');
console.log('    text in a NON-HOUSE style : %d %s', wrongBody.length,
  wrongBody.length ? '(a style outside ROMAND/PEB-BODY/PEB-TITLE/PEB-DIM is a different font)' : '- every string is in a house style');
for (const r of wrongBody.slice(0, showAll ? 999 : 8)) {
  console.log('        %s  in %s  h=%d  [%s]', JSON.stringify(r.txt.slice(0, 40)), r.style, Math.round(r.h), r.lay);
}
console.log('    dimension text not PEB-DIM : %d %s', wrongDim.length,
  wrongDim.length ? '(S58 - a standards note: all four styles are romand.shx, so this is invisible on paper)' : '');
for (const r of wrongDim.slice(0, showAll ? 999 : 8)) {
  console.log('        %s  in %s  h=%d  [%s]', JSON.stringify(r.txt.slice(0, 40)), r.style, Math.round(r.h), r.lay);
}

// ── SIZES: how many does a reader actually see, and do they sit on the ladder? ──────────────────
// The rendered height is the ladder rung x the sheet's TEXT-SCALE, and every sheet sets its own
// scale, so a rendered height is only ON the ladder relative to some scale. Rather than guess the
// scale, this reports the RATIOS between the distinct heights: on a sheet using the ladder properly
// those ratios are ladder ratios (550/400, 830/550 ...), whatever the scale happens to be.
const heights = [...new Set(rows.map((r) => Math.round(r.h)))].sort((a, b) => a - b);
console.log('\n  SIZE');
console.log('    distinct rendered heights: %d', heights.length);
console.log('    %s', heights.join(', '));
const rungs = Object.values(LADDER).sort((a, b) => a - b);
const ratios = rungs.map((v) => (v / rungs[0]).toFixed(2));
console.log('    the ladder, as ratios off its smallest rung: %s', ratios.join(', '));
if (heights.length > 1) {
  const seen = heights.map((v) => (v / heights[0]).toFixed(2));
  console.log('    this drawing, same way                    : %s%s',
    seen.slice(0, 14).join(', '), seen.length > 14 ? ' …' : '');
}
// Only a non-house style fails the run; the PEB-DIM note is reported, not enforced.
process.exitCode = wrongBody.length ? 1 : 0;
