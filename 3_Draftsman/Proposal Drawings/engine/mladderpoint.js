'use strict';
// mladderpoint.js - does each M-Ladder arrow actually land on the member it names?
//
//   node mladderpoint.js <file.dxf> [--all] [--tol <units>]
//
// GOLDEN RULE (owner, 5-Sep-2026): "MLadder arrow must point to that member for which this MLadder
// is being used. For example if MLadder is showing the Girts, it should point out the Girt."
//
// WHY THIS NEEDS MEASURING RATHER THAN READING. An M-Ladder is a leader: the code hands it a tip
// coordinate and a string, and nothing connects the two. The tip is computed from the building
// geometry - eave height plus purlin depth plus cladding thickness, that sort of thing - so it
// drifts the moment any of those change, and it drifts SILENTLY. The label still says GIRT; the
// arrow just quietly lands on a purlin, or in fresh air two metres below the member. Reading the
// source tells you what the author intended, not where the arrow went.
//
// So this reads the rendered DXF, takes each leader's ARROW TIP, and asks what is actually under
// it. If the nearest geometry is not on a layer the label's own words imply, that is a violation.
//
// WHAT COUNTS AS THE RIGHT LAYER. Taken from the words in the label, because that is what a reader
// goes by. "GIRT" -> GIRTS, "PURLIN" -> PURLINS, "ROOF SHEETING" -> SHEETING/CLADDING, and so on.
// A label naming nothing in the map is reported as UNMAPPED rather than passed: silence on a label
// this cannot classify would make the check look cleaner than it is.
//
// TOLERANCE. An arrowhead has size, and a leader is meant to touch its member rather than bury
// itself in it, so "on" means within --tol of some geometry on the expected layer. Default 250
// model units, about one arrowhead. A tip further than that from anything at all is reported as
// POINTING AT NOTHING, which is the failure the reference photo in Library/Overhead Crane calls
// out ("MLadder Arrow Should Touch the Rafter").

const path = require('path');
const A = require(path.join(__dirname, 'dxfannot.js'));

const file = process.argv[2];
const showAll = process.argv.includes('--all');
const ti = process.argv.indexOf('--tol');
const TOL = ti > 0 ? parseFloat(process.argv[ti + 1]) : 250;
if (!file) { console.error('usage: node mladderpoint.js <file.dxf> [--all] [--tol <units>]'); process.exit(2); }

// WHAT THE ARROW MUST TOUCH, AND WHAT IT SHOULD BE.
//
// THE MAP IS READ OFF THE DRAWING, not invented. My first version assumed each member sits on an
// eponymous layer - GIRT on GIRTS, RAFTER on RAFTER - and reported "nearest girt 49,272 units away"
// on labels that were perfectly placed. There is no RAFTER layer at all; rafters are STRUCTURE, a
// column can be COLUMNS or COL-OUTER, and on the cross-section the girt is drawn inside the wall
// assembly on CLADDING. Layer names checked against the rendered DXF, not guessed from the word.
//
// TWO QUESTIONS, IN ORDER OF HOW MUCH I TRUST THE ANSWER:
//
//  1. DOES THE ARROW TOUCH ANYTHING AT ALL? This needs no map and cannot be argued with. It is
//     also the failure the reference photo names - "MLadder Arrow Should Touch the Rafter" - and
//     the one that actually looks wrong on paper: an arrow floating two metres off its member.
//     THIS is what fails the run.
//
//  2. IS THE THING IT TOUCHES THE RIGHT MEMBER? Reported, not enforced, because the map is a
//     judgement about how this engine draws and I would rather show the layer and the distance and
//     let a person decide than fail a build on my reading of it.
// WRITTEN OUT WITH REAL \b WORD BOUNDARIES. The previous version of this array reached the file
// through a NON-RAW Python string, which turned every \b into a literal BACKSPACE byte (0x08): the
// patterns looked correct in a diff, matched nothing at all, and the checker cheerfully reported
// "2 of 2 touch their member" on a drawing carrying fifteen more callouts. The same trap cost a
// regex earlier in this session. It is invisible precisely because a backspace prints as nothing.
const EXPECT = [
  [/\bGIRTS?\b/i,                     /^(GIRTS|CLADDING)$/i],
  [/\bPURLINS?\b/i,                   /^PURLINS$/i],
  [/\bSHEETING\b|\bCLADDING\b/i,      /^(SHEETING|CLADDING)$/i],
  [/\bRAFTERS?\b/i,                   /^(STRUCTURE|FRAME|COLUMNS|COL-OUTER)$/i],
  [/\bCOLUMNS?\b/i,                   /^(COLUMNS|COL-OUTER|STRUCTURE|FRAME)$/i],
  [/\bGUTTER\b/i,                     /^(GUTTER|CLADDING|SHEETING)$/i],
  [/\bDOWN ?PIPE\b|\bDOWN ?SPOUT\b/i, /^(GUTTER|CLADDING|SHEETING)$/i],
  [/\bBRACING\b|\bBRACE\b/i,          /^(CROSS|BRACING)$/i],
  [/\bINSULATION\b/i,                 /^(CLADDING|SHEETING)$/i],
  [/\bCRANE\b/i,                      /^COMP-CRANE/i],
  [/\bBASE PLATE\b|\bANCHOR\b/i,      /^(PLATES|BOLTS|STRUCTURE|FRAME)$/i],
];

