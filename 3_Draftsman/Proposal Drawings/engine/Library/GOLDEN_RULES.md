# GOLDEN RULES — AutoCAD PEB Component Library

**Binding.** Every rule here cost real time, and every one is traceable to a specific failure or
a specific instruction from the owner. Read this before writing a drawer. Most of these failures
are **silent** — the render "succeeds" and the sheet is wrong or blank.

Established 3-Sep-2026, from building the first component (wall light / sky light).

---

## A · WHAT A COMPONENT IS

### 1. One product, one drawer

A sky light and a wall light are the same fiberglass panel. The name follows the surface — *"on
Wall it is called Wall Light not Skylight, though both have the same material, as we say purlins
and girts."* One product must have exactly **one** piece of code that draws it.

> **Why:** the roof plan draws skylights with its own poly + hatch
> (`peb-draw-skylights-per-bay`, `Plan.lsp:5036`) while the library draws the same panel with
> `peb-acc-light-elev`. Be precise about how far they diverge: the **colour and pen already
> agree** — `peb-ensure-layers` creates `SKY LIGHT` at ACI 151 / 0.50 from the standard before
> either runs, so the `4` in `(peb-comp-layer "SKY LIGHT" 4)` at `:5054` is a dead fallback and
> the comment above it calling the layer "cyan" is stale. What diverges is the **fill density** —
> `skyW/4` on the roof plan against `/25` in the library — so the identical product reads as
> stripes on one sheet and as a glossy sheet on another.

If two sheets show the same product, they call the same drawer. No exceptions.

### 2. A drawer is pure geometry

Everything in as **arguments**; geometry out.

A drawer must **not**:
- read the BSF (`MSPL-Get-Str` / `MSPL-Get-Num`) — the data belongs to the caller;
- draw a sheet, frame or title block — sheets are the building engine's job;
- hard-code a name that depends on the surface — pass it in;
- hand-drive `LAYER` / `STYLE` / `TEXT` with `command` — see rule 10.

A drawer that reads the BSF cannot be reused anywhere else, and it re-derives numbers the BSF has
already settled (rule 24).

### 3. Reuse the geometry — and share the SOURCE, not the numbers

The light panel calls `peb-sd-sprofile` rather than re-authoring ribs. But it first carried its
own `250` and `35` while the sheeting carried the same two literals independently.

> **"100% match" means one source, not two equal numbers.** Two literals that agree today are a
> match waiting to be broken by whoever edits one of them.

Hence `peb-sheet-rib-pitch` / `peb-sheet-rib-height` / `peb-sheet-cover`, declared beside
`peb-sd-sprofile` in `MAIMAAR_PEB_Framing.lsp` and read by both the sheet and every component
that reuses the profile.

---

## B · WHAT SURVIVES THE PLOT

### 4. The deliverable is monochrome. Colour carries nothing.

`monochrome.ctb` is set on **all four** plot paths — `MAIMAAR_PEB_PDF.lsp:90` and `:140`,
`drawingRender.ts:394` and `:1263`. Every ACI collapses to black on the customer's PDF.

Colour is for the DWG the draughtsman works in, and for a colour print. **Only lineweight can
carry meaning on the deliverable.** Never let a distinction depend on colour alone.

| | layer | pen |
|---|---|---|
| steel sheeting | `SHEETING` | 0.09 |
| light panel outline | `SKY LIGHT` / `WALL LIGHT` | 0.50 |
| translucency fill | same | 0.05 |

### 5. Prefer a line fill. A filled region is a decision, not a default.

This rule was first written as "never a filled region". **That was wrong**, and the correction
matters: genuine `HATCH` and `SOLID` entities *are* used for material in this engine and *do*
survive the pipeline — `AR-CONC` for concrete, `AR-B816` / `BRICK` for masonry, `ANSI31` for
steel poche, `SOLID` for base plates, across `MAIMAAR_PEB_Section.lsp`,
`MAIMAAR_PEB_Framing.lsp` and `MAIMAAR_PEB_MezzDetail.lsp`. The material→pattern table is
`MAIMAAR_PEB_Standard.lsp:194-202`.

What is true is that the **newer** drawers are all line-based, for four separately documented
reasons — and you should know which one applies to you:

