# Maimaar OS — System Map (organized overview)

_Single source of truth = the **Inquiry Form (IF)** in Sales. Every module reads from it;
nothing is hand-keyed twice._ Last organized: 25-Jun-2026.

## Build health
- `Sales CRM & Estimation Portal/` (Node + TypeScript, hybrid): **typecheck 0 errors, `npm run build` OK.**
- Run: `npm run setup` (migrate+seed) → `npm start` (builds to `dist/`, runs `dist/server.js`).
- Parallel work in flight (other terminals): **Marketing** module (`routes/marketing.ts`,
  `services/leadSla.ts`, `public/modules/marketing/*`) — not touched here.

## The one app + external generators
```
D:\maimaar-os\
├─ Sales CRM & Estimation Portal\   ← the web app (git repo, branch main)
│   routes/  services/  models/  migrations/  public/modules/  dist/
├─ drawing_generator\               ← Python: IF → DXF proposal drawings (2D, verifiable)
├─ sketchup_generator\              ← Python+Ruby: IF → native .skp + 8 snaps (3D, real parts)
└─ sketchup_study\                  ← parts DB + real-component library (calibration source)
```

## Modules (route / UI / role)
| Module | route | UI (public/modules) | Role | Purpose |
|---|---|---|---|---|
| **Sales CRM** | `sales.ts` | `sales/` dashboard, spec | sales | Inquiry Form (IF) — the master record; proposal/exports |
| **Estimation Portal** | `estimation.ts` | `estimation/portal` | estimator | weight + PKR pricing (services/estimation) |
| **Design / Draftsman** | `design.ts` | `design/index` | design | DesignData (tapered-section reference DB); PD + drawings + 3D |
| **Marketing** | `marketing.ts` | `marketing/` board, capture, dashboard | marketing/md | lead intake → Sales (in progress) |
| **AI Feeder** | `aiFeeder.ts` | (in sales) | sales | RFQ upload → Claude pre-fills the IF |
| **Admin / Auth / Master** | `admin.ts` `auth.ts` `master.ts` | `admin/panel` | admin | users, login, master data |

## Draftsman outputs (all generated FROM the IF, customer-blind)
Served from `routes/sales.ts` on an inquiry id:
- `…/proposal.docx` — **PD** (proposal document) — `services/proposalGenerator` + `proposalDoc`
- `…/drawings.dxf` — 2D drawings — `services/drawingDxf` (+ external `drawing_generator/`)
- `…/drawing-data.zip` — feeds the AutoCAD **LISP** engine — `services/drawingData`
- `…/model.dae` — **3D COLLADA** to *import* into SketchUp — `services/colladaExporter`
- **NEW (external) — native `.skp` + 8 rendered snaps** — `sketchup_generator/generate_from_if.py`

## The two 3D paths — reconciled
| | `model.dae` (in-app) | `sketchup_generator` (native) |
|---|---|---|
| Output | COLLADA `.dae` to import | finished `.skp` + 8 PNG snaps |
| Fidelity | tapered frames + cladding | + **real Maimaar components** (end-plates, clips, bolts), bypass purlins/girts, gutters, endwall, masonry — calibrated to 271 real models |
| Needs SketchUp? | no (import later) | yes (runs SketchUp 2021 headlessly server-side) |
| Use | quick browser download / any-CAD | **primary Draftsman deliverable** (mirrors PP models) + proposal snaps |

→ Keep `.dae` as the lightweight fallback; make the **`.skp` generator the primary 3D
deliverable**. Both consume the SAME building model, so no data divergence.

## Integration TODO (to make SketchUp live in the portal)
Add to `routes/sales.ts` (or `design.ts`), mirroring the `.dae` handler:
- `GET …/inquiries/:id/model.skp` and `…/snaps.zip`:
  1. build the canonical model JSON via `services/drawingData` (already used by `drawing-data.zip`),
  2. shell out: `python sketchup_generator/generate_from_if.py <model.json>` (server has SketchUp 2021),
  3. stream back the `.skp` and the 8 snaps.
- This is the only wiring left to surface the native SketchUp output in the Draftsman portal.

## Flow (end to end)
```
Sales fills IF  ──►  (AI Feeder pre-fills from RFQ)
      │
      ├─► Estimation Portal   → weight + PKR price
      ├─► Design/Draftsman    → DesignData sections
      └─► Outputs from the IF → proposal.docx (PD)
                                drawings.dxf / drawing-data.zip (LISP)
                                model.dae (import)  +  model.skp + snaps (native, real parts)  ◄ NEW
Marketing  ──►  feeds new leads into Sales (in progress)
```
