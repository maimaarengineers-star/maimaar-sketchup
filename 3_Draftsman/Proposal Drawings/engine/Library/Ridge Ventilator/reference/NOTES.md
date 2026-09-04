# RIDGE VENTILATOR REFERENCE — what is here and what was read off it

The ridge ventilator is the **OUTLET** of the ventilation system. The louvers are the intake
(see `../../louver/`): air enters low through the louvers, warms, rises, and is discharged at
the ridge. The two are one system, and neither works without the other.

## The sources

| File | What it is |
|---|---|
| `TechnicalManual_p344-356_ventilators.pdf` | Chapter 13 / **Section 13.7 : Ventilators**, all 13 pages, from the industry technical manual (PDF pages 344-356 = printed 345-357). Covers the sizing method, the worked example, both gravity types and the power ventilator. |
| `p344.png` … `p356.png` | The same pages at 170 dpi, so the details can be read without opening a 250 MB PDF. |
| `afridi_text.txt`, `dump_afridi.js` | Text extracted from **203-MSPL** (Afridi Markets / DHL Warehouse, Islamabad, 2025) — the job where the ridge ventilator was **in Maimaar's own scope**. Its DWG is R2004+, so the text is compressed and `strings` finds nothing; AutoCAD has to open it. |

## TRACED — the specification table (printed p349, "Specifications for Gravity Ridge Ventilators")

| | **MRV 300** | **MRV 600** |
|---|---|---|
| Length | **3000 mm** | **3000 mm** |
| Installation | at the ridge, continuous OR single units | same |
| Throat | **300 mm** | **600 mm** |
| **Throat area** | **0.9 m²** | **1.8 m²** |
| Throat opening | Fixed | Fixed |
| **Damper** | **option available** | **option NOT available** |
| Bird screen | 1.06 mm galvanized, 12 × 12 mesh | 2.3 mm galvanized, 16 × 16 mesh |
| Wind band | cold-formed plain sheet, with brace plates (0.5 mm pre-painted) and throat gussets (1.3 mm galvanized) | cold-formed **Profile 'C' panel** with framing — cold-formed channels and hot-rolled angles |
| Main parts | wind bands, top plate, throat flashing, end flashing — **all 0.5 mm pre-painted galvanized steel** | same |

**Throat area = throat × length.** 0.3 × 3 = 0.9 m²; 0.6 × 3 = 1.8 m². It is not a lookup, it is
the arithmetic, so any length works.

**MRV 600 CANNOT TAKE A DAMPER.** The BSF offers throat 300/600 and damper With/Without as two
independent fields, so "600 + With damper" is selectable and is not a real product. Worth a
validation rather than a silent wrong quote.

## The anatomy (printed p351 / p352 — the drawn details)

Named parts, all on the reference isometrics and sections:

- **Top plate** — the ridge cap over the opening; the rain stops here.
- **Wind band** — the side skirt that makes the throat and stops wind-driven rain.
- **Brace plate** — the internal stiffener between wind band and top plate.
- **Throat flashing** and **throat gusset** — where the unit meets the roof sheet at the ridge.
- **End plate** and **end flashing** — the ends; on a continuous run "END PLATES INSTALLED WITH
  NO GAP".
- **Bird screen** — along both throat faces.
- **Damper** (MRV 300 only) with its **lifting mechanism**: operator shaft, pulley wheel,
  operating cable, operating arm, joint shaft and "S" hook.

**How it works, as the section draws it:** *HOT AIR OUT* rises through the throat; *RAIN IN* is
caught by the top plate and wind band and leaves as *RAIN WATER OUT* at both sides. That is why
the top plate overhangs and why the wind bands come down past the throat — the geometry IS the
weather protection, and drawing it flat would misrepresent the product.

**SINGLE vs CONTINUOUS** (printed p350) is the BSF's own `ventType`: discrete 3 m units spaced
along the ridge, or an unbroken run. 266 is **single units, one per bay**.

## The sizing method (printed p345-348) — why the louvers matter

```
Qv = quantity of ventilators        R = exhaust capacity (m³/sec)
V  = building volume (m³)           N = air changes per hour
```

Stack height = the **average of the eave height and the ridge (peak) height**; with the inside/
outside temperature difference it gives the required exhaust capacity from the manual's table.

> "For efficient functioning of the ventilation system the **free inlet area** (permanent
> openings plus the effective area of the louvers) **must be greater than 150% of the
> ventilation area**."

So the ventilators and the louvers are sized against each other, and the louver component's
`peb-lv-free-area` is the other half of this calculation.

**MSPL-26-266 as it now stands:** 6 × MRV 300 at 3 m = **5.4 m² ventilation area**, which
requires **8.1 m² of free inlet area**. The 12 louvers give **5.76 m²** (0.960 each, halved by
the insect screen) — **about 29% short**. Either more louver area, or drop the insect screen
(which alone would double the inlet to 11.5 m²), or fewer ventilators.

## NOT in the manual

The **turbine / turbo ventilator** the BSF also carries (`RA_TURBOVENTS`) is a different product
and has no page here. Do not draw it from these details.