| reason | where it is stated |
|---|---|
| real HATCH entities fail under `acad /b` | `Plan.lsp:3307`, `:4996` |
| a large fill plots **black** under `monochrome.ctb` | `LightPanel.lsp:86` |
| an **unbounded** HATCH is the classic way to hang a headless render | `MezzDetail.lsp:748` |
| the pattern does not stretch to its boundary | `Framing.lsp:3009` |

So: **a big area you are tinting → line fill** (a solid one reaches the customer black). **A
small poche inside a section cut → the system pattern is fine**, and `Framing.lsp:1813` shows the
safe way to do it — call `-HATCH`, then check `(eq (entlast) hEnt)` and fall back to manual 45°
lines when it aborted.

Density carries the material: `/4` across the cover reads as stripes, `/25` as a glossy sheet.

### 6. Set the pen explicitly

`peb-comp-layer` (`MAIMAAR_PEB_Plan.lsp:3300`) sets **colour only, never lineweight**. Any layer
it invents inherits `LWDEFAULT` 0.25 — which lands between the 0.09 sheet and the 0.50 panel, so
you get a visible difference **by accident rather than by design**, and it changes if the host
drawing differs.

Put the pen on the entity — `(cons 370 N)` — **and** the layer in the standard.

---

## C · LAYERS

### 7. Layers come from `PEB_LAYERS.csv`. No exceptions.

The first draft invented `DIM` (the standard is `DIMENSIONS`, ACI 6, 0.13) and `GIRT` (the
standard is `GIRTS`, ACI 6, 0.13), and called `SHEETING` at ACI 8 when the standard says 4.
Every one of those is an invisible drift from the house standard.

### 8. A new layer goes in the CSV, then the file is regenerated

`SKY LIGHT` and `WALL LIGHT` did not exist in the standard at all. Add them to
`Rule_Book/PEB_LAYERS.csv`, then run `build_engine_standard.py`.

### 9. Regenerating may carry unrelated drift — ship only your own change

`_PEB_LAYERS_generated.lsp` was **stale against its own CSV**. Regenerating it silently also
changed `FRAME` (colour 1→7, weight 0.30→0.50) and `COMP-MEZZ-BEAM` (0.50→0.40) — the frame
weight on *every sheet Maimaar has ever produced*.

Both were reverted so the change stayed additive. **Diff the generated file semantically before
accepting it**, and report drift rather than silently "fixing" it.

---

## D · SCRIPTING AUTOCAD — WHERE THE SILENCE LIVES

### 10. An open prompt eats the rest of the script, and is not an error

Hit **twice** in one session:

- `SAVEAS` onto an existing file asks *"replace? \<N\>"* → swallowed the `PNGOUT` line, then hung
  for ten minutes.
- `PDFIMPORT` could not find its file → re-prompted for a filename and ate every line after it.

**Delete before writing** — exactly what `_pebout` already does — and never leave a command that
can ask you a question. This is the same class as the standing LISP silent-failure rule: an open
`acad` command is not a LISP error, so nothing catches it.

### 11. Script lines and LISP strings escape differently

| context | backslashes |
|---|---|
| a **script line** (typed at the prompt) | **single**, raw |
| a **LISP string literal** | **doubled** |

Getting this wrong produced `D:\\\maimaar-os`; every `(load)` failed and the sheet came out
blank, with nothing in the harness output to say so. Keep **one** `q()` helper doing **one**
substitution, and use it only for LISP strings.

### 12. Quote any path containing a space

Script lines split on spaces. `…\Proposal Drawings\…` arrived as two separate answers and
started the prompt loop of rule 10.

### 13. Fresh work dir per run — never delete the old one

`rmSync` throws `EPERM` when a PDF from the previous run is still open in a viewer, and the run
dies before drawing anything. Use `wl_<timestamp>`; a directory that never existed cannot be
locked.

---

## E · DRAWING LIKE A DRAUGHTSMAN

### 14. Scale annotation to what is drawn

`peb-th`'s text ladder is tuned for a sheet showing a 48 m building. Used unchanged on a
1000 × 1524 panel, the callouts came out **three times taller than the panel**. A component
sample sets its own `*PEB-TEXT-SCALE*` — scale off the component, not the building.

