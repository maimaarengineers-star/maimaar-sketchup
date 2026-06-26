# Maimaar PEB Connection Rules (extracted from real approval drawings)

Mined from **133 approval drawings (latest revision per job, 2022–2026)** — DWGs exported
to DXF (`D:\autocad_approval\dxf\`) and parsed with `ezdxf`. Counts below are across all
133 drawings, so they reflect Maimaar's actual standard practice (not one project).

## Bolts (hole diameters detected → bolt size)
| Bolt | Hole-dia count | Use |
|---|---|---|
| **M20** | 26,684 | PRIMARY moment connections (knee/ridge end-plates) + most splices |
| **M24** | 18,629 | heavier frames / base anchors |
| **M16** | 1,713 | lighter connections, chemical anchors |
| **M12** | ~168 + "12mm Ø bolts" callouts | SECONDARY — purlin/girt to clip/cleat |
| M30 / M36 | callouts (98 / 95) | the heaviest frames |
Anchor variants seen: `M20×500 anchor bolt`, `M24×625 J-bolt`, `M24×600 stud bolt`,
`M16×300 chemical anchor`.

## Secondary members (exact sections)
- **Purlin / Girt / Eave strut = 200Z**: `Z 200×60×20×(1.5–2.0 mm)` (depth 200, flange 60,
  lip 20, gauge 1.5 or 2.0). Heaviest eave strut also seen as `275Z×2.0`.
- **Sag rod Ø12 mm** — between purlins (roof) and girts (walls).
- **Flange brace** — angle from the rafter/column INNER flange out to a purlin/girt (stability;
  "FLANGE BRACE DETAIL" on 46 drawings).
- **Eave purlin / eave strut** runs along the eave line tying the frames.

## Primary connections
**Base** (217 "BASE PLATE", 134 "ANCHOR BOLT SCHEDULE"):
- ~**20 mm thick** base plate, **4 anchor bolts** per column.
- Anchor assembly = **"one 'L'-shaped anchor bolt, 2 hex nuts and 1 washer"** (verbatim).
- Threaded projection dimensioned ("T : threaded bolt projection").

**Knee (column↔rafter)** — verbatim NOTE on 47 drawings:
- "@ KNEE [web thk] **≥ 8 mm → BACK-UP PLATE generally NOT provided**."
- "For cases where **knee depth < 400 mm and web thk [< 8 mm] → back-up plate provided**."
- Bolted **end-plate** (M20/M24), **hillside washers**, **flat washers**, hex nuts.

**Ridge / apex** — bolted end-plate (M20/M24), same family as the knee.

**Cable / rod bracing** — `EYE BOLT`, `BRACE GRIP`, `STEEL STRAND`, `HIGH STRENGTH CABLE`,
`HILL SIDE WASHER` → cross-bracing is high-strength cable with eye bolts + brace grips.

## What this changes in the generator (sketchup_generator)
| Element | Old (approx) | New (from drawings) |
|---|---|---|
| Z purlin/girt | 200 deep × 75 flange | **200 × 60 × 20** (lip), gauge 1.5–2.0 |
| Eave strut | (none) | **200Z along both eaves** |
| Sag rods | (none) | **Ø12 mm** rods between purlins/girts |
| Flange braces | (none) | angle braces frame-flange → secondary |
| Connection bolts | generic | **M20** primary, **M12** secondary clips, **M24** base anchors |
| Base anchors | 4 generic | **4 × L/J-shaped** anchor bolts (M20–M24), 20 mm plate |
| Knee back-up plate | always gusset | per rule: web ≥ 8 mm → none; depth<400 & web<8 → add |

## Measured plate dimensions (dimension values near callouts, 133 drawings)
- **Knee / end-plate:** plate ≈ **225 × 520 mm** (also 450/540 common); bolt pitch ~40–175 mm.
  NB the bolted END-PLATE (~520 mm) is shorter than the full haunch web depth — the haunch
  (deep tapered web) and the end-plate are different things.
- **Base plate / anchors:** edge/gauge values cluster at 50, 75, 100, 125, 150 mm; bolt
  spread 200–300 mm; reach up to ~660 mm on the largest columns. Base plate ~320 × 490 × 22.
- Encoded: real end-plate component (264×682×11) + base plate 320×490×22 + M20/M24 bolts.

## Source
- Drawings: `D:\autocad_approval\dxf\*.dxf` (133) — from `E:\…\Jobs` 2022–2026, latest rev.
- Scanner: `sketchup_study` (ezdxf): bolt-circle diameters + connection text callouts.
