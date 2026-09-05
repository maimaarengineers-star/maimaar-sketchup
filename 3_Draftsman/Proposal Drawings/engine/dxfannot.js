'use strict';
// dxfannot.js — read a model DXF and return every piece of ANNOTATION as an oriented box.
//
// Shared by textclash.js (annotation vs annotation) and textgeom.js (annotation vs geometry).
// It is one module on purpose: the two checkers have to agree about what a label's box IS, and
// this engine has been bitten twice in one day by two copies of the same arithmetic drifting
// apart — the crane levels computed in two places, and Section.lsp's txt* helpers shadowed by
// Plan.lsp's. A checker that measures differently from its sibling is that same bug in a tool.
//
// WHAT COUNTS AS ANNOTATION, and where this engine actually puts it:
//
//   TEXT / MTEXT          labels, notes, hand-built dimension text        top level
//   MTEXT in a *D block   native _DIMLINEAR text                          block definition
//   MULTILEADER           M-Ladder / leader notes                         CONTEXT_DATA
//
// The middle one is a trap worth stating. A flat read of a DXF walks straight through the BLOCKS
// section, so block-definition entities arrive looking like drawn ones. For a dimension's
// anonymous *D block that happens to be RIGHT — AutoCAD writes its text at real world coordinates
// and at the real plotted height — which is why native dimension text has been getting checked
// all along without anyone meaning it to be. For any OTHER block it is wrong: that geometry is in
// block space and means nothing until the INSERT's transform is applied. So *D blocks are kept,
// every other block is dropped, and the number dropped is reported, so a block that starts
// carrying text cannot slip past unnoticed.
//
// The last one is why "0 clashes" was wrong. An MLEADER is neither TEXT nor MTEXT, so a checker
// filtering on those two types cannot see it — and the ROOF SHEETING / WALL SHEETING notes that
// have been printing through each other on PRO-02 are MLEADERs.

const fs = require('fs');

// ROMAND advance width as a fraction of cap height. MEASURED with vla-GetBoundingBox
// (GOLDEN_RULES 37); it is NOT the 0.62 that was assumed here for months. Under-reporting every
// string's width by half again is precisely why "checked for clashes" kept coming back clean on
// sheets that clashed. Anything narrower than the truth turns these tools into a rubber stamp.
const EM = 0.94;
const LINE = 1.55;        // line pitch as a multiple of text height, for wrapped MTEXT

// ── read ──────────────────────────────────────────────────────────────────────────────────────
function readDxf(file) {
  const L = fs.readFileSync(file, 'latin1').split(/\r?\n/);
  const ents = [];
  let cur = null, inBlock = null;
  for (let i = 0; i + 1 < L.length; i += 2) {
    const code = L[i].trim();
    const val = L[i + 1];
    if (code === '0') {
      if (cur) ents.push(cur);
      const t = val.trim();
      if (cur && cur.t === 'BLOCK') inBlock = cur.g['2'] || null;
      if (t === 'ENDBLK') inBlock = null;
      cur = { t, g: {}, all: [], pts: [], blk: inBlock };
    } else if (cur) {
      cur.all.push([code, val.trim()]);
      // Group 3 is the EXCEPTION to first-wins: an MTEXT over 250 characters carries several of
      // them and they all belong to the string. It must be excluded from the first-wins line too,
      // or the opening chunk is stored once and then appended again — which made the GENERAL
      // NOTES block measure half again too tall and invent a clash with the statement below it.
      if (code !== '3' && !(code in cur.g)) cur.g[code] = val;
      if (code === '3') cur.g['3'] = (cur.g['3'] || '') + val;
      const f = parseFloat(val);
      if (code === '10') cur.pts.push([f, null]);
      if (code === '20' && cur.pts.length) cur.pts[cur.pts.length - 1][1] = f;
    }
  }
  if (cur) ents.push(cur);
  return ents;
}

// ── strip MTEXT formatting so a width is the width of what a reader actually sees ─────────────
function plain(s) {
  if (!s) return '';
  return s
    .replace(/\\[Ff][^;]*;/g, '')
    .replace(/\\[HWQTApChfKkLlOoXxC][^;\\]*;?/g, '')
    .replace(/\\P/g, '\n')
    .replace(/[{}]/g, '')
    .replace(/\\\\/g, '\\')
    .trim();
}

