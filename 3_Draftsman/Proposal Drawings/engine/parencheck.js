'use strict';
// Paren balance for AutoLISP. lispcheck.js finds functions CALLED but never DEFINED; it cannot
// see a dropped paren, and a dropped paren is worse: (load) fails, EVERY function in the file is
// undefined, and the sheet silently loses whatever that file drew. That is how the wall-light
// band vanished on 4-Sep - LightPanel.lsp was +1 and nothing anywhere said so.
const fs = require('fs');
let bad = 0;
for (const f of process.argv.slice(2)) {
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
