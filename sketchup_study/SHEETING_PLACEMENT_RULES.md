# Maimaar PEB — Sheeting Profiles & Member Placement (from real approval drawings)

Mined from the **133 approval drawings (2022–2026)** (`D:\autocad_approval\dxf\`, parsed with
`ezdxf`). Companion to `CONNECTION_RULES.md`.

## Sheeting / cladding profiles
- **Single-skin = 0.5 mm PPGI / PPGL** (pre-painted galvanised / galvalume), colour-coated.
- **Profile = "TYPE-R" / "HIGH RIB"** — trapezoidal high-rib, for **roof** and **wall** ("ROOF HIGH RIB", "WALL HIGH RIB").
- **Liner panel = 0.5 mm PPGL** (interior liner, on roof and/or walls).
- **Sandwich panel = 75 mm PIR** (walls/roof where insulated); **50 mm PIR** at door leaves (1219×2438).
- **Insulation** (single-skin builds): **50 mm or 100 mm fibreglass** (roof/wall).
- Named areas: roof panel, sidewall panel, endwall panel, ridge panel, liner.

## Trims / edge members (cold-formed angles)
- **Eave angle 80×80×1.5**, **Gable angle 80×80×1.5**, **Corner angle 80×80×1.5** (all TYP.).
- **Sheeting angle 80×50×1.5** (TYP.) — support angle for sheeting at openings/edges.

## Fasteners & spacing (placement)
- **Roof crest fix:** `SDS-5.5×57 @ 250 c/c` + **outside foam closure**.
- **Side-lap / stitch:** `SDS-4.8×20 @ 500 c/c`; flat screw `SSDS018 @ 1000 c/c`; `SDS-5.5×25`.
- Other spacings seen: `@ 300 c/c`, `@ 200 c/c`, `@ 500 c/c`.

## Member placement
- **Purlins / girts = 200Z 1.5 (TYP.)**, lighter walls **150Z 1.5**; eave strut 200Z (see CONNECTION_RULES).
- **Bracing in BRACED BAYS** (74×): **roof bracing Ø12** cable/rod, cross (X) pattern;
  sidewall cable X-bracing in the same bays (typically the end/near-end bays — matches the IF
  model's `resolved.bracing.braced[].reason = "near-end"`).
- **Sag rods Ø12** between purlins/girts (see CONNECTION_RULES).
- **Part marks** seen: MB-xx (main beam/frame), CP-xx (clip/cap plate), J-xx (joint), SL-xx,
  SWS-xx (sidewall sheeting), FP-xx (flat/flashing) — Maimaar's drawing mark convention.
- **Existing RCC** (extensions): many jobs sit on existing RCC columns (e.g. 460×460),
  pedestals and beams — the PEB ties into them; level callouts like `+17400`.

## Wired into the generator (v10)
- Sheeting material named **"0.5mm PPGI Type-R High-Rib"** (roof/wall), translucent for snaps.
- **Cable X-bracing (Ø12)** added in the braced bays (roof + sidewalls) from the IF
  `bracing.braced` list.
- **Edge trims** (eave / gable-rake / corner angles 80×80) added.
- Purlin/girt = 200Z, eave strut 200Z, sag rods Ø12 (already wired in v9).