### 15. One scale per sheet

The first sample put a 1000-wide detail and a 48,770-long side wall on one sheet. The two small
views collapsed into an unreadable overlap at the left edge. **One view per sheet, or one scale
for all views.**

### 16. Dimension text goes on the far side of the line from the object

The helper always placed text *above* the dimension line, so a dimension taken *below* a panel
put "1000 COVER" back across the panel it was measuring. The sign of the offset says which way
the dimension was taken, so it also says which side the text belongs on.

### 17. Annotate the type, not every instance

> *"No need to mention the labeling of wall lights — just show the wall lights … Only L-Type
> ladder with Text 'Wall Light - Type' … Maximum Write the Qty."*

A band of 48 panels labelled individually is noise. One L-leader
(`peb-label-with-leader` with `"V"`) carrying `NN No. <TYPE>`.

### 18. A library detail carries GENERAL information

> *"Labelling should be general for information."*

State the **rule** — *sill = clear height − panel length* — never one job's `3962`, which is
right for that building and wrong for the next one that reads the sheet. Job numbers belong on
the building's own sheet.

---

## F · REFERENCES AND HONESTY

### 19. Read the drawing, not the text layer

The seam-lock sky light was first traced as **637 cover** from `pdftotext` output. Importing the
sheet into AutoCAD showed **484** dimensioned across the finished panel — 637 is the *developed
girth* — plus a 25 × 25 × 1.2 stiffener tube the text stream never showed.

`<component>/reference/view_reference.js` imports an approval PDF to DXF + PNG. **Use it before
trusting any traced number.**

### 20. Declare what is traced and what is stylised

Rulebook 4B.24: a stylised shape under correct dimensions is honest; invented dimensions are
not. Each component's README says which of its numbers are measured and which are drawn to look
right.

### 21. Every component keeps its own reference

> *"Copy the old references of similar component for quick reference for the development to
> match."*

Approval PDFs, the converted DXF, and the relevant manual pages live in `reference/`, beside the
code that traces them.

---

## G · VERIFICATION

### 22. Look at it. Rendering is not verifying.

`PNGOUT` rasters the drawing so the result can actually be seen. In one session a blank sheet, an
unreadable three-scale overlap, and dimension text sitting across the panel **all rendered
"successfully"**.

### 23. Run `lispcheck` — and read it

It catches functions called but never defined, which render as a blank sheet silently. It also
reads function names out of **prose**, so keep `(peb-…` out of comments or you will chase a
phantom.

### 24. The BSF is the single source of truth

`geometryRules.js` computes → the BSF stores → the drawing reads. The drawer re-derives nothing.
The light panel's sill is the worked example: `lightPanel()` returns it, the BSF keeps it, and
the LISP just draws at the sill it is given.

---

---

## H · PEB MATERIALS — HOW EACH ONE IS DRAWN

The rules above are about *code*. This section is about *materials*: what each PEB material looks
like on a Maimaar drawing, so a new component draws its material the way the rest of the engine
already does instead of inventing a look.

### The three ways a material is expressed

1. **PROFILE GEOMETRY** — the strongest signal, and often the only one needed. A lock-seam sheet
   is not a hatch, it is a 470 cover with ribs at 155 centres. A sandwich panel is a 184 module
   with a 32 rib, deliberately *not* the S profile.
2. **FILL** — line-based for the newer drawers, all at the lightest pen (0.05). The *spacing* is
   what distinguishes them, so pick spacing deliberately.
3. **PEN** — the only one that survives the monochrome plot (rule 4). Weight is how a material
   reads as different on the customer's PDF.

Colour is a fourth, but it is DWG-only. It is worth setting, and worth never depending on.

### The catalogue as it stands

