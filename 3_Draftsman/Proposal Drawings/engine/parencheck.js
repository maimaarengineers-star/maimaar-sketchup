'use strict';
// Paren balance for AutoLISP. lispcheck.js finds functions CALLED but never DEFINED; it cannot
// see a dropped paren, and a dropped paren is worse: (load) fails, EVERY function in the file is
// undefined, and the sheet silently loses whatever that file drew. That is how the wall-light
// band vanished on 4-Sep - LightPanel.lsp was +1 and nothing anywhere said so.
const fs = require('fs');
let bad = 0;
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
const FILES = process.argv.slice(2).length ? process.argv.slice(2) : engineFiles(false);

for (const f of FILES) {
  const t = fs.readFileSync(f, 'utf8');
  let depth = 0, str = false, com = false, line = 1, firstNeg = 0;
  for (let i = 0; i < t.length; i += 1) {
    const c = t[i];
    if (c === '\n') { line += 1; com = false; continue; }
    if (com) continue;
    if (str) { if (c === '\\') { i += 1; continue; } if (c === '"') str = false; continue; }
    if (c === ';') { com = true; continue; }
    if (c === '"') { str = true; continue; }
    if (c === '(') depth += 1;
    else if (c === ')') { depth -= 1; if (depth < 0 && !firstNeg) firstNeg = line; }
  }
  if (depth !== 0 || firstNeg) {
    bad += 1;
    console.log('UNBALANCED ' + (depth > 0 ? '+' : '') + depth + '  ' + f
      + (firstNeg ? '  (first extra ")" near line ' + firstNeg + ')' : '')
      + (depth > 0 ? '  <-- missing ' + depth + ' paren(s); this file will NOT load' : ''));
  } else {
    console.log('ok         ' + f);
  }
}
process.exit(bad ? 1 : 0);
