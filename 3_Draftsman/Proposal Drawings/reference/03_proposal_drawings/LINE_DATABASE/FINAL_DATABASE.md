# MAIMAAR PEB — FINAL DATABASE (best of both sources, decided)
### The single, finalized line/brick standard — best of **Phase-2** + **real Mammut**, owner-locked.
Source codes: **[P2]** Phase-2 engine · **[MAM]** real Mammut (measured) · **[BOTH]** they agreed · **[OWN]** owner override.

## STRUCTURAL GEOMETRY (Phase-2 = the gold)
| Element | FINAL rule | Source |
|---|---|---|
| **MS Column** | built-up **I-SECTION** (flanges + web + 4 bolts, web sized by span) | **[P2]** |
| **Base plate** | **plate + 4 anchor bolts** | **[P2]** |
| **Section frame** | tapered cigar frame + haunch/ridge connection plates | **[P2]** |
| **Grid bubble shape** | **CIRCLE** | **[P2]/[OWN]** |

## LINE STYLE (colour · linetype · lineweight)
| NAME (line) | FINAL | Source |
|---|---|---|
| `SHEETING` (outline) | **cyan 4** · Continuous · 0.09 | **[P2]/[OWN]** |
| `GRID` (bubble) | **150** · Continuous · 0.13 | **[P2]/[OWN]** |
| `GRID-TEXT` (number) | **150** · Continuous · 0.09 | **[P2]/[OWN]** |
| `GRID-LINES` (axes) | **grey 8 · CENTER** dash-dot · 0.09 | **[MAM]** |
| `COLUMNS` | **red 1** · Continuous · **0.50** | **[BOTH]** colour · **[MAM]** lw |
| `COL-CENTER` / `CL` | red 1 · CENTER · 0.09 | **[BOTH]** |
| `CROSS` (bracing) | **cyan 4 · DOT (dotted) · 0.18** — sidewall-pair X (NSW + FSW, between adjacent columns in the column-depth band) per braced bay | **[OWN]** Zealcon Eng. |
| `RIDGE` | blue 5 · HIDDEN · 0.18 | **[BOTH]** |
| `RAFTER` | grey 8 · HIDDEN · 0.09 | **[BOTH]** |
| `DIMENSIONS` | **magenta 6** · Continuous · 0.13 + arch tick | **[MAM]** |
| `FALL` | **red 1** glyph + "FALL" (no 1:10 on plan) | **[MAM]** |
| `ARROWS` | green 3 · 0.13 (dim ticks) | **[P2]** |
| `TEXT` | white 7 · 0.13 | **[BOTH]** |
| `LEADER` (callouts) | white 7 · 0.13 + arrow | **[BOTH]** |
| `AREA-MARK` (area tag) | grey 8 · 0.18 — boxed AREA-0N | **[P2]** |
| `OPEN` (door/window) | magenta 6 · 0.18 | **[BOTH]** |
| `BOLTS` | white 7 · 0.09 | **[BOTH]** |
| `PLATES` | white 7 · 0.35 | **[BOTH]** |
| `GUTTER` | cyan 4 · 0.18 | **[BOTH]** |
| `PURLINS` / `GIRTS` | magenta 6 · 0.13 | **[BOTH]** |
| `CLADDING` | blue 5 · 0.18 | **[BOTH]** |
| `BRICK-WALL` | brown 30 · 0.25 | **[BOTH]** |
| `RCC-COLUMN` | grey 8 · 0.35 | **[BOTH]** |
| `HATCHR` (concrete) | orange 32 · 0.30 | **[MAM]** |
| `BORDER` | white 7 · 0.50 | **[MAM]** |
| `TITLEBLOCK` / `TB-HEADER` | red 1 · 0.35 / 0.50 | **[BOTH]** |

## DROPPED (not used in the final)
- Bowtie bracing → replaced by FULL X.
- Green slope arrow + "1:10" on the plan → replaced by red FALL glyph (1:10 lives in Section).
- Plain plate (no bolts) → replaced by plate + 4 bolts.
- Square column placeholder → replaced by I-section.
- The duplicate Phase-2 inline layer blocks in Plan/Section → dropped (single source = `Standard.lsp`).

## The verdict in one line
**Geometry = Phase-2 (the gold). Style = real Mammut + your locked colours.** One source (`Standard.lsp`), no duplicates, every line named (`LINE_NAMES.md`), every line placed (`WHERE_USED.md`), every line drawn through a `peb-*` primitive (BYLAYER).