| Material | How it is drawn | Layer (ACI / pen) | Source |
|---|---|---|---|
| Standard S sheet | profile: 35 rib @ 250 pitch, 1000 cover, both laps on a rib | `SHEETING` (4 / 0.09) | `peb-sd-sprofile`, `Framing.lsp:2704` |
| Lock-seam sheet | profile: 470 cover, ribs @ 155 centres, THK 0.6 | `SHEETING` (4 / 0.09) | `peb-sd-lockseam`, `Framing.lsp:2753` |
| Sandwich panel | profile: 184 module / 32 rib + flat inner liner | `SHEETING` | `peb-sd-sandwich`, `Framing.lsp:2912` |
| Sandwich **core** | single 45° line fill @ `thk/1.4` | `HATCH` (8 / 0.05) | `Framing.lsp:2933` |
| Insulation (glass wool) | ONE continuous **sine wave**, amplitude = full thickness, wavelength `0.55 × thk` | `HATCH` (8 / 0.05) | `peb-sd-insulation`, `Framing.lsp:3020` |
| Wall light / sky light | S profile + line fill @ `cover/25` (glossy) | `WALL LIGHT` / `SKY LIGHT` (151 / 0.50) | `peb-acc-light-elev` |
| Seam-lock sky light | profile: 484 cover, 75 rib, THK 2.0 | `SKY LIGHT` (151 / 0.50) | `peb-acc-sl-profile` |
| Concrete / RCC | `AR-CONC` pattern, or 45° both-ways lines @ 300 | `RCC-COLUMN` (8 / 0.35), `HATCHR` (32) | `peb-sec-xhatch`, `Section.lsp:8222` |
| Brickwork | `AR-B816` / `BRICK` pattern @ 20-150 | `BRICK-WALL` (30 / 0.25) | `Section.lsp:3255`, `Framing.lsp:1811` |
| Steel (section poche) | `ANSI31` @ `60 × TS` | `FRAME-FILL` (8 / 0.09) | `Section.lsp:3286` |
| Base plate | `SOLID` | `PLATES` (1) | `Section.lsp:3306` |
| Mezzanine deck | 45° line fill @ 1600 | `COMP-MEZZ-HATCH` (9) | `peb-mezz-hatch`, `Plan.lsp:3312` |
| Ground / earth | tick marks | `GROUND-HATCH` (8 / 0.09) | `Section.lsp:4380` |
| Insect screen | line fill @ 120, **both** diagonals | `LOUVER` (3) | `peb-lv-screen-hatch` |

The central material→pattern table is `MAIMAAR_PEB_Standard.lsp:194-202` (`*PEB-HATCH*`):
RCC/CONCRETE → `AR-CONC` 25.0; MASONRY/BRICK → `AR-B816` 20.0; EXISTING/FUTURE → `ANSI31` 60.0;
**STEEL → nil (clear)**.

### Rules for adding a material

**M1. Distinguish by geometry first, fill second, pen third, colour never alone.**
If the profile already says what it is, do not add a fill on top of it.

**M2. A fill spacing must be chosen against its neighbours, not in isolation.**
Two materials that meet on a sheet must not fill at similar spacing. The values in use are 120
(screen, crossed), 250 (door ribs), 300 (concrete, crossed), `cover/25` (glossy light panel),
`cover/4` (light panel as a small plan symbol), 800-1600 (deck, ground).

**M3. Every material fill goes at 0.05 mm.**
`(cons 370 5)`. A fill must never compete with the outline it sits inside.

**M4. Put the material's layer in `PEB_LAYERS.csv` before you use it.**
Three live layers are not in the standard and pick their own colour ad hoc — `COMP-MEZZ-HATCH`
(9), `COMP-ROOF-ACC` (4), `LOUVER` (3). Each one is a small future inconsistency; do not add a
fourth.

**M5. A material's numbers come from a drawing, not from a datasheet you remember.**
And say in the README which are traced (rules 19-20).

**M6. Check the hue against the palette.**
`SKY LIGHT` / `WALL LIGHT` at 151 sit next to `GRID` at 150, and both appear on the ROOF SHEETING
PLAN. They separate by weight (0.50 vs 0.35) and by shape, so it is a hue clash rather than an
information clash — but it is the kind of thing to notice before adding another blue.

## THE SHAPE OF A COMPONENT

```
Library/<name>/
  MAIMAAR_PEB_<Name>.lsp   drawers — pure geometry (rules 1-3, 5-7)
  reference/               traced sources + view_reference.js (rules 19-21)
  sample/                  render_sample.js + last_render.png (rules 13-16, 22)
  README.md                what it draws, its numbers, traced vs stylised (rule 20)
```

Start from `_template/` — it already obeys rules 10-13 and 22.

