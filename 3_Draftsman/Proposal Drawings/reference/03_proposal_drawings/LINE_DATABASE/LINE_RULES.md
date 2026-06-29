# MAIMAAR PEB — LINE RULES (owner-locked)
### The authoritative rule for every brick. The engine MUST obey this; `Standard.lsp` is its code form.

Status key: **🔒 OWNER-SET** = Nasir decided · **✓ settled** = old / new / real all agree (auto-locked).

## Owner decisions (29-Jun-2026)
| Brick | RULE (locked) | Why |
|---|---|---|
| **GRID bubble** | 🔒 **CIRCLE · ACI 150** (number ACI 150) | kept your original — not the pentagon |
| **GRID-LINES** | 🔒 **grey ACI 8 · CENTER (dash-dot)** | real Mammut match |
| **DIMENSIONS** | 🔒 **MAGENTA ACI 6** · arch tick · 0.13 | real Mammut match |
| **SHEETING (building outline)** | 🔒 **CYAN ACI 4** · Continuous · 0.09 | kept your original |

## Geometry decisions (compare Phase-2 vs Zealcon → choose best)
| Element | RULE (locked) | Why |
|---|---|---|
| **MS Column** | 🔒 **Built-up I-SECTION** (Phase-2: flanges + web + 4 bolts, web sized by span) | shows the real steel member; the square repro was only a placeholder. Already the production `draw-I-column-lengthwise` — no change. |

## Full locked rule set (every brick)
| Brick (layer) | Colour | Linetype | LW mm | Shape / object | Status |
|---|---|---|---|---|---|
| SHEETING (outline) | cyan 4 | Continuous | 0.09 | rectangle | 🔒 |
| BORDER | white 7 | Continuous | 0.50 | rectangle | ✓ |
| GRID-LINES | grey 8 | **CENTER** | 0.09 | line | 🔒 |
| GRID (bubble) | **150** | Continuous | 0.13 | **CIRCLE** | 🔒 |
| GRID-TEXT (number) | **150** | Continuous | 0.09 | text | 🔒 |
| COLUMNS | red 1 | Continuous | **0.50** | I-section | ✓ |
| COL-CENTER | red 1 | CENTER | 0.09 | line | ✓ |
| PLATES | white 7 | Continuous | 0.35 | rectangle | ✓ |
| BOLTS | white 7 | Continuous | 0.09 | circle | ✓ |
| CROSS (bracing) | cyan 4 | DASHED | 0.18 | **single full X** | ✓ |
| RIDGE | blue 5 | HIDDEN | 0.18 | line | ✓ |
| RAFTER | grey 8 | HIDDEN | 0.09 | line | ✓ |
| ARROWS (FALL/slope) | green 3 | Continuous | 0.13 | line + solid head | ✓ |
| DIMENSIONS | **magenta 6** | Continuous | 0.13 | dimension + tick | 🔒 |
| TEXT | white 7 | Continuous | 0.13 | text / mtext | ✓ |
| LEADER (callout) | white 7 | Continuous | 0.13 | leader | ✓ |
| AREA-MARK | grey 8 | Continuous | 0.18 | box + text | ✓ |
| OPEN (door/window) | magenta 6 | Continuous | 0.18 | poly + arc | ✓ |
| GUTTER | cyan 4 | Continuous | 0.18 | line | ✓ |

## Rule of use (strict)
Every line is laid as a named brick via a `peb-*` primitive (BYLAYER). Change a rule here → change the one row in `Standard.lsp` `*PEB-LAYERS*` → every sheet updates. Bubble shape is set in `peb-bubble` (currently `peb-circle`; `peb-pent` kept available).

> Open `BASIC_LINE_UNITS.dxf` to see these rules drawn. Re-generate after any rule change.
