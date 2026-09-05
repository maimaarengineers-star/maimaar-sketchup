# MBS 169-PK-13 Zealcon Engineering — how Mammut draws a crane on a PROPOSAL

Owner pointed at this, 5-Sep-2026: *"Will help in producing more resembles of crane. Here in PD,
our proposal easy understand about the railing"* / *"you may check the material being used"* /
*"& lines type, lines density"*.

Source: `D:\Misc\Miscellaneous\Personnel\MBS Data\A_Pakistan\Proposals\2013\169-PK-13_Zealcon
Engineering`. Mammut Building Systems FZC, quote PK-013-169, October 2013 — a workshop with a
**20 MT top running overhead crane**. Checked by NASIR, so this is a sheet the owner signed off
himself.

**The DWG was open in the owner's AutoCAD when this was taken** (S10 — never kill his session),
so everything here was made from a COPY at a space-free path.

## Files

| | |
|---|---|
| `PK-13-169_Proposal_Drawings.pdf` | the 5-page proposal set as issued |
| `PK13169.dxf` / `.pdf` | the DWG converted, for reading |
| `HQ-O-50206_20MT_crane_datasheet.xls` | the Mammut estimation workbook for this job |

## 1. On a PROPOSAL cross-section the crane is a SYMBOL, and a small one

Sheet 3 of 4, *TYPICAL RIGID FRAME CROSS SECTION AT GL 2 THRU 4*, carries the crane as:

- the **hoist body** only — a small block with its finned motor, drawn thin and SOLID
- the **hook** under it
- a **long-dash centreline** running the full height of the frame through the lift axis
- the label **`20 (M.T.) TOP RUNNING OVERHEAD CRANE`**
- a dimension **`CRANE HOOK HEIGHT: 7315`**, run from `F.F.L.: 0.00M`
- **`CRANE RUN LENGTH: 30480`** and a **`CRANE BEAM`** callout

**No bridge girder. No end carriage. No wheels.** Everything is on a layer called `Crane`.

That is the convention to follow when this library syncs to the CLP and the Section — it is
GOLDEN_RULES 32 (indicative, not detailed) and the same ruling as the ridge ventilator, which
gets a symbol on the PD and its geometry only on the details sheet. The four-page treatment in
`sample/` is a COMPONENT DEVELOPMENT sheet and is right for development; it is not what goes on
a customer's cross-section.

## 2. Linetype and density — the answer to the owner's question

| element | how Mammut draws it |
|---|---|
| hoist body, hook | **solid**, thin |
| lift axis / travel centreline | **long dash**, full height of the frame |
| scope | said by the **label**, never by a faint linetype |

Which is what this library already does — solid geometry, scope in words — plus one thing it did
not have: **the dashed centreline through the lift axis**. Worth adding when the crane goes onto
the Section.

## 3. Material — the crane beam is a built-up section, and it is priced as one

From `MBSDB` in the workbook:

| code | description | band |
|---|---|---|
| `BUCRB1..5` | **Crane Beam Built-Up with Double Side Welding (HR coil + Flat Bar)** | 47.16 / 66.79 / 91.79 / 107.88 / 139.28 kg per m |
| `BUCRBr3/5/6` | **Crane Bracket Built Up**, priced per number | 27 / 44 / 61 kg each |
| `PPLCRB` | PPL — Crane Beams (the paint line) | — |

Cost codes: **10411** crane beams (including channels), **10111** brackets, **50111** PPL. And
`FCPBS` carries a separate line for *"Second Side Welding (**excl. crane beams**)"* — crane beams
always get double-side welding, so they are excluded from the line that prices it for everything
else.

**This confirms the section drawn on sheet 3 of the library sample.** A crane beam is a built-up
plate girder — HR coil web plus flat-bar flanges, welded both sides — which is exactly MSPL-032's
`PL 8 X 400` web with `PL 10 X 225` flanges, and exactly what Thal 125-23 specifies
(*"built-up sections with double side fillet weld"*). Three independent sources now agree.

## 4. Mammut's own crane envelope

`REV` sheet, note 12, verbatim:

> *"Crane width shall not exceed 30 meters, Capacity not more than 25 Tons and crane beam span
> not more than 9 meters."*

So: span ≤ 30 m, capacity ≤ 25 T, **crane beam span (the runway bay) ≤ 9 m**. Worth carrying as a
validation on the BSF — MSPL-26-276's bays are 7.24 and 8.00, inside it.

## 5. What the estimator asks for

`Input` sheet, the whole crane block:

```
Top Running Crane
Crane Description:  Crane 2        Sales Code:  1
Crane Capacity:     10             Duty:        Medium
Center to Center of Rails: 19.812   BU/HR Finish: Standard
Crane Run:          4@7.62          CF Finish:   Galvanized
```

Five inputs, and **"Center to Center of Rails"** is the span — the same definition Mazzella gives
and the same wording now on page 1 of the library sample. Note the file is titled *20MT* while
the block reads capacity 10: this job carries **two** cranes.
