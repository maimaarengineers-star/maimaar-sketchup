'use strict';
// textsize.js — one text height per CLASS per SHEET (S57), measured on the rendered drawing.
//
//   node textsize.js <file.dxf> [--all]
//
// Owner 5-Sep-2026: "Size of Text for Different Labelling are too small, too big."
//
// WHY THIS IS MEASURED AND NOT READ OFF THE SOURCE.  A call site hands a RAW height to txt /
// txt-bold / txt-rom, and the helper multiplies it by *PEB-TEXT-SCALE*, which every sheet sets for
// itself — the cross-section runs at 1.536 while the column layout runs at 0.8. So the same ladder
// rung plots at different sizes on different sheets, and two different rungs can plot at the same
// size. Reasoning about the literals tells you nothing; only the rendered heights do.
//
// It follows that the useful question is not "is this number on the ladder" (textaudit.js asks
// that, of the source) but "does the same KIND of label print at the same size on this sheet".
// That comparison needs no scale at all — within one sheet the scale cancels — which is why this
// works without instrumenting the engine.
//
// Sheets are separated by the big gaps between the blocks the render lays out along X.
// Classes are taken from the layer plus the shape of the string, because that is what a reader
// groups by: all the grid bubbles, all the wall names, all the member callouts.

const path = require('path');
const A = require(path.join(__dirname, 'dxfannot.js'));

const file = process.argv[2];
const showAll = process.argv.includes('--all');
if (!file) { console.error('usage: node textsize.js <file.dxf> [--all]'); process.exit(2); }

const ents = A.readDxf(file);
const { boxes } = A.annotationBoxes(ents, 0);

// the title block draws at paper scale in its own space — not comparable with the drawing body
const body = boxes.filter((b) => b.lay && b.lay !== '0' && b.lay !== 'BORDER' && b.lay !== 'Outer Line');
if (!body.length) { console.log('no drawing-body annotation'); process.exit(0); }

// ── split into sheets BY THEIR HEADINGS, not by guessing a gap ────────────────────────────────
// A gap threshold cannot do this. The render lays the sheets out along X and a single sheet spans
// the whole building, so any gap small enough to separate two sheets also splits one sheet in
// half, and any gap large enough to keep a sheet whole merges its neighbour. A first cut at
// 25,000 merged the section with the roof framing plan and then reported their different label
// sizes as one sheet disagreeing with itself - a checker inventing defects, which is exactly the
// failure this audit exists to stop.
//
// Every sheet carries exactly one view heading. Assign each annotation to the nearest heading in
// X and the split is the render's own, not a guess.
// Headings on this set end in more than PLAN/SECTION: the wall sheets are titled
// "NSW - NEAR SIDE WALL FRAMING" and "... SHEETING", so a pattern that stops at PLAN
// silently folds four elevations into whichever neighbour matched, and then reports their
// different label sizes as one sheet disagreeing with itself.
const HEADING = /(PLAN|SECTION|ELEVATIONS?|DETAILS?|SCHEDULE|FRAMING|SHEETING)$/;
const centre = (b) => b.pts.reduce((s, p) => s + p[0], 0) / b.pts.length;
const heads = body.filter((b) => HEADING.test(b.txt.trim()) && b.txt.length < 40)
                  .map((b) => ({ x: centre(b), name: b.txt.trim(), h: b.h }))
                  .sort((p, q) => p.x - q.x);
// keep the biggest text at each distinct position - the heading, not a note that ends in "PLAN"
const anchors = [];
heads.forEach((h) => {
  const near = anchors.find((a) => Math.abs(a.x - h.x) < 20000);
  if (!near) anchors.push(h);
  else if (h.h > near.h) { near.x = h.x; near.name = h.name; near.h = h.h; }
});
const sheets = anchors.map(() => []);
const names = anchors.map((a) => a.name);
if (!anchors.length) { console.log('no view headings found - cannot attribute annotation to sheets'); process.exit(0); }
body.forEach((b) => {
  const x = centre(b);
  let best = 0, bd = Infinity;
  anchors.forEach((a, i) => { const d = Math.abs(a.x - x); if (d < bd) { bd = d; best = i; } });
  sheets[best].push(b);
});

// ── what class of label is this ───────────────────────────────────────────────────────────────
function classOf(b) {
  const t = b.txt.trim();
  if (b.lay === 'GRID-TEXT') return 'grid bubble';
  if (b.kind === 'dim') return 'dimension text';
  if (b.kind === 'mladder') return 'm-ladder note';
  if (/^(NSW|FSW|LEW|REW)\b/.test(t)) return 'wall name';
  if (/^(HIGH|LOW) EAVE$/.test(t)) return 'eave tag';
  // The FALL glyph is ONE symbol with two texts at deliberately different sizes - peb-fall-marker
  // sets the word at 0.55 of the glyph unit and the ratio at 0.38, so they grow together and read
  // as a pair. Splitting them keeps this audit honest: a checker that reports a designed
  // difference as a defect gets ignored, and then it misses the real ones too.
  if (/^FALL$/.test(t)) return 'slope glyph (word)';
  if (/^1:\d+$/.test(t)) return 'slope glyph (ratio)';
  if (/^AREA NO/.test(t)) return 'area tag';
  if (/^BRACED BAY$/.test(t)) return 'braced-bay tag';
  if (/PLAN$|SECTION$|ELEVATIONS?$|DETAILS?$/.test(t)) return 'sheet/view heading';
  if (/ : |:\s/.test(t)) return 'member callout';
  return 'label';
}

let offenders = 0;
sheets.forEach((sheet, i) => {
  const byClass = {};
  sheet.forEach((b) => { const c = classOf(b); (byClass[c] = byClass[c] || []).push(b); });
  const mixed = Object.keys(byClass).filter((c) => new Set(byClass[c].map((b) => b.h.toFixed(0))).size > 1);
  const xs = sheet.map((b) => b.pts[0][0]);
  const head = `${(names[i] || 'sheet ' + (i + 1)).padEnd(30)} ` +
               `${String(sheet.length).padStart(3)} annotations, ` +
               `${new Set(sheet.map((b) => b.h.toFixed(0))).size} distinct heights`;
  if (!mixed.length && !showAll) { console.log(`  ${head}   OK`); return; }
  console.log(`  ${head}`);
  Object.keys(byClass).sort().forEach((c) => {
    const hs = {};
    byClass[c].forEach((b) => { const k = b.h.toFixed(0); (hs[k] = hs[k] || []).push(b.txt.slice(0, 24)); });
    const keys = Object.keys(hs).map(Number).sort((a, b) => a - b);
    if (keys.length === 1 && !showAll) return;
    if (keys.length > 1) offenders++;
    console.log(`      ${keys.length > 1 ? '!!' : '  '} ${c.padEnd(19)} ` +
                keys.map((k) => `${k}x${hs[k.toFixed(0)].length}`).join('  '));
    if (keys.length > 1) keys.forEach((k) =>
      console.log(`             ${String(k).padStart(6)}  ${JSON.stringify(hs[k.toFixed(0)].slice(0, 3))}`));
  });
});

console.log(`\ntextsize: ${sheets.length} sheets, ${offenders} class(es) printing at more than one size on their own sheet`);
process.exitCode = offenders ? 1 : 0;
