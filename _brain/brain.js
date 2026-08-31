#!/usr/bin/env node
/**
 * brain.js - query the Maimaar knowledge index.
 *
 *   node brain.js "sag rod"                 full-text search
 *   node brain.js "payroll" --module erection --limit 5
 *   node brain.js --report                  rot / health report
 *   node brain.js --report dead_path        one flag kind in full
 *   node brain.js --doc maimaar-sagrod-rule show a document
 */

const path = require('path');
const { DatabaseSync } = require('node:sqlite');

const DB = path.join(__dirname, 'brain.db');
const db = new DatabaseSync(DB, { readOnly: true });

const argv = process.argv.slice(2);
const flag = (name, def = null) => {
  const i = argv.indexOf('--' + name);
  return i === -1 ? def : (argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true);
};
const positional = argv.filter((a, i) =>
  !a.startsWith('--') && !(i > 0 && argv[i - 1].startsWith('--') && argv[i - 1] !== '--report'));

// ------------------------------------------------------------------ report
if (argv.includes('--report')) {
  const kind = flag('report');
  if (kind && kind !== true) {
    const rows = db.prepare(`
      SELECT d.rel, d.module, f.detail FROM flags f JOIN docs d ON d.id = f.doc_id
      WHERE f.kind = ? ORDER BY d.module, d.rel`).all(kind);
    console.log(`${kind}: ${rows.length}\n`);
    for (const r of rows) console.log(`  [${r.module}] ${r.rel}${r.detail ? '  ->  ' + r.detail : ''}`);
    process.exit(0);
  }
  console.log('MAIMAAR BRAIN - health report\n');
  const tot = db.prepare('SELECT COUNT(*) n FROM docs').get().n;
  const ch = db.prepare('SELECT COUNT(*) n FROM chunks').get().n;
  console.log(`${tot} documents, ${ch} sections\n`);
  for (const k of db.prepare('SELECT kind, COUNT(*) n FROM flags GROUP BY 1 ORDER BY n DESC').all()) {
    console.log(`${k.kind} (${k.n})`);
    const sample = db.prepare(`
      SELECT d.rel, f.detail FROM flags f JOIN docs d ON d.id = f.doc_id
      WHERE f.kind = ? ORDER BY d.rel LIMIT 6`).all(k.kind);
    for (const s of sample) console.log(`    ${s.rel}${s.detail ? '  ->  ' + s.detail : ''}`);
    if (k.n > 6) console.log(`    ... ${k.n - 6} more  (node brain.js --report ${k.kind})`);
    console.log('');
  }
  process.exit(0);
}

// ------------------------------------------------------------------ doc
const docName = flag('doc');
if (docName && docName !== true) {
  const d = db.prepare(`SELECT * FROM docs WHERE title = ? OR rel LIKE ? LIMIT 1`)
              .get(docName, '%' + docName + '%');
  if (!d) { console.log('not found:', docName); process.exit(1); }
  console.log(`${d.rel}   [${d.source_type} / ${d.module}]  ${d.mtime}`);
  if (d.description) console.log(`\n${d.description}\n`);
  for (const c of db.prepare('SELECT * FROM chunks WHERE doc_id = ? ORDER BY ord').all(d.id)) {
    if (c.heading !== '(intro)') console.log('\n' + '#'.repeat(c.level || 2) + ' ' + c.heading);
    console.log(c.body);
  }
  process.exit(0);
}

// ------------------------------------------------------------------ search
const query = positional.join(' ').trim();
if (!query) {
  console.log('usage: node brain.js "<search>" [--module m] [--type t] [--limit n]');
  console.log('       node brain.js --report [kind]');
  console.log('       node brain.js --doc <name>');
  process.exit(0);
}

const limit = parseInt(flag('limit', '8'), 10);
const mod = flag('module');
const type = flag('type');

let sql = `
  SELECT d.rel, d.module, d.source_type, c.heading,
         snippet(chunks_fts, 1, '>>', '<<', ' ... ', 24) AS snip,
         bm25(chunks_fts) AS score
  FROM chunks_fts
  JOIN chunks c ON c.id = chunks_fts.rowid
  JOIN docs d   ON d.id = c.doc_id
  WHERE chunks_fts MATCH ?`;
const params = [query];
if (mod && mod !== true)  { sql += ' AND d.module = ?';      params.push(mod); }
if (type && type !== true){ sql += ' AND d.source_type = ?'; params.push(type); }
sql += ' ORDER BY score LIMIT ?';
params.push(limit);

let rows;
try { rows = db.prepare(sql).all(...params); }
catch (e) { console.log('query error:', e.message); process.exit(1); }

if (!rows.length) { console.log(`no match for: ${query}`); process.exit(0); }
console.log(`${rows.length} hit(s) for "${query}"\n`);
for (const r of rows) {
  console.log(`[${r.module}] ${r.rel}  >  ${r.heading}`);
  console.log(`   ${r.snip.replace(/\s+/g, ' ').trim()}\n`);
}
