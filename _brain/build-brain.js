#!/usr/bin/env node
/**
 * build-brain.js - indexes every Maimaar knowledge source into one SQLite file.
 *
 * Zero dependencies: uses node:sqlite (Node 22+) with FTS5.
 * Regenerable: delete brain.db and re-run. Nothing here is a source of truth.
 *
 *   node build-brain.js
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { DatabaseSync } = require('node:sqlite');

const OUT = path.join(__dirname, 'brain.db');
const CRM = 'D:/maimaar-os/2_Sales CRM';
const OS_ROOT = 'D:/maimaar-os';
const MEMORY = 'C:/Users/nasir/.claude/projects/C--Users-nasir/memory';
const SKILLS_USER = 'C:/Users/nasir/.claude/skills';
const SKILLS_REPO = path.join(CRM, '.claude/skills');

// ---------------------------------------------------------------- sources
const SOURCES = [
  { dir: MEMORY,                      type: 'memory',     depth: 1 },
  { dir: path.join(CRM, 'RULES'),     type: 'rulebook',   depth: 1 },
  { dir: path.join(CRM, 'docs'),      type: 'doc',        depth: 4 },
  { dir: path.join(OS_ROOT, '0_Master Plan'), type: 'plan', depth: 4 },
  { dir: SKILLS_USER,                 type: 'skill',      depth: 2 },
  { dir: SKILLS_REPO,                 type: 'skill',      depth: 2 },
];
const SINGLE_FILES = [
  { file: path.join(CRM, 'CLAUDE.md'),         type: 'project-doc' },
  { file: path.join(CRM, 'UNIVERSAL_RULES.md'),type: 'project-doc' },
  { file: path.join(CRM, 'README.md'),         type: 'project-doc' },
  { file: path.join(OS_ROOT, 'MASTER_RULES.md'), type: 'project-doc' },
];

const SKIP_DIR = new Set(['node_modules', '.git', '_archive', '_BACKUP', 'dist', 'coverage']);

function walk(dir, maxDepth, depth = 0, acc = []) {
  if (depth > maxDepth) return acc;
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    if (SKIP_DIR.has(e.name) || e.name.startsWith('.trash')) continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, maxDepth, depth + 1, acc);
    else if (/\.md$/i.test(e.name)) acc.push(full);
  }
  return acc;
}

// ---------------------------------------------------------------- helpers
function moduleOf(rel, type) {
  const r = rel.replace(/\\/g, '/').toLowerCase();
  if (/erection|payroll|supervisor|worker|attendance|fabrication/.test(r)) return 'erection';
  if (/pmt|pmd|register|project.?no|phase/.test(r))      return 'pmd';
  if (/estimat|qe-|quickest|pricing|per-kg|freight/.test(r)) return 'estimation';
  if (/\bpd\b|drawing|lisp|autocad|dxf|dwg|fascia|mezz|canopy|crane|purlin|section|plan-/.test(r)) return 'pd';
  if (/proposal|tfp|\bop\b|word|docx|price.?table/.test(r)) return 'proposal';
  if (/inquiry|\bif\b|bsf|building.?spec|wall|area|frame/.test(r)) return 'if-bsf';
  if (/ustaad|sap|design/.test(r))                        return 'ustaad';
  if (/sales|crm|lead|customer/.test(r))                  return 'sales';
  if (type === 'rulebook') return 'rules';
  return 'general';
}

function frontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!m) return { fm: {}, body: text };
  const fm = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([a-zA-Z_]+):\s*(.*)$/);
    if (kv) fm[kv[1]] = kv[2].replace(/^["']|["']$/g, '');
  }
  return { fm, body: text.slice(m[0].length) };
}

// Split a markdown body into heading-scoped chunks so a hit returns a section,
// not a 22 KB file.
function chunk(body) {
  const lines = body.split(/\r?\n/);
  const out = [];
  let heading = '(intro)', level = 0, buf = [];
  const flush = () => {
    const text = buf.join('\n').trim();
    if (text) out.push({ heading, level, body: text });
    buf = [];
  };
  for (const line of lines) {
    const h = line.match(/^(#{1,4})\s+(.*)$/);
    if (h) { flush(); level = h[1].length; heading = h[2].trim(); }
    else buf.push(line);
  }
  flush();
  return out;
}

// ---------------------------------------------------------------- schema
if (fs.existsSync(OUT)) fs.rmSync(OUT);
const db = new DatabaseSync(OUT);
db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE docs (
    id INTEGER PRIMARY KEY, path TEXT UNIQUE, rel TEXT, source_type TEXT,
    module TEXT, title TEXT, description TEXT, mem_type TEXT,
    bytes INTEGER, mtime TEXT, sha TEXT
  );
  CREATE TABLE chunks (
    id INTEGER PRIMARY KEY, doc_id INTEGER, ord INTEGER,
    heading TEXT, level INTEGER, body TEXT,
    FOREIGN KEY(doc_id) REFERENCES docs(id)
  );
  CREATE VIRTUAL TABLE chunks_fts USING fts5(
    heading, body, content='chunks', content_rowid='id', tokenize='porter unicode61'
  );
  CREATE TABLE links (from_doc INTEGER, target TEXT, resolved INTEGER);
  CREATE TABLE flags (doc_id INTEGER, kind TEXT, detail TEXT);
  CREATE INDEX idx_docs_module ON docs(module);
  CREATE INDEX idx_docs_type ON docs(source_type);
  CREATE INDEX idx_chunks_doc ON chunks(doc_id);
`);

const insDoc = db.prepare(`INSERT OR IGNORE INTO docs
  (path, rel, source_type, module, title, description, mem_type, bytes, mtime, sha)
  VALUES (?,?,?,?,?,?,?,?,?,?)`);
const insChunk = db.prepare(`INSERT INTO chunks (doc_id, ord, heading, level, body) VALUES (?,?,?,?,?)`);
const insFts   = db.prepare(`INSERT INTO chunks_fts (rowid, heading, body) VALUES (?,?,?)`);
const insLink  = db.prepare(`INSERT INTO links (from_doc, target, resolved) VALUES (?,?,?)`);
const insFlag  = db.prepare(`INSERT INTO flags (doc_id, kind, detail) VALUES (?,?,?)`);

// ---------------------------------------------------------------- collect
const files = [];
for (const s of SOURCES) {
  if (!fs.existsSync(s.dir)) continue;
  for (const f of walk(s.dir, s.depth)) files.push({ file: f, type: s.type });
}
for (const s of SINGLE_FILES) if (fs.existsSync(s.file)) files.push({ file: s.file, type: s.type });

const memoryNames = new Set();
if (fs.existsSync(MEMORY)) {
  for (const f of fs.readdirSync(MEMORY)) {
    if (f.endsWith('.md')) memoryNames.add(f.replace(/\.md$/, ''));
  }
}

// Code paths referenced in prose, to check they still exist.
const CODE_REF = /\b((?:services|routes|scripts|migrations|public|tests|middleware|config)\/[A-Za-z0-9_./-]+\.(?:ts|js|html|css|json|csv))/g;

// A memory written before the TypeScript migration cites services/x.js, while the source
// is now x.ts and the runtime loads dist/. Count any of those as "still exists" - flagging
// them all makes the report mostly false positives, and a noisy report gets ignored.
const ALT_EXT = {
  '.js':   ['.ts', '.tsx', '.mjs', '.cjs', '.json'],
  '.ts':   ['.js', '.tsx'],
  '.json': ['.js', '.ts'],
};
function pathResolves(p) {
  const cands = [p, 'dist/' + p];
  const ext = path.extname(p);
  for (const alt of (ALT_EXT[ext] || [])) {
    const swapped = p.slice(0, -ext.length) + alt;
    cands.push(swapped, 'dist/' + swapped);
  }
  return cands.some(c => fs.existsSync(path.join(CRM, c)));
}

let nDocs = 0, nChunks = 0;
db.exec('BEGIN');
for (const { file, type } of files) {
  let text, stat;
  try { text = fs.readFileSync(file, 'utf8'); stat = fs.statSync(file); } catch { continue; }
  const { fm, body } = frontmatter(text);
  const norm = file.replace(/\\/g, '/');
  const rel = norm.replace(OS_ROOT + '/', '').replace(MEMORY + '/', 'memory/').replace(SKILLS_USER + '/', 'skills/');
  const title = fm.name || (body.match(/^#\s+(.+)$/m) || [])[1] || path.basename(file, '.md');
  const mod = moduleOf(rel, type);
  const sha = crypto.createHash('sha1').update(text).digest('hex').slice(0, 12);

  insDoc.run(norm, rel, type, mod, title, fm.description || '', fm.type || '',
             stat.size, stat.mtime.toISOString().slice(0, 10), sha);
  const docId = db.prepare('SELECT id FROM docs WHERE path = ?').get(norm).id;
  nDocs++;

  const parts = chunk(body);
  parts.forEach((c, i) => {
    insChunk.run(docId, i, c.heading, c.level, c.body);
    const rowid = db.prepare('SELECT last_insert_rowid() AS r').get().r;
    insFts.run(rowid, c.heading, c.body);
    nChunks++;
  });

  // ---- wikilinks
  for (const m of text.matchAll(/\[\[([a-z0-9-]+)(?:\.md)?\]\]/gi)) {
    const target = m[1];
    insLink.run(docId, target, memoryNames.has(target) ? 1 : 0);
    if (type === 'memory' && !memoryNames.has(target)) {
      insFlag.run(docId, 'broken_link', target);
    }
  }

  // ---- rot signals
  if (/\bSUPERSEDED\b|\bDEPRECATED\b/i.test(text)) insFlag.run(docId, 'superseded', '');
  if (/\bOPEN DECISION\b|\bOPEN:/i.test(text))     insFlag.run(docId, 'open_decision', '');
  if (/\bSTANDING\b/i.test(text) && !/tests?\//i.test(text)) {
    insFlag.run(docId, 'standing_no_test', 'declares a STANDING rule but names no test file');
  }
  const seen = new Set();
  for (const m of text.matchAll(CODE_REF)) {
    const p = m[1];
    if (seen.has(p)) continue;
    seen.add(p);
    if (!pathResolves(p)) insFlag.run(docId, 'dead_path', p);
  }
}
db.exec('COMMIT');

db.exec("INSERT INTO chunks_fts(chunks_fts) VALUES('optimize')");

// ---------------------------------------------------------------- report
const q = (sql) => db.prepare(sql).all();
console.log(`brain.db built -> ${OUT}`);
console.log(`  ${nDocs} documents, ${nChunks} sections indexed\n`);
console.log('By source:');
for (const r of q(`SELECT source_type, COUNT(*) n, SUM(bytes) b FROM docs GROUP BY 1 ORDER BY n DESC`))
  console.log(`  ${String(r.n).padStart(4)}  ${r.source_type.padEnd(12)} ${(r.b/1024).toFixed(0)} KB`);
console.log('\nBy module:');
for (const r of q(`SELECT module, COUNT(*) n FROM docs GROUP BY 1 ORDER BY n DESC`))
  console.log(`  ${String(r.n).padStart(4)}  ${r.module}`);
console.log('\nFlags raised:');
for (const r of q(`SELECT kind, COUNT(*) n FROM flags GROUP BY 1 ORDER BY n DESC`))
  console.log(`  ${String(r.n).padStart(4)}  ${r.kind}`);
db.close();
