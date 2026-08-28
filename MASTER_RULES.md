# MASTER RULES — which document rests where

**For every terminal, every session, every department.** Set 28-Aug-2026 by Nasir Abbas.
If any other document disagrees with this one about *filing*, this one wins.

---

## The one rule

> ## Documents go to a folder. Data goes to the database. Never both.

Master data — **people, projects, inquiries, money** — lives in the database **once**, with
department as a *column*. A folder never holds a second copy of it. The moment `workers.xlsx` sits
in `7_ED\` and HR keeps another, you have two lists, and within a month they disagree and nobody can
say which is right.

---

## Decide in three questions

**Q1 — Is it data, paper, or output?**

| | Means | Goes |
|---|---|---|
| **Data** | the system can answer from it | **the database, once.** Never a folder. |
| **Paper** | evidence that arrived from outside | a department folder → Q2 |
| **Output** | something we produced | `_reports\` of whoever asked for it |

> **The test:** *if I delete this file, can the system still answer the question?*
> Delete a CNIC scan → the man's identity evidence is gone. **That is a record. File it.**
> Delete `worker list.xlsx` → nothing lost, the database has it. **Never create it.**

**Q2 — Whose is it? File by WHO PRODUCED IT, not who is interested in it.**

The site attendance sheet is **Erection's** document even though HR, Accounts and PMD all care about
it. File by origin and every document has exactly one home. File by interest and the same sheet
belongs in three folders — so you copy it three times, and then they drift.

**Q3 — Is it a plan, or is it working material?**

- A **plan, spec, roadmap, handoff, review** → `0_Master Plan\`, in that department's numbered folder.
- **Working source, reference, output** → that department's folder here in `D:\maimaar-os`.

---

## Inside every department folder — the same four

| Folder | What | Rule |
|---|---|---|
| `_source\` | Raw material **as received** — Excel, PDF, client files | An **inbox**, never edited. Keep the original bytes. |
| `_extract\` | Machine-readable pulls from `_source` | CSV of each tab, so the record is readable without Excel |
| `_import_logs\` | What was loaded into the database, when, by which script | This is what makes `_source` provenance instead of a second system |
| `_reports\` | What **we** produced — audits, reconciliations, findings | Regenerate them; never maintain them by hand |

---

## The lookup — which document rests where

### Sales & Commercial

| Document | Where |
|---|---|
| Customer RFQ / enquiry pack as received | `2_Sales CRM\data\rfq` (uploaded through the app) |
| **Inquiry Form (IF), BSF** | **database** — the single source of truth |
| Estimate / QE output, Price Table | **database** — derived from the BSF, never a saved copy |
| **JAF** (Job Approval Form — shows the margin) | `4_Estimation\_source\` |
| Rate lists, MSPLDB, QuickEst rulers | `4_Estimation\` (the workbooks the extract scripts read) |
| **TFP** (proposal .docx), **PD** (proposal drawings) | generated from the IF — `3_Draftsman\_generated_drawings`, filed by proposal number |
| PO · Contract · LOI · signed agreement | `6_…PMD\_source\` (PMD owns the signing handover) |
| Marketing collateral, brochures, campaign material | `1_Marketing\` |

### Engineering & Drawings

| Document | Where |
|---|---|
| AutoLISP engine, DXF/DWG source, layer CSV | `3_Draftsman\Proposal Drawings\` |
| Reference / archive drawings from past jobs | `3_Draftsman\AutoCAD_Reference_Library\` |
| Approval drawings sent to and returned by the customer | `3_Draftsman\_source\` (returned) — the approval **status** is data |
| Shop / detail drawings | `3_Draftsman\` |
| USTAAD schema, validation, standards, research | `5_USTAAD\` |
| Codes and standards (MBMA, AISC, ASCE) | `0_Master Plan\0_Common\` if they govern everything; otherwise the department that applies them |

### Projects (PMD)

| Document | Where |
|---|---|
| **The project register — every job, customer, weight, contract value** | **database** |
| The PMT Google Sheet snapshot it was imported from | `6_…PMD\_source\` (frozen, sha256 recorded, never edited) |
| **PIF** (Project Information Form) | `6_…PMD\_source\` — but note its BDS half **is** the BSF: derive it, do not re-key it |
| Daily board / meeting tasks | **database** |
| Project No. assignment | **database** — a serial is unreclaimable once used |

### Production, Supply Chain, Quality

| Document | Where |
|---|---|
| Workshop attendance sheets as received | `8_Production\_source\` |
| Production plans, shop loading | `8_Production\_reports\` |
| Purchase orders, supplier quotations, GRNs | `9_Supply Chain\_source\` |
| Stock counts, store records | `9_Supply Chain\_source\` |
| Dispatch notes, packing lists | `9_Supply Chain\_source\` |
| MTCs (mill test certificates), inspection reports | `10_Quality & Safety\_source\` |
| Weld records, paint DFT readings | `10_Quality & Safety\_source\` |
| Site safety records, incident reports | `10_Quality & Safety\_source\` |

### Erection & People — *this is the one that causes confusion*

| Document | Where |
|---|---|
| **The worker register — every man, department, rate, days, advance balance** | **database.** Not `7_ED\`, not `12_HR\`. |
| **CNIC scans, worker photos** | **database** (`erection_worker_documents`) — upload them, don't file them |
| Signed site attendance sheets as received | `7_ED\_source\` |
| Site cash vouchers, advance slips | `7_ED\_source\` |
| Payroll run, deductions, postings | **database** |
| The payroll Excel it was imported from | `7_ED\_source\` (frozen) |
| Tools list, site equipment records | `7_ED\Tools List\` |
| **HR policy** — contract templates, leave policy, salary structure, appraisal forms | `12_HR\` |
| An employee's **signed** contract or appraisal | **database**, against his worker record |
| Org chart | `13_Common Records\` — and the live one is `departments.parent_id` |

### Finance

| Document | Where |
|---|---|
| Postings, recharges, cost centres, receivables | **database** |
| Bank statements, invoices, receipts as received | `11_Finance\_source\` |
| Reconciliations we produced | `11_Finance\_reports\` |

> **The ERP records money; it never generates it.** Ledgers stay in the accounting system.

### Cross-department and system

| Document | Where |
|---|---|
| Company-wide policy, terminology, signatory & hierarchy records | `13_Common Records\` |
| Anything applying to **most** departments (documents) | `13_Common Records\` |
| Anything applying to **most** departments (plans) | `0_Master Plan\0_Common\` |
| Plans, specs, roadmaps, handoffs — any department | `0_Master Plan\<department folder>\` |
| Cross-module audit findings | `0_Master Plan\Audit\` |
| Backups, database snapshots | `E:\_MAIMAAR_BACKUP\offdrive-mirror` (external drive) |
| Keys, `.env`, credentials | `0_Master Plan\RUNNING_KEYS\` — **local only, git-ignored, never pushed** |

---

## Hard rules — these are not preferences

1. **The org chart lives in `departments.parent_id`, never in the folder tree.** A folder tree that
   mirrors an org chart must be re-shuffled at every re-org and every path breaks with it. A parent
   column makes a re-org one `UPDATE`.
2. **Never reorganize inside `2_Sales CRM`** — the app finds files by relative path.
3. **Never renumber `0`–`7`.** `2_Sales CRM` is a git repo whose path is in `.env`, the launch
   scripts and a hundred documents. New departments continue from 8.
4. **Never put source code on Google Drive or OneDrive.** It is the whole ERP. A private external
   drive or NAS is fine (`BACKUP_MIRROR_CODE=on`); cloud storage is not.
5. **Never put the live `data\maimaar.db` in a synced folder.** Sync clients lock the `-wal`/`-shm`
   sidecars mid-write and corrupt it. Snapshots are safe; the live file is not.
6. **`4_Estimation` has no git remote.** The cost price lists and MSPLDB family rates exist on this
   laptop and nowhere else. Treat it as irreplaceable.
7. **A frozen `_source` file is never edited.** To refresh, add a new dated copy beside it and leave
   the original. The importer records the sha256 so the same file cannot be imported twice.

---

## The department folders

```
0_Master Plan      ALL plans, every department (own git repo — the "gate")
1_Marketing        2_Sales CRM (THE LIVE APP)   3_Draftsman        4_Estimation
5_USTAAD           6_…PMD                       7_Erection Deparment-ED
8_Production       9_Supply Chain               10_Quality & Safety
11_Finance         12_HR                        13_Common Records
```

## The org chart (people and work — *not* the folder tree)

```
Commercial          Marketing · Sales · Estimation · Contracts
Engineering         Design · Detailing · Approval Drawings
Operations          PMD · Planning · Production · Erection
                      └ Production → Fabrication · Finishing
