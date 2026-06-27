# Proposal-Drawing COVER (PRO-00) — Layout Rules

How the cover sheet is built so it stays **world-class, consistent, and dynamic**
for every future project. Engine: `engine/MAIMAAR_PEB_Cover.lsp` (`peb-cover-draw`).
The cover matches the **Mammut cover** format (clean, no side title-strip) and is
fully driven by the Inquiry Form (IF) data file.

## The golden rules

**R1 — Everything is canvas-relative.**
The sheet is `Hc` (height) × `Wc` (width), centre `cx`. EVERY position and text
height is a *fraction of Hc*. So the cover is resolution-independent — it looks
identical at any plotted size. Move a block → change its Y-fraction; resize text →
change its height-fraction. Nothing is in absolute mm.

**R2 — Zones (Y, as fractions of Hc), top → bottom**

| Zone | Y range |
|---|---|
| Logo | 0.772 – 0.960 |
| Company name | 0.745 |
| Tagline | 0.714 |
| Contact line | 0.687 |
| Brand accent rule (green) | 0.666 |
| **PROPOSAL DRAWING banner** | 0.448 – 0.642 |
| PROPOSAL / QUOTE NO. box | 0.366 – 0.424 |
| List of Drawings + Title Block | 0.045 – 0.300 |
| Footer (NOT FOR CONSTRUCTION) | 0.022 |

**R3 — AUTOFIT is the rule for variable text** (the important one).
Every variable value is drawn with `(tb-fith TEXT MAXWIDTH CAPHEIGHT)`, which
returns a text height so `TEXT` fits `MAXWIDTH` on one line, capped at `CAPHEIGHT`.
→ A longer name in a future project **shrinks automatically and never overflows**.
- `MAXWIDTH` = the box width × a margin factor (use **0.84–0.95**).
- `CAPHEIGHT` = the desired / maximum height for that field.
- **Bold CAPITAL text is wide.** For big hero text (the PROPOSAL DRAWING banner)
  fit against the *inner* box width with divisor ~**0.78** so letters never touch
  the box lines.

**R4 — Wrap rule for long values that must stay big.**
The **PROJECT TITLE** sits in a *taller* cell (`rt`) and may wrap to **2 lines
inside** the cell. Standard rows use `rh`. To allow longer titles, increase `rt`;
to allow more wrap elsewhere, give that row a taller height too.

**R5 — All text is UPPERCASE.** IF values pass through `(strcase …)`; static text
is typed in capitals.

**R6 — Colours (ACI).** white 7 = lines / hero text · blue 5 = company name ·
green 3 = brand accent + live IF values · grey 8 = field labels · red 1 =
NOT-FOR-CONSTRUCTION. The **inner border is green** (brand frame, modern accent).

**R7 — One knob per field.** To tune a field, change ONLY its `CAPHEIGHT` (size)
or its zone-fraction (position) — nothing else depends on it. No values are
hard-typed; they all come from the IF, so a different project just flows through.

## To restyle for a future need
- Bigger hero word → raise the banner box fraction range + its `CAPHEIGHT`.
- Different brand colour → change the `green`/`blue` ACI in `peb-cover-draw`.
- Add/remove a row in the title block → adjust the `rh`/`rt` split and the row list.
- The values themselves never need code edits — they are the IF fields
  (project, customer, building name, quote, date, rev, prepared/checked).

## Verified dynamic
Stress-tested with a very long project name + customer: both wrapped/shrank
inside their cells with no overflow into neighbouring rows.
