'use strict';
// textgeom.js — find ANNOTATION with drawing GEOMETRY running through it, in a model DXF.
//
//   node textgeom.js <file.dxf> [--all] [--min <n>] [--layer <name>]
//
// The other half of the owner's rule (5-Sep-2026): "No Override of Text and Labells and MLadders
// and Dim."  textclash.js answers "does a label print on another label"; this answers "does a
// COLUMN line, a grid line, a runway beam or a dimension line print through the lettering."
// Standing rule S64: a label must not land on geometry.
//
// Measured on MSPL-26-276 before any fix: 33 of 196 drawing labels had geometry through them —
// HIGH EAVE, LOW EAVE, CRANE RUN LENGTH, the girt / purlin / sheeting notes.  CLP 27%, section
// 31%.  None of it was visible to any existing checker.
//
// THE FIX IS TO MOVE THE LABEL, NOT TO MASK IT (owner's ruling, 5-Sep).  That is also what this
// engine's own history says: peb-fr-masked-label had its WIPEOUT removed on 4-Sep — "side walls
// elevations are showing Box" — because a wipeout plots as a pale grey rectangle on a monochrome
// plot.  Masking is not available to us; only the AREA-tag re-assert still uses it, deliberately.
//
// WHAT IS NOT A HIT.  A label's OWN leader is supposed to touch it, and a dimension's text sits
// on its own dimension line by construction.  Both are excluded, or the report is all noise:
//   - a segment with an endpoint inside the box is a leader landing on its label
//   - anything on a dimension layer is skipped for a box whose kind is 'dim'
// Everything else — a member line, a grid line, cladding, bracing — is a real hit.

const path = require('path');
const A = require(path.join(__dirname, 'dxfannot.js'));

const file = process.argv[2];
const showAll = process.argv.includes('--all');
const mi = process.argv.indexOf('--min');
const MIN = mi > 0 ? parseInt(process.argv[mi + 1], 10) : 1;
const li = process.argv.indexOf('--layer');
const ONLY = li > 0 ? process.argv[li + 1] : null;

if (!file) {
  console.error('usage: node textgeom.js <file.dxf> [--all] [--min <n>] [--layer <name>]');
  process.exit(2);
}

// Layers that are paper furniture rather than the drawing: the title block draws at paper scale
// in its own coordinate space, so its rules and cell borders are not "geometry through a label".
const FURNITURE = new Set(['0', 'BORDER', 'Outer Line', 'DEFPOINTS']);

const ents = A.readDxf(file);
const { boxes } = A.annotationBoxes(ents, 0);
const labels = boxes.filter((b) => !FURNITURE.has(b.lay));

// every drawn segment on a real drawing layer
const segs = [];
ents.forEach((e) => {
  const lay = e.g['8'];
  if (!lay || FURNITURE.has(lay)) return;
  if (e.blk) return;                       // block-space geometry needs the INSERT transform
  if (ONLY && lay !== ONLY) return;
  if (e.t === 'LINE') {
    const x1 = parseFloat(e.g['11']), y1 = parseFloat(e.g['21']);
    if (e.pts.length && e.pts[0][1] != null && isFinite(x1) && isFinite(y1))
      segs.push([e.pts[0][0], e.pts[0][1], x1, y1, lay]);
  } else if (e.t === 'LWPOLYLINE' || e.t === 'POLYLINE') {
    for (let k = 0; k + 1 < e.pts.length; k++)
      if (e.pts[k][1] != null && e.pts[k + 1][1] != null)
        segs.push([e.pts[k][0], e.pts[k][1], e.pts[k + 1][0], e.pts[k + 1][1], lay]);
  } else if (e.t === 'CIRCLE' || e.t === 'ARC') {
    // approximate as a 24-gon; a grid bubble crossing a label matters as much as a line does
    const cx = e.pts.length ? e.pts[0][0] : NaN, cy = e.pts.length ? e.pts[0][1] : NaN;
    const r = parseFloat(e.g['40']);
    if (!isFinite(cx) || !isFinite(cy) || !(r > 0)) return;
    const a0 = e.t === 'ARC' ? parseFloat(e.g['50']) * Math.PI / 180 : 0;
    const a1 = e.t === 'ARC' ? parseFloat(e.g['51']) * Math.PI / 180 : Math.PI * 2;
    let span = a1 - a0; if (span <= 0) span += Math.PI * 2;
    const n = 24;
    for (let k = 0; k < n; k++) {
      const t0 = a0 + span * (k / n), t1 = a0 + span * ((k + 1) / n);
      segs.push([cx + r * Math.cos(t0), cy + r * Math.sin(t0),
                 cx + r * Math.cos(t1), cy + r * Math.sin(t1), lay]);
    }
  }
});