Supply Chain        Procurement · Store · Dispatch & Logistics
Quality & Safety    Quality Control · Surveyor · HSE
Finance             Accounts · Receivables · Costing
Corporate Services  HR · IT · Admin
```

⚠ **This is not `business_divisions`.** SED / CCD / MCW group by **money** (whose revenue is this).
The chart above groups by **people and work** (who does this, who do they report to). They overlap
on Erection and Fabrication and diverge everywhere else. Never collapse them.

---

## Development materials — where code and its by-products rest

Development produces a lot of files that are neither a customer document nor master data. They have
homes too, and the failure mode is different: **a scratch file committed into a department folder
looks like a record six months later.**

| Thing | Where | Why |
|---|---|---|
| **App source** — `routes/` `services/` `models/` `migrations/` `public/` `tests/` | `2_Sales CRM\` | The app finds files by relative path. **Never reorganize inside it.** |
| **Migrations** | `2_Sales CRM\migrations\` | Named `<date><seq>_<what>.js`. A migration is the *record* of a schema decision - write the reasoning in its header, not in a separate doc. |
| **Import / extract scripts** | `2_Sales CRM\scripts\` | They are code, so they are versioned. A one-off script that loaded real data is not one-off - it is how the data got there. |
| **Test fixtures, test data** | `2_Sales CRM\tests\` | Never point tests at the live DB. |
| **`node_modules` `dist` `Archive`** | gitignored, never filed | `dist` is built; `node_modules` is a junction in the worktrees. |
| **Worktrees** (parallel streams) | `D:\maimaar-wt\<name>\` | **Never inside `D:\maimaar-os`.** A checkout is not a department. Each gets its own port and its own database copy. |
| **Scratch, temp, working files** | the session scratchpad - **not the repo** | If it has no reader tomorrow, it does not belong in a department folder. |
| **Generated drawings** (PDF / DWG / DXF) | `3_Draftsman\_generated_drawings\` | Named by proposal number, one PDF per building. Regenerable, so never a source of truth. |
| **Screenshots, renders, previews** | that department's `Rendered Pictures\` or `_reports\` | Evidence of what a screen looked like on a date. |
| **Database snapshots** | `E:\_MAIMAAR_BACKUP\offdrive-mirror` | External drive. Never a synced folder - sync clients corrupt the `-wal`/`-shm` sidecars. |
| **A plan for a code change** | `0_Master Plan\2_Sales CRM\` | Plans live in the gate, never beside the code. |
| **Cross-module audit findings** | `0_Master Plan\Audit\` | And in the department's folder when they belong to one department. |
| **Session notes, handoffs, reviews** | `0_Master Plan\` | `SESSION_HANDOFF.md` is the first thing a new terminal reads. |

### Rules for every terminal

1. **Read `2_Sales CRM\CLAUDE.md` before touching the app.** It carries the hard rules that cost
   real debugging time - the BSF tick gate, the Price-Table mirror, the tax engine, CSP.
2. **Commit early and stage by path.** More than one terminal commits to this repo. Staging with
   `git add -A` from a shared tree picks up another stream's work and puts your name on it.
3. **One branch per terminal**, and `main` is fast-forwarded only from a typechecked, tested tree.
4. **Never run `npm test` while another terminal runs jest** - the shared `tests/test-data-*.db`
   files give EPERM failures that look exactly like real regressions.
5. **A generated file is never edited by hand.** Fix the generator. If you edit the output, the next
   run silently discards your fix.
6. **Bump the cache-buster** (`?v=`) whenever a served `public/js` or `public/css` file changes,
   or users get a stale bundle and it looks like a data bug.
