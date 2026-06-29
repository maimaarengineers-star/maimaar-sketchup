# MAIMAAR PEB — COMPREHENSIVE WHERE-USED DATABASE
### The master cross-reference: every LINE and every COMPONENT → which sheet uses it.
World-class PEB proposal-drawing system. One brick standard, assembled into every sheet.

**Sheet set (columns):**
`Cov` Cover · `Plan` Column Layout · `AB` Anchor-Bolt · `Roof` Roof Plan ·
`Sec` Cross-Section · `Elv` Wall Elevations · `WF` Wall Framing · `RF` Roof Framing.

` ● ` = used · ` – ` = not used.

---

## A) BASIC LINE / BRICK USAGE  (line × sheet)
| Brick (line) | Cov | Plan | AB | Roof | Sec | Elv | WF | RF |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| BORDER | ● | ● | ● | ● | ● | ● | ● | ● |
| TITLEBLOCK / strip | ● | ● | ● | ● | ● | ● | ● | ● |
| TEXT | ● | ● | ● | ● | ● | ● | ● | ● |
| LEADER (callout) | – | ● | ● | ● | ● | ● | ● | ● |
| DIMENSIONS *(magenta)* | – | ● | ● | ● | ● | ● | ● | ● |
| GRID-LINES *(grey CENTER)* | – | ● | ● | ● | ● | ● | ● | ● |
| GRID bubble *(circle 150)* | – | ● | ● | ● | ● | ● | ● | ● |
| GRID-TEXT *(number)* | – | ● | ● | ● | ● | ● | ● | ● |
| SHEETING *(outline, cyan)* | – | ● | ● | ● | – | ● | ● | ● |
| COLUMNS *(red 0.50)* | – | ● | ● | – | ● | – | – | – |
| COL-CENTER | – | ● | ● | – | – | – | – | – |
| PLATES *(base plate)* | – | – | ● | – | ● | – | – | – |
| BOLTS *(anchor)* | – | – | ● | – | ● | – | – | – |
| CROSS *(bracing, full X)* | – | ● | – | – | – | – | ● | ● |
| RIDGE | – | ● | – | ● | ● | – | – | ● |
| RAFTER | – | ● | – | – | – | – | – | ● |
| ARROWS *(FALL/slope)* | – | ● | – | ● | – | – | – | – |
| AREA-MARK *(area tag)* | – | ● | – | ● | – | – | – | – |
| OPEN *(door/window)* | – | ● | – | – | – | ● | – | – |
| GUTTER | – | – | – | – | ● | ● | – | – |
| FRAME *(main frame)* | – | – | – | – | ● | – | – | – |
| FRAME-FILL | – | – | – | – | ● | – | – | – |
| PURLINS | – | – | – | – | ● | – | – | ● |
| GIRTS | – | – | – | – | ● | ● | ● | – |
| CLADDING | – | – | – | – | ● | ● | – | – |
| BRICK-WALL | – | – | – | – | ● | ● | – | – |
| RCC-COLUMN | – | – | – | – | ● | – | – | – |
| HATCHR *(concrete poché)* | – | – | – | – | ● | – | – | – |

---

## B) PEB COMPONENT USAGE  (IF component × sheet)
The 14 optional components captured in the Inquiry Form, and where each one is drawn.
| Component (from IF) | Plan | AB | Roof | Sec | Elv | WF | RF |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Crane system | ● | – | – | ● | ● | – | – |
| Roof monitor | – | – | ● | ● | ● | – | ● |
| Mezzanine | ● | – | – | ● | ● | – | – |
| Canopy | ● | – | – | ● | ● | – | – |
| Fascia | – | – | – | ● | ● | – | – |
| Partition | ● | – | – | ● | – | – | – |
| Stairs | ● | – | – | – | ● | – | – |
| Roof platform | – | – | ● | ● | – | – | ● |
| Cat walkway | – | – | ● | – | – | – | – |
| Roof extension | ● | – | ● | ● | ● | – | – |
| Open wall | ● | – | – | – | ● | – | – |
| Liner panel | – | – | – | ● ¹ | – | – | – |
| Doors / windows | ● | – | – | – | ● | ● | – |
| Roof / wall accessories *(skylight, ridge-vent, louver…)* | – | – | ● | – | ● | – | ● |

¹ liner = a spec NOTE on the section (no distinct geometry).

---

## C) HOW EACH SHEET IS ASSEMBLED (which bricks build which body)
- **Cover** = BORDER + TITLEBLOCK + TEXT (+ logo).
- **Column Layout Plan** = SHEETING + GRID-LINES + GRID + COLUMNS + COL-CENTER + CROSS + RIDGE + RAFTER + ARROWS + AREA-MARK + OPEN + DIMENSIONS + LEADER + TEXT.
- **Anchor-Bolt Plan** = SHEETING + GRID + COLUMNS + PLATES + BOLTS + DIMENSIONS + TEXT.
- **Roof Plan** = SHEETING + GRID + RIDGE + ARROWS + AREA-MARK + roof accessories + DIMENSIONS.
- **Cross-Section** = FRAME(+FILL) + COLUMNS + PLATES + BOLTS + RIDGE + PURLINS + GIRTS + CLADDING + GUTTER + BRICK-WALL/RCC + HATCHR + DIMENSIONS + LEADER + TEXT.
- **Wall Elevations** = SHEETING + GRID + GIRTS + CLADDING + OPEN + GUTTER + DIMENSIONS + TEXT.
- **Wall Framing** = SHEETING + GRID + GIRTS + CROSS + DIMENSIONS + TEXT.
- **Roof Framing** = SHEETING + GRID + RIDGE + RAFTER + PURLINS + CROSS + DIMENSIONS + TEXT.

> The same brick (e.g. GRID, RIDGE, DIMENSIONS) recurs across many sheets — that shared reuse IS the universal system. Fix a brick in `Standard.lsp` once → every sheet here updates.
