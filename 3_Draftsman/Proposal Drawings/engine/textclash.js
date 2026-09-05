'use strict';
// textclash.js — find TEXT that prints on top of other TEXT, in a model DXF.
//
//   node textclash.js <file.dxf> [--all] [--min <mm2>]
//
// WHY THIS EXISTS.  Owner 5-Sep-2026: "Do the Audit of all dimensions and all Text and Fix all
// it - GOLDEN RULE NO TEXT MUST OVERRIDE ON THE OTHER TEXT."  Eyeballing a rastered sheet is not
// evidence: today alone a wrong linetype, a 3x-too-shallow girder and a floating end carriage all
// survived a look, and were only caught by measuring.  So this measures.
//
// THE WIDTH CONSTANT.  A romand character is 0.94 em wide, measured with vla-GetBoundingBox - not
// the 0.62 that was assumed here for months (GOLDEN_RULES 37).  Under-reporting every string's
// width by half again is exactly why "checked for clashes" kept coming back clean on sheets that
// clashed.  Anything narrower than the truth turns this tool into a rubber stamp.
//
// Rotation is handled properly (several PD labels sit at 90 deg) with a separating-axis test on
// the two oriented boxes, not on their axis-aligned hulls - an AABB test calls every 90-degree
// label a clash with its neighbours and buries the real ones.

const fs = require('fs');

const EM = 0.94;          // romand character width, in ems — MEASURED, see above
const LINE = 1.55;        // line pitch as a multiple of the text height, for wrapped MTEXT

const file = process.argv[2];
const showAll = process.argv.includes('--all');
const mi = process.argv.indexOf('--min');
const MINAREA = mi > 0 ? parseFloat(process.argv[mi + 1]) : 0;
// --gap <f>: require f x text-height of CLEAR AIR around every string, not merely
// non-overlap.  Two labels that miss each other by 8 units out of a 550 height are
// touching as far as a reader is concerned, and S57 says a clearance is measured from
// the height of the text it has to clear.  0 = strict overlap only.
const gi = process.argv.indexOf('--gap');
const GAP = gi > 0 ? parseFloat(process.argv[gi + 1]) : 0;

// ── read the DXF into entities ────────────────────────────────────────────────────────────────
const L = fs.readFileSync(file, 'latin1').split(/\r?\n/);
const ents = [];
let cur = null;
for (let i = 0; i + 1 < L.length; i += 2) {
  const code = L[i].trim();
  const val = L[i + 1];
  if (code === '0') {
    if (cur) ents.push(cur);
    cur = { t: val.trim(), g: {} };
  } else if (cur) {
    // keep the FIRST 10/20 (the insert point); 11/21 is the alignment point.
    // Group 3 is the EXCEPTION - an MTEXT over 250 characters carries several of them and they
    // all belong to the string, so 3 accumulates instead of first-wins.  It has to be excluded
    // from the first-wins line too, or the opening chunk is stored once and then appended again,
    // doubling the first 250 characters.  That made the GENERAL NOTES block measure half again
    // too tall and invent a clash with the statement below it.
    if (code !== '3' && !(code in cur.g)) cur.g[code] = val;
    if (code === '3') cur.g['3'] = (cur.g['3'] || '') + val;   // MTEXT continuation chunks
  }
}
if (cur) ents.push(cur);

// ── strip MTEXT formatting so the width is the width of what a reader sees ────────────────────
function plain(s) {
  if (!s) return '';
  return s
    .replace(/\\[Ff][^;]*;/g, '')       // font switches  \Fromand.shx;
    .replace(/\\[HWQTApChfKkLlOoXx][^;\\]*;?/g, '')
    .replace(/\\P/g, '\n')              // hard line break
    .replace(/[{}]/g, '')
    .replace(/\\\\/g, '\\')
    .trim();
}