## SYNCING INTO THE BUILDING DRAWINGS

Development is **separate** from the BSF-synchronised engine. A finished component syncs in three
small, reviewable edits:

1. its `(load …)` in `loadLines`, `services/drawingData.ts`;
2. its case in the placement dispatch, `MAIMAAR_PEB_Elevation.lsp` (today a bare `RECTANG` for
   every accessory);
3. its **placement rule** — which belongs on the BSF side (rule 24), never in the LISP.

Then render one real building and diff it against the previous PDF.


---

## I · ACCESSORIES ON A WALL — rules added 4-Sep-2026

These came out of putting the first real component (the sliding door) onto a live sheet,
MSPL-26-266. Every one of them was a thing the sheet got wrong before it was written down.

### 25. Draw the OPENING first, then place the accessory into it

> *"Always develop the Openings and then place the Accessories in it."*

The opening is the hole in the wall. It exists whether or not anything is fitted into it, it is
what the steel is framed for, and it is what the customer measures. Draw it first; everything
else is placed **into** it. A drawer that starts from the accessory and implies an opening around
it gets the framing wrong the moment the accessory changes.

### 26. Show a door PARTLY OPEN

> *"Always show the Door in Elevation in OPENED conditions for customer understanding … first
> make the Opening and then show the Door in Partially Opened condition."*

A closed leaf is indistinguishable from a panel. The customer cannot see that it slides, cannot
see where it goes, and cannot see how much wall it needs. At about 40% open the void is visible
beside the leaf, the leaf is plainly clear of the opening, and the arrow says which way it went.

### 27. NO ACCESSORY IN THE SAME PLACE AS ANOTHER — but stacked is fine

> *"There should not be overlapping of Accessories … if the Door is coming at any place, then
> Louvers should be removed from there … there was a door and within the door louver was showing,
> which is not practically possible."*
>
> and, the correction that makes it precise:
>
> *"One accessory may come over and above the other but not at the same place."*
> *"Do not break the wall lights — this is not the rule I mean to say."*

**The test is two-dimensional.** A louver ABOVE a door head shares the wall, not the place, and
must be kept. A louver INSIDE the doorway cannot be built. An x-only test cannot tell those apart
and throws away the first along with the second — which is exactly what the first attempt did.

`peb-fr-door-boxes` returns the whole rectangle each door occupies as drawn — widened for the
leaves, which stand beside the opening once the door is shown open, and running sill to head, so
nothing above the head is in its way. `peb-fr-in-door-box` asks for an overlap on **both** axes.

**What this rule does NOT do:** it does not break the continuous wall-light band. That band is
cladding running along the wall, not an accessory placed at a position, and it passes over a door
the way a girt does. The first attempt broke it and had to be put back.

A trap worth knowing: a wall carries several INDEPENDENT placers that never resolve against each
other — the wall-light band marches across the middle knowing nothing about bays, the louvers come
from the PL_* opening loop, the doors from DR_*. Fixing the one you happen to look at first fixes
nothing. On MSPL-26-266 the per-bay light was corrected and it changed the drawing not at all,
because the thing actually sitting in the doorway was a louver from a different loop entirely.

**Guard every call site.** The framing elevation cuts the framed opening and the sheeting
elevation cuts the sheet; if one stands aside and the other does not, you get a hole with no
louver, or a louver with no hole.

### 28. A door in a braced bay makes the bracing PORTAL

> *"In case of Doors, automatically Portal Bracing will be up to the Door Height and above, Cross
> Bracing."*

An X cannot run through a doorway — the diagonal is the thing in the way. Below the head, a
portal: head beam across the bay with a haunch at each knee. Above it, the X, standing on that
beam instead of on the floor.

The engine already knew this could happen: the plan prints **"(!) OPENING IN BRACED BAY"** in red.
It printed the warning and drew the X straight through the door anyway. A rule that only warns is
half a rule.

### 29. What a panel is made of decides how it is DRAWN

Not just what it costs.

| | reads as |
|---|---|
| EPS sandwich | micro-ribbed **both** sides — finer than the wall, so the door reads as a door |
| PIR sandwich | **the same as the wall** — drawn at the wall's own pitch, through the shared source |
| single skin | the frame is built first and the sheet goes on after, so **the frame shows** |

