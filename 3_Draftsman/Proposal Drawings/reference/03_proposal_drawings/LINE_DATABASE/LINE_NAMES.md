# MAIMAAR PEB — LINE NAMES (complete nomenclature for coding)
### Every line has ONE name (= its layer). Draw it with the listed primitive on that name.
Single source = `engine/MAIMAAR_PEB_Standard.lsp`. To draw any line: `(peb-xxx … "NAME")`.

## SHEET / TITLE BLOCK
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `BORDER` | sheet border | white 7 · Continuous · 0.50 | `peb-rect` |
| `TITLEBLOCK` | title-block body lines | red 1 · Continuous · 0.35 | `peb-line` |
| `TB-HEADER` | title-block header bar | red 1 · Continuous · 0.50 | `peb-line` |

## GRID SYSTEM
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `GRID` | grid bubble (CIRCLE) | 150 · Continuous · 0.13 | `peb-bubble` |
| `GRID-TEXT` | grid bubble number/letter | 150 · Continuous · 0.09 | `peb-text` |
| `GRID-LINES` | grid axis lines | grey 8 · CENTER · 0.09 | `peb-line` |

## COLUMNS
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `COLUMNS` | column I-section (flanges+web) | red 1 · Continuous · 0.50 | `peb-solid`/`peb-rect` |
| `COL-CENTER` | column centre-line (plan) | red 1 · CENTER · 0.09 | `peb-line` |
| `CL` | column/member centre-line (section) | red 1 · CENTER · 0.09 | `peb-line` |
| `COLUMN-HATCH` | column poché fill | grey 8 · Continuous · 0.09 | `peb-hatch` |
| `COL-OUTER` | reference rect at column face | cyan 4 · DASHDOT · 0.09 | `peb-rect` |
| `BOLTS` | anchor bolts | white 7 · Continuous · 0.09 | `peb-circle` |
| `PLATES` | base plates | white 7 · Continuous · 0.35 | `peb-rect` |
| `RCC-COLUMN` | RCC concrete column | grey 8 · Continuous · 0.35 | `peb-rect` |

## PRIMARY STEEL / FRAME
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `STRUCTURE` | rafters / members (generic) | white 7 · Continuous · 0.25 | `peb-line` |
| `FRAME` | section main-frame outline | white 7 · Continuous · 0.50 | `peb-poly` |
| `FRAME-FILL` | frame poché | grey 8 · Continuous · 0.09 | `peb-hatch` |
| `CROSS` | cross-bracing X (full) | cyan 4 · DASHED · 0.18 | `peb-line` |
| `RIDGE` | ridge line | blue 5 · HIDDEN · 0.18 | `peb-line` |
| `RAFTER` | rafter centre-line | grey 8 · HIDDEN · 0.09 | `peb-line` |

## SECONDARY / ENVELOPE
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `PURLINS` | roof purlins | magenta 6 · Continuous · 0.13 | `peb-line` |
| `GIRTS` | wall girts | magenta 6 · Continuous · 0.13 | `peb-line` |
| `SHEETING` | building outline / sheeting face | cyan 4 · Continuous · 0.09 | `peb-rect` |
| `CLADDING` | cladding line | blue 5 · Continuous · 0.18 | `peb-line` |
| `GUTTER` | eave gutter | cyan 4 · Continuous · 0.18 | `peb-line` |

## ANNOTATION
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `DIMENSIONS` | dimension chains | magenta 6 · Continuous · 0.13 | `peb-dim` |
| `ARROWS` | FALL / slope marker + dim ticks | green 3 · Continuous · 0.13 | `peb-solid`/`peb-line` |
| `TEXT` | labels, notes, leaders | white 7 · Continuous · 0.13 | `peb-text`/`peb-leader` |
| `AREA-MARK` | area tag (boxed AREA-0N) | grey 8 · Continuous · 0.18 | `peb-rect`/`peb-text` |
| `OPEN` | doors / windows / openings | magenta 6 · Continuous · 0.18 | `peb-poly`/`peb-arc` |

## MASONRY / GROUND / FILLS
| NAME | what it is | colour · linetype · lw | primitive |
|---|---|---|---|
| `BRICK-WALL` | brick / block wall | brown 30 · Continuous · 0.25 | `peb-line` |
| `GROUND` | ground / FFL line | white 7 · Continuous · 0.50 | `peb-line` |
| `GROUND-HATCH` | ground hatch | grey 8 · Continuous · 0.09 | `peb-hatch` |
| `HATCHR` | RCC / concrete poché | orange 32 · Continuous · 0.30 | `peb-hatch` |
| `HATCH` | light fill (existing/future) | grey 8 · Continuous · 0.05 | `peb-hatch` |

---
**Coding rule:** never draw raw — always `(peb-primitive … "NAME")`. The NAME (layer) carries
the colour/linetype/lineweight automatically (BYLAYER). Change a line's look = edit its one row
in `Standard.lsp` `*PEB-LAYERS*`. Where each name is used = `WHERE_USED.md`.