// ── an oriented box for one text entity ───────────────────────────────────────────────────────
function boxOf(e) {
  const n = (k, d) => (k in e.g ? parseFloat(e.g[k]) : d);
  const h = n('40', 0);
  if (!(h > 0)) return null;
  // MTEXT over 250 characters is split: group 3 carries the leading chunks and group 1 the
  // rest.  But some entities here also carry the WHOLE string in group 1, and blindly
  // concatenating then counts the opening 250 characters twice - which made the GENERAL NOTES
  // block measure half again too tall and report a clash with the statement below it that a
  // look at the sheet does not show.  A checker that invents clashes gets ignored, so: if
  // group 1 already starts where group 3 starts, group 1 is the whole text.
  // MTEXT over 250 characters is split: group 3 carries the leading chunks, group 1 the rest.
  let txt = plain(e.t === 'MTEXT' ? (e.g['3'] || '') + (e.g['1'] || '') : e.g['1'] || '');
  if (!txt) return null;
  const lines = txt.split('\n');
  const cols = Math.max.apply(null, lines.map((s) => s.length));
  const w = cols * h * EM;
  const hgt = lines.length === 1 ? h : (lines.length - 1) * h * LINE + h;
  // ROTATION.  Group 50 for TEXT - but an MTEXT may instead carry its X-AXIS DIRECTION VECTOR
  // in 11/21, which wins.  Every vertical dimension string on the CLP is written that way
  // (50 absent, 11/21 = 0,1 = straight up), and reading them as horizontal made two dimension
  // texts that sit side by side up the left of the sheet look like a 93% collision.  Note this
  // is the OPPOSITE meaning of group 11 on a TEXT, where it is the alignment point.
  let rot = (n('50', 0) * Math.PI) / 180;
  if (e.t === 'MTEXT' && ('11' in e.g)) {
    const vx = n('11', 1), vy = n('21', 0);
    if (Math.hypot(vx, vy) > 1e-9) rot = Math.atan2(vy, vx);
  }

  // anchor -> the box's lower-left in text space
  let ax = n('10', 0), ay = n('20', 0);
  let dx = 0, dy = 0;
  if (e.t === 'MTEXT') {
    const at = n('71', 1);                        // 1..9, TL TC TR ML MC MR BL BC BR
    const col = (at - 1) % 3, row = Math.floor((at - 1) / 3);
    dx = -w * (col / 2);
    dy = row === 0 ? -hgt : row === 1 ? -hgt / 2 : 0;
  } else {
    const hj = n('72', 0), vj = n('73', 0);
    // a justified TEXT measures from group 11, not 10
    if (hj !== 0 || vj !== 0) { ax = n('11', ax); ay = n('21', ay); }
    dx = -w * (hj === 1 ? 0.5 : hj === 2 || hj === 4 ? 1 : 0);
    dy = -hgt * (vj === 3 ? 1 : vj === 2 ? 0.5 : 0);
  }
  const c = Math.cos(rot), s = Math.sin(rot);
  const pad = GAP * h;
  const corner = (u, v) => [ax + (dx + u) * c - (dy + v) * s, ay + (dx + u) * s + (dy + v) * c];
  return {
    txt: lines.join(' / '), lay: e.g['8'] || '?', h,
    pts: [corner(-pad, -pad), corner(w + pad, -pad), corner(w + pad, hgt + pad), corner(-pad, hgt + pad)],
    w, hgt,
  };
}

