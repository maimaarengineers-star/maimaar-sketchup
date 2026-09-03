# LOUVER REFERENCE — what is in this folder and what was read off it

## The sources

| File | What it is |
|---|---|
| `TechnicalManual_p357-364_louvers.pdf` | Chapter 13 / **Section 13.8 : Louvers**, all 8 pages, lifted whole from the industry technical manual (PDF pages 357-364 = printed pages 358-365). This is the primary source; every traced number below comes off it. |
| `p357.png` … `p364.png` | The same 8 pages rastered at 170 dpi, so the details can be looked at without opening a 250 MB PDF. |
| `MSPL-107_louvers-elevation-1.pdf`, `-2.pdf` | Maimaar's OWN approval drawings, job 107-MSPL (2023). **A bespoke facade grill, NOT the catalogue wall louver** — blades at 554 / 747 / 946 in a fabricated frame. Kept because it is the only in-house louver drawing found, and it shows how Maimaar dimensions a louver elevation; it is *not* what this component draws. |

Extraction was done with PyMuPDF, not by importing into AutoCAD — the pages are page-sized
vector art, so they raster cleanly and there is nothing to snap to. (The light panel's
`view_reference.js` PDFIMPORT route exists because that reference was a single dimensioned
DETAIL that had to be measured.)

## The drawing pages

- **p360** (printed 361) — *FIXED ALUMINIUM LOUVER WITH SINGLE SKIN PANEL*: SECTION-A, LOUVER
  EXTERIOR, SECTION-B. Drawn at a **1500 louver width**, not the 1000 catalogue standard.
- **p361** (printed 362) — the same three views, *WITH SANDWICH PANEL*: adds the spacer trim,
  the sill trim and the blown-up frame/trim detail.
- **p363** (printed 364) — *ADJUSTABLE ALUMINIUM LOUVER WITH SINGLE SKIN PANEL*, drawn at
  **900 louver width**. SECTION-B shows the blades on pivots with the operating linkage.
- **p364** (printed 365) — the adjustable, *WITH SANDWICH PANEL*.

## TRACED — the numbers the drawer uses

| | Value | Where it is on the sheet |
|---|---|---|
| Frame margin | **22 mm each edge** | dimensioned `22` outside every side of both the plan and the elevation, on all four pages |
| Framed opening width | **louver + 44** | `1500 LOUVER WIDTH` → `1544 FRAMED OPENING WIDTH`; `900` → `944` |
| Framed opening height | **louver + 44** | `1000 LOUVER HEIGHT` → `1044 FRAMED OPENING HEIGHT` |
| Projection off the steel line | **105 mm** | SECTION-A and SECTION-C, left-hand dimension |
| Accessory girt, clear of the framed opening | **48 mm** | SECTION-B chain, head and sill |
| Blade pitch | **100 mm** | derived: `N = 10 openings` in a `1000` louver height (worked example, p358) |
| Clear opening between blades, C | **35 mm** | `C = 0.035 m` in the AEFF worked example, p358 |
| Blade face | **65 mm** | pitch 100 − clear 35 |
| Fasteners | **SDS-4.8x20 self-drilling at 300 O.C.** | SECTION-A callout |
| Standard fixed louver | **1000 x 1000** | p359 text, "available in one size only" |
| Standard adjustable louver | **900 x 1000** | p362 text |

**Free area.** `AEFF = N x C x L` — N openings, C the clear depth between blades in metres, L the
opening length in metres. A 1.0 x 1.0 fixed louver gives `10 x 0.035 x 1.0 = 0.35 m²`. **An
insect screen halves it** ("should be further reduced by 50%", p358). The manual's worked
example — 73.4 m² of required effective area ÷ 0.35 = **210 louvers**, 105 per side wall — is
reproduced by `peb-lv-count-for-area` and printed on the sample sheet as a check.

**Material, per the manual:** tempered aluminium alloy extrusions to ASTM B 221 alloy 6063-T6,
anodized 15 microns minimum; sheet to ASTM B 209; tested to AMCA Standard 500. **Maimaar's BSF
offers something different** — `0.5 mm Polyester Painted AluZinc coated steel` or `0.7 mm
Polyester Painted Aluminum` (components.js `LOUVER_SPEC`), which is why material is an argument
and is never written into the geometry.

## A 10 mm the sheet does not close

SECTION-B carries an overall of **1150** girt to girt, but its own chain reads
`48 + 22 + 1000 + 22 + 48 = 1140`. The 10 mm is not dimensioned anywhere and is most likely the
girt flange. The drawer uses the **chain** (`peb-lv-girt-span` = framed opening + 2 × 48), which
is the part that is actually dimensioned, and this note is the record that the two disagree.
Do not silently adopt 1150 for other sizes — it does not scale.

## NOT on this sheet

- **The sand-trap louver.** Section 13.8 has fixed and adjustable only. Maimaar's BSF offers a
  third type (`LOUVER_SPEC` → `Fixed | Adjustable | Sand-trap`) and the estimator prices it
  separately (`L1X1S5AZ` / `S7AZ` / `S7AL`), so it must be drawable — it is drawn with
  **vertical** blades at the same traced pitch and clear, and labelled **STYLISED** until a real
  sand-trap detail is traced.
- **The blade section.** The reference blade is a rolled Z with a return lip; none of its own
  dimensions are given. It is drawn as a straight drainable slat and said to be stylised.
  Correct dimensions under a straight-line shape is honest (rulebook 4B.24); inventing
  dimensions would not be.