function expectedFor(txt) {
  for (const [word, lay] of EXPECT) if (word.test(txt)) return lay;
  return null;
}

const ents = A.readDxf(file);

// Every drawable segment, with its layer - the same shape textgeom builds.
const segs = [];
for (const e of ents) {
  const lay = e.g['8'] || '?';
  if (e.t === 'LINE') {
    const x1 = +e.g['10'], y1 = +e.g['20'], x2 = +e.g['11'], y2 = +e.g['21'];
    if ([x1, y1, x2, y2].every(Number.isFinite)) segs.push([x1, y1, x2, y2, lay]);
  } else if (e.t === 'LWPOLYLINE' || e.t === 'POLYLINE') {
    const xs = e.all && e.all['10'] ? e.all['10'].map(Number) : [];
    const ys = e.all && e.all['20'] ? e.all['20'].map(Number) : [];
    for (let i = 1; i < Math.min(xs.length, ys.length); i++) {
      if ([xs[i - 1], ys[i - 1], xs[i], ys[i]].every(Number.isFinite)) {
        segs.push([xs[i - 1], ys[i - 1], xs[i], ys[i], lay]);
      }
    }
  }
}

// distance from a point to a segment
function dist(px, py, s) {
  const [x1, y1, x2, y2] = s;
  const dx = x2 - x1, dy = y2 - y1;
  const L2 = dx * dx + dy * dy;
  let t = L2 > 0 ? ((px - x1) * dx + (py - y1) * dy) / L2 : 0;
  t = Math.max(0, Math.min(1, t));
  const qx = x1 + t * dx, qy = y1 + t * dy;
  return Math.hypot(px - qx, py - qy);
}

// THE ARROW TIP IS THE FIRST POINT INSIDE LEADER_LINE{, and nowhere else.
//
// e.all is an ORDERED ARRAY of [code, value] pairs, not a map keyed by group code - reading it as
// a map is how the first version of this checker ended up measuring from the wrong coordinate and
// confidently reporting that the nearest cladding was 108 metres away. The structure is:
//
//   [300] CONTEXT_DATA{            content: the text and where it sits
//   [302] LEADER{                  10/20 here = the landing, where the leader meets the text
//   [304] LEADER_LINE{             10/20 here = the leader vertices, FIRST is the arrow tip
//
// So walk to LEADER_LINE{ and take the first 10/20 after it. Anything else is the text end of the
// leader, which is by definition not where the arrow points.
const ladders = [];
for (const e of ents) {
  if (e.t !== 'MULTILEADER' && e.t !== 'MLEADER') continue;
  if (!Array.isArray(e.all)) continue;
  let inLine = false, tipx = null, tipy = null;
  for (const [c, v] of e.all) {
    if (c === '304' && v === 'LEADER_LINE{') { inLine = true; continue; }
    if (c === '305' || (c === '303' && inLine)) { if (tipx !== null) break; inLine = false; continue; }
    if (!inLine) continue;
    if (c === '10' && tipx === null) tipx = parseFloat(v);
    else if (c === '20' && tipy === null) tipy = parseFloat(v);
  }
  if (tipx === null || tipy === null) continue;
  const b = A.mleaderBox(e, 0);
  ladders.push({ txt: b ? b.txt : '(no text)', tipx, tipy, lay: e.g['8'] || '?' });
}