// ── separating-axis overlap of two convex quads, and the overlap area ─────────────────────────
function axes(p) {
  const a = [];
  for (let i = 0; i < p.length; i++) {
    const q = p[(i + 1) % p.length];
    a.push([-(q[1] - p[i][1]), q[0] - p[i][0]]);
  }
  return a;
}
function overlaps(A, B) {
  for (const poly of [A, B]) {
    for (const ax of axes(poly)) {
      const len = Math.hypot(ax[0], ax[1]) || 1;
      const n = [ax[0] / len, ax[1] / len];
      let a0 = 1e18, a1 = -1e18, b0 = 1e18, b1 = -1e18;
      A.forEach((p) => { const d = p[0] * n[0] + p[1] * n[1]; a0 = Math.min(a0, d); a1 = Math.max(a1, d); });
      B.forEach((p) => { const d = p[0] * n[0] + p[1] * n[1]; b0 = Math.min(b0, d); b1 = Math.max(b1, d); });
      if (a1 <= b0 + 1e-9 || b1 <= a0 + 1e-9) return false;
    }
  }
  return true;
}
// Sutherland–Hodgman clip, for how BADLY they overlap
function clipArea(A, B) {
  let out = A.slice();
  for (let i = 0; i < B.length && out.length; i++) {
    const p = B[i], q = B[(i + 1) % B.length];
    const nx = -(q[1] - p[1]), ny = q[0] - p[0];
    const side = (r) => (r[0] - p[0]) * nx + (r[1] - p[1]) * ny;
    const inp = out; out = [];
    for (let k = 0; k < inp.length; k++) {
      const c = inp[k], d = inp[(k + 1) % inp.length];
      const sc = side(c), sd = side(d);
      if (sc >= 0) out.push(c);
      if ((sc >= 0) !== (sd >= 0)) {
        const t = sc / (sc - sd);
        out.push([c[0] + (d[0] - c[0]) * t, c[1] + (d[1] - c[1]) * t]);
      }
    }
  }
  let a = 0;
  for (let i = 0; i < out.length; i++) {
    const p = out[i], q = out[(i + 1) % out.length];
    a += p[0] * q[1] - q[0] * p[1];
  }
  return Math.abs(a) / 2;
}

// ── run ───────────────────────────────────────────────────────────────────────────────────────
const boxes = ents.filter((e) => e.t === 'TEXT' || e.t === 'MTEXT').map(boxOf).filter(Boolean);
const hits = [];
for (let i = 0; i < boxes.length; i++) {
  for (let j = i + 1; j < boxes.length; j++) {
    // A MASK RE-ASSERT IS NOT A CLASH.  Some labels are drawn twice on purpose: the AREA
    // tag is laid down early so the corner diagonals can terminate on real box corners, then
    // re-drawn last over a WIPEOUT because the grid and ridge lines are drawn after it and
    // would otherwise strike through the lettering (peb-fr-masked-label, owner 29-Jul).  The
    // second copy lands exactly on the first, and the reader sees ONE label.  Identical string
    // at an identical anchor and height is that pattern, not two labels fighting.
    if (boxes[i].txt === boxes[j].txt && boxes[i].h === boxes[j].h &&
        Math.abs(boxes[i].pts[0][0] - boxes[j].pts[0][0]) < 1e-6 &&
        Math.abs(boxes[i].pts[0][1] - boxes[j].pts[0][1]) < 1e-6) continue;
    if (!overlaps(boxes[i].pts, boxes[j].pts)) continue;
    const a = clipArea(boxes[i].pts, boxes[j].pts);
    const frac = a / Math.min(boxes[i].w * boxes[i].hgt, boxes[j].w * boxes[j].hgt);
    if (a <= MINAREA) continue;
    hits.push({ a, frac, x: boxes[i].pts[0][0], y: boxes[i].pts[0][1], A: boxes[i], B: boxes[j] });
  }
}
hits.sort((p, q) => q.frac - p.frac);

console.log(`${file}`);
console.log(`  texts: ${boxes.length}   overlapping pairs: ${hits.length}`);
const show = showAll ? hits : hits.slice(0, 25);
show.forEach((h) => {
  console.log(
    `  ${(h.frac * 100).toFixed(0).padStart(3)}%  at ${h.x.toFixed(0)},${h.y.toFixed(0)}\n` +
    `        "${h.A.txt}"  [${h.A.lay}]\n` +
    `        "${h.B.txt}"  [${h.B.lay}]`
  );
});
if (!showAll && hits.length > show.length) console.log(`  ... ${hits.length - show.length} more (--all)`);
process.exitCode = hits.length ? 1 : 0;
