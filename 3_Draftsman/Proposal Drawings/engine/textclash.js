'use strict';
// textclash.js — find ANNOTATION that prints on top of other ANNOTATION, in a model DXF.
//
//   node textclash.js <file.dxf> [--gap <f>] [--all] [--min <mm2>]
//
// WHY THIS EXISTS.  Owner 5-Sep-2026: "Do the Audit of all dimensions and all Text and Fix all
// it - GOLDEN RULE NO TEXT MUST OVERRIDE ON THE OTHER TEXT", then, widening it: "No Override of
// Text and Labells and MLadders and Dim."  Eyeballing a rastered sheet is not evidence: a wrong
// linetype, a 3x-too-shallow girder and a floating end carriage all survived a look on the same
// day, and were caught only by measuring.  So this measures.
//
// IT USED TO LIE.  Until 5-Sep this filtered TEXT/MTEXT at the top level of the DXF and reported
// "0 overlapping pairs" on sheets that plainly had them.  It could not see MLEADER text - which
// is where the ROOF SHEETING and WALL SHEETING notes live, the pair that has been printing
// through itself on PRO-02.  Box construction now lives in dxfannot.js, which knows about all
// three places this engine puts annotation.  Read that file's header before trusting this one.

const path = require('path');
const A = require(path.join(__dirname, 'dxfannot.js'));

const file = process.argv[2];
const showAll = process.argv.includes('--all');
const mi = process.argv.indexOf('--min');
const MINAREA = mi > 0 ? parseFloat(process.argv[mi + 1]) : 0;
// --gap <f>: require f x text-height of CLEAR AIR around every string, not merely non-overlap.
// Two labels that miss each other by 8 units out of a 550 height are touching as far as a reader
// is concerned, and S57 says a clearance is measured from the height of the text it has to clear.
// 0 = strict overlap only.
const gi = process.argv.indexOf('--gap');
const GAP = gi > 0 ? parseFloat(process.argv[gi + 1]) : 0;

if (!file) {
  console.error('usage: node textclash.js <file.dxf> [--gap <f>] [--all] [--min <mm2>]');
  process.exit(2);
}

const ents = A.readDxf(file);
const { boxes, nText, nMleader, skippedInBlocks } = A.annotationBoxes(ents, GAP);

const hits = [];
for (let i = 0; i < boxes.length; i++) {
  for (let j = i + 1; j < boxes.length; j++) {
    // A MASK RE-ASSERT IS NOT A CLASH.  Some labels are drawn twice on purpose: the AREA tag is
    // laid down early so the corner diagonals can terminate on real box corners, then re-drawn
    // last over a WIPEOUT, because the grid and ridge lines are drawn after it and would strike
    // through the lettering (Plan.lsp, owner 27-Aug audit).  The second copy lands exactly on the
    // first and the reader sees ONE label.  Identical string at an identical anchor and height is
    // that pattern, not two labels fighting.
    if (boxes[i].txt === boxes[j].txt && boxes[i].h === boxes[j].h &&
        Math.abs(boxes[i].pts[0][0] - boxes[j].pts[0][0]) < 1e-6 &&
        Math.abs(boxes[i].pts[0][1] - boxes[j].pts[0][1]) < 1e-6) continue;
    if (!A.overlaps(boxes[i].pts, boxes[j].pts)) continue;
    const a = A.clipArea(boxes[i].pts, boxes[j].pts);
    const frac = a / Math.min(boxes[i].w * boxes[i].hgt, boxes[j].w * boxes[j].hgt);
    if (a <= MINAREA) continue;
    hits.push({ a, frac, x: boxes[i].pts[0][0], y: boxes[i].pts[0][1], A: boxes[i], B: boxes[j] });
  }
}
hits.sort((p, q) => q.frac - p.frac);

console.log(`${file}`);
console.log(`  annotation: ${boxes.length}   (${nText} text+dim, ${nMleader} m-ladder)` +
            (skippedInBlocks ? `   [${skippedInBlocks} skipped inside non-dimension blocks]` : ''));
console.log(`  overlapping pairs: ${hits.length}` + (GAP ? `   (clearance ${GAP} x text height)` : ''));
const show = showAll ? hits : hits.slice(0, 25);
show.forEach((h) => {
  console.log(
    `  ${(h.frac * 100).toFixed(0).padStart(3)}%  at ${h.x.toFixed(0)},${h.y.toFixed(0)}\n` +
    `        "${h.A.txt}"  [${h.A.kind}/${h.A.lay}]\n` +
    `        "${h.B.txt}"  [${h.B.kind}/${h.B.lay}]`
  );
});
if (!showAll && hits.length > show.length) console.log(`  ... ${hits.length - show.length} more (--all)`);
process.exitCode = hits.length ? 1 : 0;
