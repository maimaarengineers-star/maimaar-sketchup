> ## ⚠️ RECONCILED AGAINST THE RULE REGISTER (read this first)
> After reading `Rule_Book/RULE_REGISTER.md` + `Compiler/PEB_RULES.json` + `_peb_rules.lsp`,
> several items below are **NOT bugs — they are deliberate, owner-LOCKED rules**. Do not "fix" them:
> - **A1/A2 "39100 vs 39300"** = rule **D8** (BASIS-DRIVEN dims, owner 4-Jul): under C/C the overall
>   length is intentionally `grid − 2×half-web` (−200). Working as specified.
> - **"Bubbles only top+left" (C1)** = rule **G4** (owner): bubbles/lines TOP & LEFT only, by design.
> - **Bubble radius floor 900** = owner's 4-Jul readability tuning; **GRID BUBBLE is LOCKED (3-Jul)**.
>   (Note: the compiled Rule Book value is `bubble_radius_mm = 620`, but the engine hardcodes 900 —
>   a real rule-vs-code disconnect that is the OWNER's call to resolve, not a bug to silently fix.)
> - **Wall-condition suffix, jack beams, four-side dims, section** = tracked in the register as
>   TODO / TO-BUILD (W2 built, AR-series TO-BUILD), not oversights.
>
> **Genuinely safe fixes that remain valid:** A11 (letters past Z → AA/AB), A3 (grid dedupe tolerance),
> A7 (guard undefined `peb-th`), A11/A3 applied. The magic-number/scaling refactor (§B/§D) is a
> *design improvement*, not a correctness fix, and must go through the register's written→built→**validated** loop.

# PEB Column-Layout Plan — Bug & Refactor Audit
**Generator:** `engine/MAIMAAR_PEB_Plan.lsp` (3,664 lines) + `_peb_rules.lsp`, `_peb_symbols.lsp`.
**Fixture:** Clear Span 12400 × 39300, 7 bays (5750+5750+6100+6100+5200+5200+5200 = 39300), bearing endwalls, `LENGTH_REF = C/C of Steel Column`, `DIM_DISPLAY = mm`.
**Target look:** Mammut "Roshan" reference — bubbles all around, column at every intersection, inner+outer dim chains, area marks, jack beams, section, full title block, and it must self-fit from 20×15 to 150×100.

**Core diagnosis:** the layout is a stack of hardcoded mm offsets × one global text-scale factor, with **no drawing scale and no anchor/margin system**. That is why there are 26 `fix(plan)` commits and why a fix at one building size breaks another. The cure is a layout system, not more tweaks.

---

## A. CRITICAL BUGS

- **A1 — "39.12 M" subtitle vs C/C length.** `peb-basis-dim` (L1028-1044) folds the ±basis offset into the printed VALUE (`nth 0`), so the overall length dim reads 39100 under C/C while the subtitle (L2244-2257) prints raw len. An overall dim must always read the true 39300; the basis offset must move **witness lines only**, never the printed value.
- **A2 — dim chain doesn't close.** Bay chain prints the IF expression (=39300) but the overall dim over the same points prints 39100 (root cause = A1). 200 mm discrepancy on the sheet.
- **A3 — letter grid ≠ column grid.** Endwall stations (L1678-1694) merged with a 1 mm dedupe can land letters/lines where no interior column exists; floating rounding can double a bubble. "Column at every intersection" breaks.
- **A4 — shared/common wall drawn twice.** No multi-area suppression; `AR_POSITION/AR_REF_AREA/AR_GAP` are read but never used. Tiling two areas doubles the party wall's columns/letters/dims.
- **A5 — jack beams missing.** No jack-beam / intermediate-column entity or layer anywhere. Roshan shows them.
- **A6 — endwall auto-spacing overrides the IF.** When the IF gives explicit endwall spans, the code re-scales them to close on width (L1683), silently misrepresenting input instead of flagging.
- **A7 — `peb-th` called but never defined** (L444, L491). Comes from `MAIMAAR_PEB_Standard.lsp`; if not loaded, ridge symbols silently vanish (wrapped in catch). Same latent risk: `draw-height-dim` (L3376), `peb-tile-place` (L3447).
- **A8 — width grid lines can cut into the dim/label zone** (L1846) depending on `3*dimGap` vs the left dim-stack width.
- **A9 — border computed twice; first block dead** (L2307-2319 dead, L2499-2502 live). Live border (`-6500*DS`) is inside the true left content extent (`-9000*DS - BUBRAD`) → LEW bubbles/labels fall OUTSIDE the border. This is the recurring "everything inside border" bug.
- **A10 — FALL glyph autosize** (L2083) uses its own scale band; on narrow buildings the pentagon + text can cross the ridge/walls.
- **A11 — grid letters break past 26** (L1848 `chr (+ 65 …)`) → garbage letters on large multi-span (LARGE test).

## B. MAGIC-NUMBER / SCALING ISSUES (why it won't generalize)
Everything is `constant × *PEB-TEXT-SCALE*` (L1662-1664) — one factor drives BOTH text height AND layout gaps, with no sheet/plot scale. Key offenders: bubble radius floor/cap ladder (L1808), `dimGap/txtGap` fixed mm×scale (L1813-14), hand-stacked Ys `yBayDim…yFrmTop` (L1813-1823), left stack `gridX1 = -6000*DS-BUBRAD` (L1823), endwall divisor 6250 (L1667), fabricated witness offsets 100/200/400 unrelated to real web (L1030-32, B8), ridge symbol fixed coords capped ×1.0 (L481-491), FALL band (L2083), bracing bare `190.0` mixed with `*TS/*DS` (L732-742), title-block width tied to building length (L2431-33), LTSCALE set twice (L1723,1745). Each should derive from **building extents + a single plot scale**, not a legibility factor.

## C. GAPS vs ROSHAN (the presentation/beauty layer)
1. Bubbles only on **top + left**; Roshan has all **four sides**.
2. No distinct "column mark" at every intersection; letter grid vs column grid mismatch (A3).
3. Dim chains **left/top only**; REW has **no dims** (L2209); Roshan has inner+outer on multiple sides.
4. Single centre area mark; no AREA-01/02 split, no shared wall (A4).
5. **Jack beams absent** (A5).
6. Wall-condition suffix deliberately stripped (L2112); `peb-ow-suffix` (L570) unused; Roshan shows conditions.
7. Ridge/fall present but fragile + fixed-scale.
8. **No section** placed (title says "…& ANCHOR BOLT PLAN").
9. Title block: two dead sizing systems remain; `SCALE = "N.T.S."` hardcoded (L2486) — Roshan carries a real scale.

## D. REFACTOR — the layout/scale system (the real fix)
Introduce these helpers; each retires a cluster of magic numbers:
1. `peb-compute-sheet len wid` → sheet + **plotScale** (world→paper) + real "1:NN" scale. Replaces L1658-1664, 2486, 2278-2280.
2. `peb-th kind` → world text height = paperHeight / plotScale (**this is the undefined function from A7 — define it here**). Removes the text-scale factor from all glyphs.
3. `peb-glyph frac` → symbol/bubble world size from extent fraction, clamped to a paper minimum. Replaces bubble/ridge/fall/crosshair sizing.
4. `peb-stack anchor dir bands` → non-overlapping row Ys by construction. Replaces the hand-stacked Ys.
5. `peb-grid-model data` → ONE reconciled grid (merge width/endwall/module stations with scale-aware tolerance; base-26 lettering; record which stations carry columns). All four sides read from it.
6. `peb-basis-witness` → returns **witness offsets only**, never a mutated value; use real `colWeb/2`. Fixes A1/A2/B8.
7. `peb-extents` + `peb-place-border` → border/title from **true drawn extents + fixed paper margin**. Fixes A9, B12-14.
8. `peb-area-model` (consumes AR_* , draws shared wall once) + `peb-jack-beams`. Fixes A4/A5.

**Net:** every size/position becomes a function of (extents, plotScale, grid model) → 20×15 and 150×100 self-fit with identical code.

## E. PRIORITIZED FIX ORDER
**Phase 1 — correctness quick wins:** A1/A2 (39.12 fix), A7 (define peb-th / hard-require Standard), A11 (base-26 letters), A3 dedupe tolerance, B8 (real witness offsets).
**Phase 2 — the scale/layout system (retires ~20 of 26 recurring tweaks):** D1 sheet/plotScale, D2 peb-th, D3 peb-glyph, D4 peb-stack, D5 grid-model, D7 extents/border, D6 basis-witness.
**Phase 3 — Roshan presentation polish (only AFTER Phase 2):** four-side bubbles, REW/NSW dim chains, multi-area shared wall + jack beams, wall-condition labels, fall glyph sizing, place the section + real scale in the title block.

> Do NOT do Phase 3 before Phase 2 — adding presentation features on top of magic numbers just grows the pile. The layout system is what makes it look like Roshan at every size.
