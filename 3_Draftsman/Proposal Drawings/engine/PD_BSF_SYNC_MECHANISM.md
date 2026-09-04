# PD ↔ BSF SYNC MECHANISM — the zero-conflict architecture

**Goal.** A comprehensive mechanism that makes BSF ↔ Proposal-Drawings drift **structurally
impossible** — not merely "fixed today." Every BSF field either reaches the drawing correctly
or is explicitly accounted for; no name mismatch, silent default, or Plan/Section
interpretation split can happen *undetected*.

**Terms.** IF = Inquiry Form · BSF = Building Specification Form (single source of truth) ·
PD = Proposal Drawings · "the bridge" = `2_Sales CRM/services/drawingData.ts` · "the engine"
= `MAIMAAR_PEB_*.lsp`.

**Companions.** Rules → `PD_RULEBOOK.md` · per-key matrix + code index → `PD_MASTER_REFERENCE.md`
· per-sheet ownership → `DRAWING_CONTENT_RULES.md`. This file is the *mechanism* that keeps
all of that in sync.

**Scope note.** This is the design + gap register. Steps that change drawing output are
tagged **[render-gated]** — they are specified here but must be headless-render-verified
before they ship (deliberately not executed in this documentation pass).

---

## 0. The conflict classes we are eliminating

Every real defect the audit found reduces to one of six classes. The mechanism kills each
class *by construction*, so future instances can't recur silently.

| # | Conflict class | Live example found | Killed by |
|---|---|---|---|
| C1 | **Name mismatch** — bridge emits a key the engine doesn't read | `RM_CONSTRUCTION_TYPE` vs `RM_CONSTR` | Layer 1 (one key contract) + Layer 2 (guard) |
| C2 | **Emitted-not-read** — dead key, wasted intent | `BP_VALLEY_HEIGHT`, `BP_GABLE_COUNT` | Layer 2 (guard flags orphans) |
| C3 | **Read-not-emitted** — engine silently defaults | `BP_GROUND_CH`/`FIRST_CH` (F2) | Layer 2 (guard flags missing emitter) |
| C4 | **Silent fabrication** — blank BSF prints a confident value | `DL_LIVE_ROOF=0.57`, `CR_CAP=10` | Layer 4 (default policy) |
| C5 | **Interpretation split** — Plan & Section read the same row differently | `peb-v3-to-legacy` drift | Layer 3 (shared core) |
| C6 | **Staleness** — drawing reflects an old BSF | (latent) | Layer 5 (freshness contract) |

---

## 1. LAYER 1 — the single KEY CONTRACT (one source of the wire schema)

**The rule.** There is exactly ONE authoritative definition of the `PEB_Data` wire schema.
Both sides *derive from* it; neither side invents a key name independently. This is what makes
C1 (the RM_CONSTR bug) impossible: a key has one spelling, in one place.

**Shape.** A machine-readable manifest — `_peb_key_contract.json` (proposed) — one row per key:

```jsonc
{
  "RM_CONSTR": {
    "source":   "roof_monitor.constructionType",  // BSF/IF field (or "derived"/"title-only")
    "unit":     "text",                           // text | mm | ratio | yesno | count
    "scale":    "passthrough",                    // mm(x1000) | scaleSpacing | passthrough
    "default":  { "policy": "safe-default", "value": "Hot-Rolled (IPEa)" },
    "consumer": "peb-draw-roof-monitor",          // engine fn that reads it (or "title-block")
    "reader":   "Section.lsp:6707",
    "sheet":    ["S"],                            // C P S R E F
    "status":   "live"
  }
}
```

**Where the data already lives.** `PD_MASTER_REFERENCE.md §3` (the trigger matrix) *is* this
contract in human form — every key with source, write line, reader, sheet, status. Layer 1 =
promote that matrix to the machine-readable manifest so tooling can check it. **Single-source
rule: the matrix and the manifest are generated from / reconciled to each other — never hand-
maintained twice.**

**How each side binds to it:**
- **Bridge:** `drawingData.ts` `push(KEY, …)` calls are validated against the manifest at test
  time (every emitted `KEY` must exist in the contract).