### 30. Before editing a drawing rule, find the code the sheet ACTUALLY runs

The portal rule was first written into the X-bracing block in `MAIMAAR_PEB_Elevation.lsp`. That
block never runs for this sheet set — the framing elevation is drawn by `peb-draw-framing-elev` in
`MAIMAAR_PEB_Framing.lsp`. The output was identical before and after, and the giveaway was that
the label the block should have produced was **absent from the drawing in both cases**.

Two implementations of the same thing already exist in this engine. Adding a rule to the dead one
and not the live one makes that worse. **Count the thing your change should produce, in the output,
before and after** — and if the count is zero both times, you are editing the wrong file.

### 31. EVERY DRAWING IS FRAMED IN A LAYOUT — never plotted from the model

**Owner, 4-Sep-2026: "ALL DRAWINGS TO BE FRAMED IN LAYOUTS — NOT IN THE MODEL."**

The model is where geometry is built at true size. It is never what gets plotted. A sheet is a
sheet because it sits on an A4 layout with a viewport at a stated scale and a title block — that
is what makes a plot repeatable, what makes the scale mean something, and what lets the customer
press print once and get the same page back.

The trap is that plotting from the model **looks fine**. `plotpdf` plots
`(vla-get-ActiveLayout)`, and every sheet begins with `(setvar "TILEMODE" 1)` — so a page that
forgets to create its layout silently plots *Model*, ZOOM-Extents-scaled to fit the paper. It
comes out the right way up, roughly the right size, and nothing anywhere reports a problem.

That is exactly how the COVER shipped: it draws its own A4 frame, so extents happened to land
near the paper edge and it passed the eye. It was still scale-to-fit-whatever-the-extents-were,
not framed to the sheet, so it could not be trusted to match the other pages or to reprint the
same twice. Every engineering sheet in the same set went through `peb-add-layout` correctly.

**So:**

* Every page — cover included — creates a layout before `plotpdf`. Use `peb-add-layout` for a
  sheet that needs the Maimaar title strip, `peb-add-plain-layout` for one that already draws
  its own complete frame.
* A DWG deliverable ships with a **named tab per sheet**, and the cover's LIST OF DRAWINGS is
  built from those same tabs, in the same order, so the two cannot disagree. Set
  `*PEB-SHEET-LIST*` from the sheets actually emitted — never leave `Cover.lsp` to fall back to
  its hard-coded list.
* A layout created for a PDF page is deleted again before the next sheet draws. `ERASE ALL`
  clears model space only, so a surviving paperspace makes the next `peb-*-from-file` read
  EXTMAX from the layout and wedge AutoCAD at 100% CPU with no error.
* **How to check it, since looking at the page will not tell you:** the plotted page must come
  from a layout that exists at plot time. Grep the built script for `plotpdf` and confirm an
  `add-layout` call precedes each one in the same sheet block.

### 32. A PROPOSAL DRAWING IS INDICATIVE, NOT DETAILED

**Owner, 4-Sep-2026: "Proposal Drawings are always Indicative, not detailed one."**

Show **what** and **where**. Do not show **how much** or **how fixed**. Laps, cleats, bolts,
fastener spacings, rib pitches and member sizes belong to the APPROVAL drawing, which is a
different document with a different purpose and a different signature on it.

This is the tie-breaker, and it had been decided ad hoc four separate times before anyone wrote
it down — each time by arguing the specific case again from scratch:

* the 250 rib pitch on a wall light, which at 1:300 out-drew the cladding it sat in;
* the translucency sheen at cover/25, which plotted as a solid smear;
* the 100 mm sheeting lap at a wall light (rule 33), correct and deliberately not drawn;
* jamb cleats and bolt counts on a framing elevation.

The test is not "is it true?" — all four are true. The test is **"does the customer's decision
turn on it at proposal stage?"** If not, it is noise on an A4 sheet, and noise is what makes a
drawing look wrong even when every line in it is right.

The corollary matters as much: **indicative is not vague.** Positions, counts, levels and grid
references must be exactly right, because those are what the customer is being asked to agree to.
Leave out the detail, never the substance.

### 33. THE SHEETING BREAKS AT A WALL LIGHT — 100 mm lap, and the wall is THREE COURSES