// ── a TEXT / MTEXT box ────────────────────────────────────────────────────────────────────────
function boxOf(e, GAP) {
  const n = (k, d) => (k in e.g ? parseFloat(e.g[k]) : d);
  const h = n('40', 0);
  if (!(h > 0)) return null;
  const txt = plain(e.t === 'MTEXT' ? (e.g['3'] || '') + (e.g['1'] || '') : e.g['1'] || '');
  if (!txt) return null;
  const lines = txt.split('\n');
  const cols = Math.max.apply(null, lines.map((s) => s.length));
  const w = cols * h * EM;
  const hgt = lines.length === 1 ? h : (lines.length - 1) * h * LINE + h;

  // ROTATION. Group 50 for a TEXT — but an MTEXT may instead carry its X-AXIS DIRECTION VECTOR in
  // 11/21, which wins. Every vertical dimension string on the CLP is written that way (50 absent,
  // 11/21 = 0,1 = straight up); read those as horizontal and two dimension texts standing side by
  // side up the left of the sheet report as a 93% collision. This is the OPPOSITE meaning of group
  // 11 on a TEXT, where it is the alignment point.
  let rot = (n('50', 0) * Math.PI) / 180;
  if (e.t === 'MTEXT' && ('11' in e.g)) {
    const vx = n('11', 1), vy = n('21', 0);
    if (Math.hypot(vx, vy) > 1e-9) rot = Math.atan2(vy, vx);
  }

  let ax = n('10', 0), ay = n('20', 0);
  let dx = 0, dy = 0;
  if (e.t === 'MTEXT') {
    const at = n('71', 1);                     // 1..9, TL TC TR ML MC MR BL BC BR
    const col = (at - 1) % 3, row = Math.floor((at - 1) / 3);
    dx = -w * (col / 2);
    dy = row === 0 ? -hgt : row === 1 ? -hgt / 2 : 0;
  } else {
    const hj = n('72', 0), vj = n('73', 0);
    if (hj !== 0 || vj !== 0) { ax = n('11', ax); ay = n('21', ay); }   // justified TEXT measures from 11
    dx = -w * (hj === 1 ? 0.5 : hj === 2 || hj === 4 ? 1 : 0);
    dy = -hgt * (vj === 3 ? 1 : vj === 2 ? 0.5 : 0);
  }
  const c = Math.cos(rot), s = Math.sin(rot);
  const pad = (GAP || 0) * h;
  const corner = (u, v) => [ax + (dx + u) * c - (dy + v) * s, ay + (dx + u) * s + (dy + v) * c];
  const kind = (e.blk && /^\*D/i.test(e.blk)) ? 'dim'
             : (e.g['8'] === 'DIMENSIONS') ? 'dim' : 'label';
  return {
    txt: lines.join(' / '), lay: e.g['8'] || '?', h, kind, rot,
    pts: [corner(-pad, -pad), corner(w + pad, -pad), corner(w + pad, hgt + pad), corner(-pad, hgt + pad)],
    w, hgt,
  };
}

// ── an MLEADER box ────────────────────────────────────────────────────────────────────────────
function mleaderBox(e, GAP) {
  const ctx = e.all.findIndex((a) => a[0] === '300' && a[1] === 'CONTEXT_DATA{');
  if (ctx < 0) return null;
  let bx = null, by = null, h = 0, txt = null, att = 5;
  for (let i = ctx + 1; i < e.all.length; i++) {
    const c = e.all[i][0], v = e.all[i][1];
    if (c === '302' && v === 'LEADER{') break;      // past the content, into the leader itself
    if (c === '10' && bx === null) bx = parseFloat(v);
    if (c === '20' && by === null) by = parseFloat(v);
    if (c === '41' && !h) h = parseFloat(v);
    if (c === '304' && txt === null) txt = v;
    if (c === '172') att = parseInt(v, 10) || 5;
  }
  if (txt === null || !(h > 0) || bx === null || by === null) return null;
  // An inline \H0.42x; scales the run it introduces. Take the first, which is what the heading
  // line is set in; without it the box is reported at more than twice its real height.
  const hf = /\\H([0-9.]+)x;/.exec(txt);
  const eff = h * (hf ? parseFloat(hf[1]) : 1);
  const lines = plain(txt).split('\n');
  const cols = Math.max.apply(null, lines.map((z) => z.length));
  const w = cols * eff * EM;
  const hgt = lines.length === 1 ? eff : (lines.length - 1) * eff * LINE + eff;
  const col = (att - 1) % 3, row = Math.floor((att - 1) / 3);
  const dx = -w * (col / 2), dy = row === 0 ? -hgt : row === 1 ? -hgt / 2 : 0;
  const pad = (GAP || 0) * eff;
  return {
    txt: lines.join(' / '), lay: e.g['8'] || '?', h: eff, kind: 'mladder', rot: 0,
    pts: [[bx + dx - pad, by + dy - pad], [bx + dx + w + pad, by + dy - pad],
          [bx + dx + w + pad, by + dy + hgt + pad], [bx + dx - pad, by + dy + hgt + pad]],
    w, hgt,
  };
}

