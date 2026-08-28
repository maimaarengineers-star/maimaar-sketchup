# Maimaar OS — where things go

_This file loads for every session anywhere under `D:\maimaar-os`. It is the filing rule and
nothing else, so it stays short enough to still be true in six months. Set 28-Aug-2026._

## The rule

> **Documents go to a folder. Data goes to the database. Never both.**

| What | Where |
|---|---|
| A **plan, spec, roadmap, handoff** — for any department | `0_Master Plan\`, in that department's numbered folder |
| A department's **working source, reference and output** | that department's folder here, in `_source` / `_extract` / `_import_logs` / `_reports` |
| Something applying to **most** departments | `13_Common Records\` (documents) · `0_Master Plan\0_Common\` (plans) |
| **Master data** — people, projects, inquiries, money | **the database, once**, with department as a column |

## The three questions that settle any case

**1. Is it data, or is it paper?** Test: *if I delete this file, can the system still answer the
question?* Delete a CNIC scan and the man's identity evidence is gone — file it. Delete a
`worker list.xlsx` and nothing is lost, because the database has it — so never create it.

**2. If it is paper — file by who PRODUCED it, not who is interested in it.** The site attendance
sheet is Erection's document even though HR and Accounts both care. File by origin and every
document has one home; file by interest and the same sheet lands in three folders.

**3. `_source` is an inbox, not an archive.** Once imported, the database is the record.
`_import_logs` says what was loaded and when. The folder never becomes a second system.

## The folders

```
0_Master Plan   ← ALL plans, every department (its own git repo, the "gate")
1_Marketing     2_Sales CRM (THE LIVE APP)   3_Draftsman   4_Estimation
5_USTAAD        6_…PMD        7_Erection Deparment-ED
8_Production    9_Supply Chain   10_Quality & Safety   11_Finance
12_HR           13_Common Records
```

## Hard rules

- **The org chart lives in `departments.parent_id`, never in the folder tree.** A folder tree that
  mirrors an org chart has to be re-shuffled every re-org, and every path breaks with it.
- **Never reorganize inside `2_Sales CRM`** — the app finds files by relative path.
- **Never renumber `0`–`7`.** `2_Sales CRM` is a git repo whose path is in `.env`, the launch
  scripts and a hundred documents. New departments continue from 8.
- **Never put source code on Google Drive or OneDrive** — it is the whole ERP. A private external
  drive or NAS is fine (`BACKUP_MIRROR_CODE`); cloud storage is not.
- **`4_Estimation` has no git remote.** The cost price lists and MSPLDB family rates exist on this
  laptop and nowhere else. Treat that folder as irreplaceable.