**Owner, 4-Sep-2026:** *"place girts on top and bottom of wall lights by default and then we
always install the bottom sheet from BW to bottom of wall light girt and we fix the wall lights
on top of it and then again a sheet come from wall light top to the eave level all around"* — and
*"At the Location where wall skylights will come, walls sheeting will break with 100mm overlap
b/w them."*

So a wall carrying wall lights is built, and must be drawn, as **three courses**:

1. brickwork → the bottom wall-light girt
2. the fiberglass wall lights, girted top and bottom **by default**
3. the top wall-light girt → eave

A wall light is a **standard 1000 wide** — exactly one sheeting panel — so a light bay and a
cladding bay are the same bay, and the break always lands on a joint. The steel laps the
fiberglass by **100 mm** at head and sill.

**Draw the courses. Do not draw the lap** (rule 32) — the lap is fabrication, the courses are
the building.

**This is why the side wall "showed boxes" four times running.** The cladding drew every joint
as ONE line from brickwork to eave — a sheet that does not exist — and the band's own sill and
head then crossed all 48 of them. Three rounds of work went into thinning the band (ribs, sheen,
panel outlines: 1,628 entities down to 96) and none of it helped, because **the horizontals were
never the fault. The full-height verticals were.** When a drawing looks wrong in a way that
tidying does not fix, the geometry is telling you the building is not built the way you drew it.

### 34. THE FACE SHOWS PANEL JOINTS, NOT RIBS — and a wall light is a PANEL, not a hole

A sheeted face — wall or roof — shows **one line per panel joint at the COVER width**, plus the
two end edges. `n = L ÷ cover` panels gives `n+1` lines. 22 m at 1000 cover = 22 panels, 23
lines. The cover is **read** (`peb-panel-cover` / `PN_<KEY>_COVER`), never assumed: a lock-seam
surface lays out at **470**, not 1000.

**Ribs are never drawn on the face.** The 35 mm rib at 250 pitch is a roll-forming dimension;
four pitches make the 1000 cover. The DETAILS sheet draws the true profile (`peb-sd-sprofile`).

**A wall light is a panel in the run** — it replaces a sheet on the module, it is not an opening
cut into one. So it carries the same four edges as any panel and lands on the same joint
stations, and the cladding courses above and below butt to it.

**Three independent sources say so, and one of them is a mistake I made on 4-Sep-2026.**
Asked for "profiling lines", I reasoned from what the eye sees standing at a real wall — the rib
shadows at 250, with the side lap invisible because it is formed to sit *in* a rib — and
recommended drawing the rib rhythm thinned for legibility. That is correct physics and the wrong
drawing. The evidence:

* **S43 in `PD_RULEBOOK.md`**, the owner's own words: *"if we have 22m length of end wall, there
  must be 22 or 23 lines to show 2 side lines of each panel, for all roofs and all walls"* — and
  *"Ribs are not drawn on the face."*
* **Mammut's own proposal elevation** (`MAMMUT_08_PearlKhas_Elevations_Poultry.dxf`): the
  `SHEETING` layer is declared and holds **zero entities**. Their proposal face is plain — bay
  grid and a text callout naming the panel, nothing more.
* **Maimaar's erection sheets** (Awan Sports 045-MSPL, Gold Panel 035-MSPL, Tekla 2022): panels
  marked one by one at the module — `SWS-1/(2863)`, `9*SWS-5/(628)` — with the wall light inline
  among them as `5*WL-1/(1700)`. No rib lines anywhere.

**The lesson is the general one:** a drawing is a convention, not a photograph. What the eye
resolves at 1 m it cannot resolve at 1:300, and reasoning from the real object will confidently
produce the wrong sheet. Check the reference and the rule book before reasoning from first
principles — and when they disagree with the reasoning, they win.

**Legibility floor**, since it decides how many lines survive: joint spacing on A4 is
`219 × cover ÷ L` mm. Below **1.5 mm** lines stop being information and plot as a grey band, so
`peb-panel-lines` thins to every 2nd joint, then every 3rd. Never bypass it with a hard-coded
step — `MAIMAAR_PEB_Elevation.lsp` stepped a literal 1500 (neither rib nor cover) and so escaped
the guard entirely.