// ── every annotation box in the drawing ───────────────────────────────────────────────────────
function annotationBoxes(ents, GAP) {
  let skippedInBlocks = 0;
  const text = ents.filter((e) => {
    if (e.t !== 'TEXT' && e.t !== 'MTEXT') return false;
    if (e.blk && !/^\*D/i.test(e.blk)) { skippedInBlocks++; return false; }
    return true;
  }).map((e) => boxOf(e, GAP)).filter(Boolean);
  const mleaders = ents.filter((e) => e.t === 'MULTILEADER' || e.t === 'MLEADER')
                       .map((e) => mleaderBox(e, GAP)).filter(Boolean);
  return { boxes: text.concat(mleaders), nText: text.length, nMleader: mleaders.length, skippedInBlocks };
}

// ── oriented-box overlap, and how badly ───────────────────────────────────────────────────────
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
      const len = Math.hypot(ax[0], ax[1]);
      if (len < 1e-12) continue;                 // a degenerate edge yields no separating axis
      const n = [ax[0] / len, ax[1] / len];
      let a0 = 1e18, a1 = -1e18, b0 = 1e18, b1 = -1e18;
      A.forEach((p) => { const d = p[0] * n[0] + p[1] * n[1]; a0 = Math.min(a0, d); a1 = Math.max(a1, d); });
      B.forEach((p) => { const d = p[0] * n[0] + p[1] * n[1]; b0 = Math.min(b0, d); b1 = Math.max(b1, d); });
      if (a1 <= b0 + 1e-9 || b1 <= a0 + 1e-9) return false;
    }
  }
  return true;
}
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

// ── point-in-box and segment-vs-box, for the geometry checker ─────────────────────────────────
// NOT via the SAT above.  A segment expressed as a degenerate quad gives that routine two
// zero-length edge normals, and a zero normal projects everything onto 0, so the very first
// separating-axis test "succeeds" and every segment is reported as MISSING the box.  That is how
// the first run of textgeom.js reported 0 labels with lines through them on a drawing where 33
// were measured by hand.  Exact segment arithmetic instead - no normalisation, nothing to
// degenerate.
function pointInBox(p, poly) {
  // convex quad: the point is inside if it is on the same side of every edge
  let neg = false, pos = false;
  for (let i = 0; i < poly.length; i++) {
    const a = poly[i], b = poly[(i + 1) % poly.length];
    const d = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]);
    if (d < -1e-9) neg = true;
    if (d > 1e-9) pos = true;
    if (neg && pos) return false;
  }
  return true;
}
function segSeg(p1, p2, p3, p4) {
  const d = (x, y, z) => (y[0] - x[0]) * (z[1] - x[1]) - (y[1] - x[1]) * (z[0] - x[0]);
  const d1 = d(p3, p4, p1), d2 = d(p3, p4, p2), d3 = d(p1, p2, p3), d4 = d(p1, p2, p4);
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) return true;
  return false;
}
function segHitsBox(seg, box) {
  const xs = box.pts.map((p) => p[0]), ys = box.pts.map((p) => p[1]);
  if (Math.max(seg[0], seg[2]) < Math.min.apply(null, xs)) return false;
  if (Math.min(seg[0], seg[2]) > Math.max.apply(null, xs)) return false;
  if (Math.max(seg[1], seg[3]) < Math.min.apply(null, ys)) return false;
  if (Math.min(seg[1], seg[3]) > Math.max.apply(null, ys)) return false;
  const p1 = [seg[0], seg[1]], p2 = [seg[2], seg[3]];
  if (pointInBox(p1, box.pts) || pointInBox(p2, box.pts)) return true;
  for (let i = 0; i < box.pts.length; i++)
    if (segSeg(p1, p2, box.pts[i], box.pts[(i + 1) % box.pts.length])) return true;
  return false;
}

module.exports = {
  EM, LINE, readDxf, plain, boxOf, mleaderBox, annotationBoxes, overlaps, clipArea,
  segHitsBox, pointInBox,
};
