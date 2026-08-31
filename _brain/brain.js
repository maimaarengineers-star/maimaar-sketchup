#!/usr/bin/env node
/**
 * brain.js - query the Maimaar knowledge index.
 *
 *   node brain.js "sag rod"                          search
 *   node brain.js "what stops sheets sagging?"       plain-English search
 *   node brain.js "payroll" --module erection --limit 5
 *   node brain.js "WIDTH_REF" --raw                  pass the query to FTS5 verbatim
 *   node brain.js --report [kind]                    health / rot report
 *   node brain.js --doc maimaar-sagrod-rule          print a document
 *
 * Query handling: FTS5 treats a bare multi-word query as AND of every term, so a
 * natural question ("what stops sheets sagging in a long bay") demands that "what"
 * and "stops" appear too, and matches nothing. We strip stopwords, OR the rest and
 * let bm25 rank - which puts the rarest, most specific terms on top.
 */

const path = require('path');
const { DatabaseSync } = require('node:sqlite');

const DB = path.join(__dirname, 'brain.db');
const db = new DatabaseSync(DB, { readOnly: true });

const argv = process.argv.slice(2);
const flagIdx = (n) => argv.indexOf('--' + n);
const flag = (name, def = null) => {
  const i = flagIdx(name);
  if (i === -1) return def;
  const nxt = argv[i + 1];
  return nxt && !nxt.startsWith('--') ? nxt : true;
};

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

// ------------------------------------------------------------------ query build
const STOP = new Set(`a an the and or but if then than that this these those it its is are was were
be been being am do does did doing have has had having i we you he she they them our your my me
of in on at to for from by with about into over under again further once here there when where why
how what which who whom all any both each few more most other some such no nor not only own same so
too very can will just should now does do need want got get keep make made using use used as also
between during before after above below up down out off why does happen happens stop stops`
  .split(/\s+/).filter(Boolean));

function buildMatch(raw) {
  // Anything with explicit FTS5 syntax is the user's own expression - pass it through.
  if (/["*:^]|\b(AND|OR|NOT|NEAR)\b/.test(raw)) return raw;

  const terms = raw
    .split(/[^A-Za-z0-9_-]+/)
    .map(t => t.replace(/^-+|-+$/g, ''))
    .filter(t => t.length > 1 && !STOP.has(t.toLowerCase()));

  if (!terms.length) return raw;
  // A term containing - or _ must be quoted: FTS5 reads a leading - as NOT and
  // splits on punctuation, which would shred MSPL-26-270 and WIDTH_REF.
  const quoted = terms.map(t => (/[^A-Za-z0-9]/.test(t) ? `"${t}"` : t));
  return quoted.join(' OR ');
}

const positional = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith('--')) { const n = argv[i + 1]; if (n && !n.startsWith('--')) i++; continue; }
  positional.push(a);
}
const query = positional.join(' ').trim();
if (!query) {
  console.log('usage: node brain.js "<search>" [--module m] [--type t] [--limit n] [--raw]');
  console.log('       node brain.js --report [kind]');
  console.log('       node brain.js --doc <name>');
  process.exit(0);
}

const limit = parseInt(flag('limit', '8'), 10);
const mod = flag('module');
const type = flag('type');
const match = argv.includes('--raw') ? query : buildMatch(query);

let sql = `
  SELECT d.rel, d.module, d.source_type, c.heading,
         snippet(chunks_fts, 1, '>>', '<<', ' ... ', 24) AS snip,
         bm25(chunks_fts, 2.0, 1.0) AS score
  FROM chunks_fts
  JOIN chunks c ON c.id = chunks_fts.rowid
  JOIN docs d   ON d.id = c.doc_id
  WHERE chunks_fts MATCH ?`;
const params = [match];
if (mod && mod !== true)   { sql += ' AND d.module = ?';      params.push(mod); }
if (type && type !== true) { sql += ' AND d.source_type = ?'; params.push(type); }
sql += ' ORDER BY score LIMIT ?';
params.push(limit);

let rows;
try { rows = db.prepare(sql).all(...params); }
catch (e) { console.log('query error:', e.message, '\n  match expression was:', match); process.exit(1); }

if (!rows.length) { console.log(`no match for: ${query}\n  (searched: ${match})`); process.exit(0); }

console.log(`${rows.length} hit(s) for "${query}"`);
if (match !== query) console.log(`  searched: ${match}`);
console.log('');
for (const r of rows) {
  console.log(`[${r.module}] ${r.rel}  >  ${r.heading}`);
  console.log(`   ${r.snip.replace(/\s+/g, ' ').trim()}\n`);
}
