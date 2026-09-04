// merge_pdfs.js — merge every PDF in a folder (sorted by filename) into ONE
// multi-page PDF. Called by MAIMAAR_PEB_PDF.lsp (MSPLPDF) so AutoCAD gets a
// single merged document. Reuses the Sales CRM's pdf-lib install.
//   Usage:  node merge_pdfs.js <inputDir> <outputPdf>
const fs = require('fs');
const path = require('path');
const CRM = 'D:/maimaar-os/2_Sales CRM';
const PDFLib = require(CRM + '/node_modules/pdf-lib');

(async () => {
  const dir = process.argv[2];
  const out = process.argv[3];
  if (!dir || !out) { console.error('usage: node merge_pdfs.js <inputDir> <outputPdf>'); process.exit(1); }
  const files = fs.readdirSync(dir).filter((f) => /\.pdf$/i.test(f)).sort();   // filename order = drawing then sheet
  if (!files.length) { console.error('no PDFs in ' + dir); process.exit(1); }
  const merged = await PDFLib.PDFDocument.create();
  for (const f of files) {
    try {
      const src = await PDFLib.PDFDocument.load(fs.readFileSync(path.join(dir, f)));
      const pages = await merged.copyPages(src, src.getPageIndices());
      pages.forEach((p) => merged.addPage(p));
    } catch (e) { /* skip a bad page, keep the rest */ }
  }
  fs.writeFileSync(out, await merged.save());
  console.log('merged ' + files.length + ' file(s) -> ' + out);
})().catch((e) => { console.error(e); process.exit(1); });