- **Engine:** every `MSPL-Get-* … "KEY"` and `peb-alist-get … "KEY"` must exist in the contract.

---

## 2. LAYER 2 — the automated DRIFT GUARD (the zero-conflict enforcer)

**The rule.** Drift is a **build failure**, never a silent wrong drawing. A validator
(pattern already established in this codebase: `auditAll.py`, `checkFieldSync.js`,
`auditIfSync`/`auditEngine`) runs on every commit / CI and cross-checks three sets:

```
   A = keys the BRIDGE emits          (grep push('KEY' … in drawingData.ts)
   B = keys the ENGINE reads          (grep MSPL-Get-*/peb-alist-get "KEY" in *.lsp, incl. strcat-built)
   C = keys in the CONTRACT manifest  (_peb_key_contract.json)
```

**Checks (each a hard failure unless the key is explicitly annotated):**
1. `A ⊄ C` → bridge emits an unknown key → **fail** (catches typos/renames like C1).
2. `B ⊄ C` → engine reads an unknown key → **fail**.
3. `key in C, emitted, no reader` and not `status:title-only|derived` → **fail** (C2 orphan).
4. `key in C, read, no emitter` and not `status:engine-default-ok` → **fail** (C3 gap).
5. `peb-v3-to-legacy` / `peb-frame-display-to-code` / the reader block **differ between
   Plan.lsp and Section.lsp** → **fail** (C5 — until Layer 3 makes them one file, this diff
   check is the guard; after Layer 3 it's automatic).

**Note on dynamic keys.** Some keys are built with `strcat` (e.g. `PN_<K>_INSUL_THK`,
`FA_<w>_TYPE`). The guard must expand the known prefixes (`PN_ROOF/WALL`, walls
`NSW/FSW/LEW/REW`, indices `1..4/1..3`) before comparing, or it will false-flag them as dead.

**Status (21-Jul): BUILT ✅ & CI-wired** — lives in the tracked CRM repo:
`2_Sales CRM/scripts/check_pd_sync.py` + `scripts/_peb_key_contract.json`, npm script
`check:pd-sync`. Calibration learned in build: the bridge **intentionally over-emits** the
full BSF spec (the `.txt` also feeds SketchUp + the data-download), so **C3 (read-not-emitted)
and C5 (Plan≠Section) are the hard failures**; C1/C2 (emitted-not-drawn) is informational.
Run `npm run check:pd-sync` (or `python scripts/check_pd_sync.py -v`) from `2_Sales CRM`. It
reads the bridge in-repo and the AutoLISP engine via `PEB_ENGINE_DIR` (default = the local
engine path); if the engine dir is absent it **skips (exit 0)** so a CRM-only CI checkout
never hard-fails. Current run: **PASS** — 169 over-emission keys info, 17 known items allowlisted.

---

## 3. LAYER 3 — the shared INTERPRETATION CORE (`_peb_core.lsp`)

**The rule.** Plan and Section must interpret a BSF row **identically**. The reader, the
`MSPL-*` accessors, the frame-code map and `peb-v3-to-legacy` live in ONE shared file loaded
before both — they cannot diverge because there is one copy.

Full spec (canonical union, load-wiring, execution gate) → **`PD_MASTER_REFERENCE.md §6`**.
Status: **[render-gated]** — designed, additive-only, needs a render check on
mezzanine/crane/butterfly/multi-gable before it ships. Until then, Layer 2 check #5 holds the
line by failing the build if the two copies drift again.

---

## 4. LAYER 4 — the DEFAULT POLICY (no silent fabrication)

**The rule.** A blank BSF field must never print a *confident engineering value* nobody
entered (C4). Every contract key carries a `default.policy`, one of three:

| Policy | Meaning | Example keys |
|---|---|---|
| **required** | Generation is **blocked** with a clear message until the BSF supplies it | `CR_CAP`, `MZ*_FLOOR_THK`, `DL_LIVE_ROOF`, crane span, hook height |
| **blank-ok** | Emit blank → the drawing prints a visible `—` / `TBD`, which review catches | dimension refs, optional notes |
| **safe-default** | A value that is genuinely universal and correct when unspecified | `BP_DIM_DISPLAY=mm`, `OW_*=Fully Sheeted`, panel `0.50 mm AZ150` |

**Migration from today:** every current hardcoded default (listed in `PD_MASTER_REFERENCE.md
§4d`) is reclassified into one of the three. The load-bearing engineering numbers
(loads, capacities, slab/joist/stair sizes) move from silent `safe-default` to **required**.
**[render/UX-gated]** — this changes generation behavior, so it's owner-approved per key.

---

## 5. LAYER 5 — REALTIME sync (the freshness contract)

**The rule.** The drawing is a **pure, deterministic function** of `(BSF row + tick
selection)`. Therefore:

1. **Any BSF edit invalidates the drawing.** On save of an inquiry's building/area/components,
   stamp a `drawings_dirty = true` (or compare a content hash) so the UI knows the current
   DXF/DWG/PDF is stale.
2. **Regeneration is always full re-derivation** from the BSF via the one bridge — never a
   patch of the old drawing. This is why determinism + Layer 1 contract = the drawing can't
   silently disagree with the BSF.
3. **Realtime surface (two options):**
   - *On-demand (today):* `GET/POST /inquiries/:id/drawings*` regenerates on open. Add the
     dirty flag so a stale drawing is visibly marked "regenerate".
   - *Eager (enhancement):* on BSF save, kick a background render (debounced) so the drawing is
     ready the instant it's opened — true realtime. **[render-gated]**
4. **Tick-gate stays authoritative** (Foundational rule 1.2): realtime never draws an unticked
   section; changing a tick is a BSF edit → invalidate → regenerate.

**Net effect:** because the drawing is *always* re-derived from the current BSF through the
single contract, and the guard forbids key drift, "realtime sync" reduces to "regenerate on
change" — there is no separate two-way state to keep aligned, so it cannot fall out of sync.

---

## 6. LAYER 6 — the GAP REGISTER (every gap, filled with a disposition)

"Fill the gaps" = every known gap gets an owner-visible disposition. Code changes that touch
drawing output are **[render-gated]**.

| Gap | Class | Disposition |
|---|---|---|
| `RM_CONSTRUCTION_TYPE` → `RM_CONSTR` | C1 | ✅ **DONE** (drawingData.ts:454, committed 21-Jul) |
| `BP_VALLEY_HEIGHT` emitted, unread | C2 | ✅ **WIRED 21-Jul** — `draw-bf-frame` gained a `valleyH` param → butterfly valley Y = the key (mm), else `H`. Render-verified (valley=4000). |
| `BP_COL_WEB_STYLE` (Tapered/Straight) unread | C2 | ✅ **WIRED 21-Jul** — "Straight" ⇒ `cb:=ht` (constant-depth end column, vertical inner face); blank/"Tapered" unchanged. |
| `BP_EXT/INT_BASE_COND` (Pinned/Fixed) unread | C2 | ✅ **WIRED 21-Jul** — "Fixed" ⇒ 4-bolt moment base vs 2-bolt pinned (`*BASE-BOLTS*` per column group). |
| `BP_EAVE_TYPE` / `BP_GABLE_TYPE` unread | C2 | ✅ **DROPPED 21-Jul** — spec-text; already consumed by estimation + TFP via raw `a.eaveType`/`a.gableType`. Cross-section has no per-type geometry (future speccable feature). |
| `BP_GABLE_COUNT`, `BP_DIM_REF` unread | C2 | ✅ **DROPPED 21-Jul** — redundant (count derived from grid; DIM_REF an alias). Removed from bridge; no consumer. |
| `BP_WELD_TYPE` unread | C2 | ✅ **DROPPED 21-Jul** — spec-text (never section geometry); consumed by estimation/TFP via `a.filletWeld`. |
| `BP_GROUND_CH` / `BP_FIRST_CH` read, unemitted (F2) | C3 | ✅ **DONE 21-Jul** — emitted by the bridge (blank until UI captures them; engine splits eave height on blank). Removed from contract `readNotEmittedKnown`. |
| `MZ_OFFSET_FROM/TO` read, unemitted | C3 | ✅ **DONE 21-Jul** — emitted (blank ⇒ nil ⇒ grid-bay placement, exact current behaviour). Removed from contract. |
| **Mezzanine floor count capped at 3** (bridge `MZ1..3`, engine `MZ<n>` drawers, contract `indexed.MZ=3`) | requirement | **PROVISION for UNLIMITED mezzanine floors (user choice); keep default = 1 (as today).** Lift the cap in three places together: bridge instance loop, engine `MZ<n>` drawers, and `_peb_key_contract.json.indexed.MZ`. Default stays one mezzanine. **[render-gated]** |
| Silent engineering defaults (loads/capacities/sizes) | C4 | **RECLASSIFY** to `required` per Layer 4. **[UX-gated]** |
| Plan/Section `peb-v3-to-legacy` drift | C5 | ✅ **DONE 21-Jul** — reconciled IN PLACE to one canonical body in both files (`peb-v3-to-legacy`, `peb-frame-display-to-code`, `peb-build-sheeting-string`); guard now enforces byte-identity, `knownCoreDrift: []`. (Physical `_peb_core.lsp` extraction skipped — decentralised load paths make it crash-prone; the CI guard is the single-source guarantee.) Fixed a real latent bug: Section drew G+1 as clear-span. |
| Unemitted DB fields worth drawing: `xBracingNSW/FSW/LEW/REW`, `eaveLow/eaveHigh`, `archRise` | C3 | **REVIEW** — these change how the frame looks; decide wire vs out-of-scope. Owner. |
| Unemitted DB fields (material/estimation/notes) | — | **OUT OF SCOPE** by design (geometry-only rule 1.4) — recorded in `PD_MASTER_REFERENCE.md §4e`, no action. |

---

## 7. How the layers combine → the zero-conflict guarantee

```
   BSF row  ──(one bridge)──►  PEB_Data (keys ∈ CONTRACT)  ──(shared core)──►  drawing
      │             │                    │                        │
   Layer 5      Layer 1              Layer 2 guard            Layer 3 core
  freshness    one schema        every key checked         one interpretation
      │             │                    │                        │
      └─ Layer 4 default policy: no blank prints a fabricated engineering value ─┘
```

- A **new key** can't be added on one side only — the guard (L2) fails until it's in the
  contract (L1) and has both an emitter and a reader.
- A **renamed key** can't drift — one spelling in the contract; both sides validated (kills C1).
- **Plan and Section** can't split — one shared core (L3); the guard diffs them until then (kills C5).
- A **blank field** can't fabricate — default policy (L4) makes it `required` or visibly blank (kills C4).
- A **stale drawing** can't persist — any BSF edit invalidates and re-derives (L5) (kills C6).

Result: the only way a BSF value fails to reach the drawing is a gap that is **listed in the
register (L6) with an owner** — never a silent one.

---

## 8. ROLLOUT ORDER (safe → render-gated)

| Step | What | Risk | Gate |
|---|---|---|---|
| 1 | ✅ RM_CONSTR rename | none | done |
| 2 | ✅ `_peb_key_contract.json` authored | none (data) | done |
| 3 | ✅ Drift guard `check_pd_sync.py` (C3+C5 hard-fail, C1/C2 info) — runs PASS | none (read-only) | done |
| 4 | Drop the pure-dead keys (`BP_GABLE_COUNT`, `BP_DIM_REF`) from the bridge | very low | **owner decision** (also feed SketchUp/download — confirm before dropping) |
| 5 | ✅ **DONE 21-Jul** — Emit `BP_GROUND_CH`/`FIRST_CH`, `MZ_OFFSET_*` (C3) | low | done |
| 6 | ✅ **DONE 21-Jul** — Single-source core reconciled in place (not a separate file); guard enforces | medium | done |
| 7 | Default-policy reclass → `required` for engineering values (L4) | medium (UX) | **[owner + UX]** |
| 8 | Wire the fidelity fields (valley height, web style, base condition) (C2) | medium | **[render-gated]** |
| 9 | Eager background render on BSF save (L5 realtime) | medium | **[render-gated]** |

Steps 2–4 are safe to do in the documentation/tooling phase. Steps 5–9 change drawing output
and wait for a render-verification window.