// PLAIN-TEXT CALLOUTS WITH A LEADER COUNT TOO.
//
// Only the two sheeting notes are real MLEADERs. GIRT, COLUMN, RAFTER, DOWN PIPE and the rest are
// drawn as TEXT with a LINE run out to the member - the same thing to a reader, and the owner's rule
// is about what the reader sees, not which entity type the engine happened to use.
//
// THREE THINGS THIS HAS TO GET RIGHT, each of which it got wrong first time and reported as fact:
//
//  1. A DIMENSION IS NOT A CALLOUT. "30,480 [100'-0"] O/O STEEL COLUMN" contains the word COLUMN and
//     was being checked as though it pointed at one. It is a dimension: it labels a distance, its
//     "leader" is an extension line, and it is supposed to sit on its own dimension line. Anything
//     on a dimension layer, of dim kind, or that reads as a measurement is skipped.
//
//  2. THE ARROWHEAD IS NOT THE MEMBER. Arrowheads are drawn at the tip on ARROWS/TEXT, so "nearest
//     geometry" was always the leader's own head, 0 units away, on every single callout. That is
//     not a finding, it is the checker looking at itself. Member geometry only.
//
//  3. THE LEADER IS THE LINE THAT LEAVES THE LABEL. Taking the longest line touching the box picked
//     up grid lines and member lines that merely passed nearby. A leader STARTS at the label: one
//     endpoint inside or within half a text height of the box, the other well outside it.
const DIMLIKE = /^[\d,.'"\s\[\]\-x×]+$|^\d[\d,]*\s*\[/;
const isMemberGeom = (lay) => !/^(TEXT|ARROWS|DIMENSIONS|AREA-MARK|GRID-LINES)$/i.test(lay);

const { boxes } = A.annotationBoxes(ents);
for (const b of boxes) {
  if (b.kind !== 'label') continue;                       // (1) dim kind
  if (/DIM/i.test(b.lay)) continue;                       // (1) dimension layer
  if (DIMLIKE.test(String(b.txt).trim())) continue;       // (1) reads as a measurement
  if (!expectedFor(b.txt)) continue;
  const xs = b.pts.map((p) => p[0]), ys = b.pts.map((p) => p[1]);
  const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
  const near = (px, py) => px > x0 - b.h * 0.5 && px < x1 + b.h * 0.5 && py > y0 - b.h * 0.5 && py < y1 + b.h * 0.5;
  let best = null;
  for (const s2 of segs) {
    if (!/^(TEXT|ARROWS)$/i.test(s2[4])) continue;        // (3) leaders live on TEXT/ARROWS
    const aIn = near(s2[0], s2[1]), bIn = near(s2[2], s2[3]);
    if (aIn === bIn) continue;                            // (3) exactly one end at the label
    const tx = aIn ? s2[2] : s2[0], ty = aIn ? s2[3] : s2[1];
    const len = Math.hypot(tx - (x0 + x1) / 2, ty - (y0 + y1) / 2);
    if (len < b.h) continue;                              // a stub is not a leader
    if (!best || len > best.len) best = { len, tipx: tx, tipy: ty };
  }
  if (best) ladders.push({ txt: b.txt, tipx: best.tipx, tipy: best.tipy, lay: b.lay, plain: true });
}

console.log(file);
console.log('  callouts checked: %d   (%d MLEADER, %d text+leader)   tolerance %d units',
  ladders.length, ladders.filter((l) => !l.plain).length, ladders.filter((l) => l.plain).length, TOL);
if (!ladders.length) { console.log('  nothing to check'); process.exit(0); }

let bad = 0, mismatched = 0;
for (const L of ladders) {
  const want = expectedFor(L.txt);
  let near = null, nearOnWanted = null;
  for (const s of segs) {
    if (!isMemberGeom(s[4])) continue;                    // (2) not the leader's own arrowhead
    const d = dist(L.tipx, L.tipy, s);
    if (!near || d < near.d) near = { d, lay: s[4] };
    if (want && want.test(s[4]) && (!nearOnWanted || d < nearOnWanted.d)) nearOnWanted = { d, lay: s[4] };
  }
  const label = String(L.txt).replace(/\s+/g, ' ').slice(0, 42);
  // 1. TOUCHING - the hard rule.
  if (!near || near.d > TOL) {
    bad++;
    console.log('  NOT TOUCHING  "%s"  - nearest member geometry is %s, %d away',
      label, near ? near.lay : '(nothing)', near ? Math.round(near.d) : -1);
    continue;
  }
  // 2. the right member - a note.
  const right = want ? want.test(near.lay) : null;
  if (right === false) {
    mismatched++;
    // Node's console.log has no %-14s; padEnd does the column instead of printing the directive.
    console.log('  WRONG MEMBER  "%s"  - touches %s, but the wording implies %s%s',
      label, (near.lay + '@' + Math.round(near.d)).padEnd(20),
      String(want).replace(/[/^$i()]/g, '').replace(/\|/g, ' or '),
      nearOnWanted ? '  (nearest such: ' + nearOnWanted.lay + '@' + Math.round(nearOnWanted.d) + ')' : '  (none on this sheet)');
  } else if (showAll) {
    console.log('  ok            "%s"  -> %s at %d', label, near.lay, Math.round(near.d));
  }
}
console.log('  %d of %d touch their member; %d point at nothing, %d touch a layer the wording does not imply',
  ladders.length - bad, ladders.length, bad, mismatched);
process.exitCode = bad ? 1 : 0;