// ── THE ONE LEGITIMATE MASK ───────────────────────────────────────────────────────────────────
// A WIPEOUT punches an opaque hole in whatever was drawn BEFORE it, so a label sitting on one has
// clear paper under it however many lines cross that spot. Only one label in the engine still
// works this way - the AREA tag, re-asserted last over a wipeout because the grid and ridge lines
// are drawn after it (Plan.lsp, owner 27-Aug audit). Everywhere else the wipeout was removed on
// 4-Sep: it plots as a pale grey rectangle on a monochrome sheet ("side walls elevations are
// showing Box"). So this exemption should stay rare - if it starts covering many labels, someone
// has reintroduced masking and that is its own defect.
// A WIPEOUT does not store its outline in world coordinates. It stores an insertion point
// (10/20), a U vector (11/21), a V vector (12/22) and the clip boundary as NORMALISED vertices
// (14/24) in the range -0.5..+0.5 - with V running the other way, so the mapping is
//     P = insertion + U * (u + 0.5) + V * (0.5 - v)
// Verified against the AREA tag on MSPL-26-276: the box comes out at x 121,457..126,159,
// y 8,674..9,616, which is exactly where "AREA NO. 01" sits.
const wipeouts = ents.filter((e) => e.t === 'WIPEOUT').map((e) => {
  const num = (k, i) => { const m = e.all.filter((a) => a[0] === k); return m[i] ? parseFloat(m[i][1]) : NaN; };
  const ox = num('10', 0), oy = num('20', 0);
  const ux = num('11', 0), uy = num('21', 0);
  const vx = num('12', 0), vy = num('22', 0);
  if (![ox, oy, ux, uy, vx, vy].every(isFinite)) return null;
  const us = e.all.filter((a) => a[0] === '14').map((a) => parseFloat(a[1]));
  const vs = e.all.filter((a) => a[0] === '24').map((a) => parseFloat(a[1]));
  const n = Math.min(us.length, vs.length);
  if (n < 3) return null;
  const poly = [];
  for (let i = 0; i < n; i++)
    poly.push([ox + ux * (us[i] + 0.5) + vx * (0.5 - vs[i]),
               oy + uy * (us[i] + 0.5) + vy * (0.5 - vs[i])]);
  return poly;
}).filter(Boolean);
function masked(b) {
  const cx = b.pts.reduce((s, p) => s + p[0], 0) / b.pts.length;
  const cy = b.pts.reduce((s, p) => s + p[1], 0) / b.pts.length;
  return wipeouts.some((w) => {
    let inside = false;
    for (let i = 0, j = w.length - 1; i < w.length; j = i++) {
      if ((w[i][1] > cy) !== (w[j][1] > cy) &&
          cx < (w[j][0] - w[i][0]) * (cy - w[i][1]) / (w[j][1] - w[i][1]) + w[i][0]) inside = !inside;
    }
    return inside;
  });
}

const hits = [];
let maskedOut = 0;
labels.forEach((b) => {
  if (masked(b)) { maskedOut++; return; }
  const through = [];
  for (const s of segs) {
    if (b.kind === 'dim' && /DIM/i.test(s[4])) continue;          // a dimension's own line
    if (!A.segHitsBox(s, b)) continue;
    // a leader that LANDS on its label has an endpoint inside the box; a line that runs THROUGH
    // it enters and leaves. Only the second is a defect.
    if (A.pointInBox([s[0], s[1]], b.pts) || A.pointInBox([s[2], s[3]], b.pts)) continue;
    through.push(s[4]);
    if (through.length > 6) break;
  }
  if (through.length >= MIN) hits.push({ n: through.length, lay: [...new Set(through)].join(','), b });
});
hits.sort((p, q) => q.n - p.n);

console.log(`${file}`);
console.log(`  labels: ${labels.length}   with geometry through them: ${hits.length}` +
            `   (${(100 * hits.length / (labels.length || 1)).toFixed(0)}%)` +
            (maskedOut ? `   [${maskedOut} exempt: masked by a WIPEOUT]` : ''));
const show = showAll ? hits : hits.slice(0, 30);
show.forEach((h) => {
  console.log(`  ${String(h.n).padStart(2)} line(s) [${h.lay}]  through  ` +
              `"${h.b.txt.slice(0, 46)}"  [${h.b.kind}/${h.b.lay}]  at ` +
              `${h.b.pts[0][0].toFixed(0)},${h.b.pts[0][1].toFixed(0)}`);
});
if (!showAll && hits.length > show.length) console.log(`  ... ${hits.length - show.length} more (--all)`);
process.exitCode = hits.length ? 1 : 0;
