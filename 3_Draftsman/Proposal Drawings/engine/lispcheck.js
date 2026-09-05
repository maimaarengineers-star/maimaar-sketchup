// Guard for the AutoLISP failure that has no error message: a function that is CALLED but
// never DEFINED. The whole evaluation unwinds silently and the sheet comes out blank.
//
// Paren balance does not catch it — deleting a whole defun leaves the file balanced, which
// is exactly how three peb-sd-* helpers went missing on 28-Aug and the DETAILS sheet
// rendered empty with no complaint from anything.
//
//   node lispcheck.js <file.lsp> [more.lsp ...]
const fs = require('fs');

const defined = new Set();
const called = new Map();          // name -> first file:line seen

// ── FILE LIST ────────────────────────────────────────────────────────────────────────────────
// Named files, else the whole engine. The npm script used to pass the glob "MAIMAAR_PEB_*.lsp",
// which npm hands to cmd.exe on Windows - and cmd does NOT expand globs, so `npm run
// check:pd-lisp` died on ENOENT for a file literally named "MAIMAAR_PEB_*.lsp". The chain has
// therefore never run on this machine since it was added. Globbing here rather than in the shell
// makes it work the same from npm, from bash and from a bare `node <tool>`.
const _fs = require('fs'), _path = require('path');
function engineFiles(withLibrary) {
  const here = __dirname;
  const out = _fs.readdirSync(here).filter((f) => /^MAIMAAR_PEB_.*\.lsp$/i.test(f))
                 .map((f) => _path.join(here, f));
  const lib = _path.join(here, 'Library');
  if (withLibrary && _fs.existsSync(lib)) {
    for (const d of _fs.readdirSync(lib, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const sub = _path.join(lib, d.name);
      for (const f of _fs.readdirSync(sub)) if (/\.lsp$/i.test(f)) out.push(_path.join(sub, f));
    }
  }
  return out.sort();
}
const FILES = process.argv.slice(2).length ? process.argv.slice(2) : engineFiles(true);

for (const f of FILES) {
  const lines = fs.readFileSync(f, 'utf8').split('\n');
  lines.forEach((raw, i) => {
    const line = raw.replace(/;.*$/, '');                       // drop comments
    let m;
    const d = /\(defun\s+([A-Za-z0-9:\-*_]+)/g;
    while ((m = d.exec(line))) defined.add(m[1].toUpperCase());
    const c = /\((peb-[A-Za-z0-9\-*_]+)/g;                      // our own namespace only
    while ((m = c.exec(line))) {
      const n = m[1].toUpperCase();
      if (!called.has(n)) called.set(n, f.split(/[\\/]/).pop() + ':' + (i + 1));
    }
  });
}

// -- STRUCTURE: does every defun CLOSE before the next one starts? ---------------------------
// Defined-vs-called catches a DELETED function.  It cannot catch the opposite failure: a defun that
// loses the closing parens of its own body and therefore SWALLOWS every function after it.  This
// script still reports every swallowed name as "defined" -- it reads text, not structure -- while
// AutoLISP quietly leaves them UNDEFINED.  Sheets then render with whole components missing and
// nothing errors.  A paren count can be off and still tell you nothing: it gives one number for a
// 9,000-line file.  This names the function.
// That is 4B.26's "a balanced file is not a working one", and it cost a render to find on 31-Aug:
// deleting a dimension block from peb-draw-monitor took the `))` that closed its progn+if with it,
// and the SKYLIGHTS -- defined 1,100 lines further down -- silently stopped existing.
function closeIndex(src, start) {
  let d = 0, inStr = false, esc = false, inCom = false;
  for (let i = start; i < src.length; i += 1) {
    const ch = src[i];
    if (ch === '\n') { inCom = false; continue; }
    if (inCom) continue;
    if (esc) { esc = false; continue; }
    if (inStr) { if (ch === '\\') esc = true; else if (ch === '"') inStr = false; continue; }
    if (ch === '"') inStr = true;
    else if (ch === ';') inCom = true;
    else if (ch === '(') d += 1;
    else if (ch === ')') { d -= 1; if (d === 0) return i; }
  }
  return -1;
}

const swallowed = [];
for (const f of FILES) {
  const src = fs.readFileSync(f, 'utf8');
  // TOP-LEVEL defuns only (column 0). A nested helper defun -- tb-get inside
  // peb-titleblock-mammut, aLn inside C:PEB-PLAN -- is legitimately enclosed by its parent,
  // and comparing against those reports the parent as 'swallowing' its own local.
  const re = /^\(defun\s+([A-Za-z0-9:\-*_]+)/gm;
  const starts = [];
  let mm;
  while ((mm = re.exec(src))) starts.push([mm.index, mm[1]]);
  starts.forEach((cur, k) => {
    const end = closeIndex(src, cur[0]);
    const next = k + 1 < starts.length ? starts[k + 1][0] : src.length;
    if (end < 0 || end > next) {
      swallowed.push({
        file: f.split(/[\/]/).pop(),
        line: src.slice(0, cur[0]).split('\n').length,
        name: cur[1],
        eats: k + 1 < starts.length ? starts[k + 1][1] : '(rest of file)',
      });
    }
  });
}

// ── AN OPTIONAL CALL IS NOT A MISSING ONE ────────────────────────────────────────────────────
// A call wrapped in (if (boundp 'peb-foo) (peb-foo ...)) is DELIBERATELY optional - the engine
// asks whether the helper was loaded and does without it if not. Elevation.lsp:285 does exactly
// this for peb-dim-v-native. Reporting it as "renders as a blank sheet, silently" is wrong, and
// it is the kind of wrong that matters: it is the ONLY line this check printed, so it made
// `npm run check:pd-lisp` exit non-zero every time and the whole chain stop before emcheck and
// arity ever ran. One false positive was disabling four real checks.
const guarded = new Set();
for (const f of FILES) {
  const src = require('fs').readFileSync(f, 'utf8');
  for (const m of src.matchAll(/\(boundp\s+'([A-Za-z0-9_\-*]+)/g)) guarded.add(m[1].toLowerCase());
}
const missing = [...called.keys()].filter((n) => !defined.has(n) && !guarded.has(n.toLowerCase()));
console.log('defined %d peb-* functions, %d distinct calls', defined.size, called.size);

if (swallowed.length) {
  console.log('\nUNCLOSED DEFUN -- it eats the functions after it, and the file still BALANCES:');
  swallowed.forEach((s) => console.log('  %s:%d  %s  swallows  %s', s.file, s.line, s.name, s.eats));
}
if (!missing.length && !swallowed.length) {
  console.log('OK - every peb-* call has a definition, and every defun closes before the next');
  process.exit(0);
}
if (missing.length) {
  console.log('\nCALLED BUT NEVER DEFINED - this renders as a blank sheet, silently:');
  missing.forEach((n) => console.log('  %s   first called at %s', n.toLowerCase(), called.get(n)));
}
process.exit(1);
